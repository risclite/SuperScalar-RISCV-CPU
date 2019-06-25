/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2019  Li Xinbing
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//
/////////////////////////////////////////////////////////////////////////////////////

`include "define.v"
module mprf(
    //system signals
    input                                clk,
	input                                rst,
	
	//from sys_csr
	input                                direct_mode,
   
	//from membuf                       
	input                                mem_release,
	input  `N(`RGBIT)                    mem_sel,
	input  `N(`XLEN)                     mem_data,
   
	//from alu/alu_mul                  
	input  `N(`EXEC_LEN*`RGBIT)          rg_sel,
	input  `N(`EXEC_LEN*`MEMB_OFF)       rg_cnt,
	input  `N(`EXEC_LEN*`XLEN)           rg_data,
 
	//between alu/alu_mul               
	input  `N(`EXEC_LEN*`RGBIT)          rs0_sel,
	input  `N(`EXEC_LEN*`RGBIT)          rs1_sel,    	
	output reg `N(`EXEC_LEN*`XLEN)       rs0_data,
	output reg `N(`EXEC_LEN*`XLEN)       rs1_data,
	
	//to schedule
	output `N(`EXEC_OFF)                 rf_release
);

    function `N(`MEMB_OFF) subone(input sub_flag,input `N(`MEMB_OFF) i);
	begin
	    subone = sub_flag ? ((i==0) ? 0 : (i-1)) : i;
	end
	endfunction

    reg  `N(`XLEN)                  r         [31:1];

	reg  `N(`RFBUF_LEN*`XLEN)       buf_r;
	reg  `N(`RFBUF_LEN*`MEMB_OFF)   buf_cnt;
	reg  `N(`RFBUF_LEN*`RGBIT)      buf_sel;
	reg  `N(`RFBUF_OFF)             buf_len;	
	wire `N(`RFBUF_LEN*`MEMB_OFF)   buf_count;
	
	wire `N(`RFBUF_LEN)             this_flag;	
	wire `N(`EXEC_OFF)              this_shift `N(`RFBUF_LEN);
	wire `N(`RFBUF_OFF)             left_shift `N(`RFBUF_LEN+`EXEC_LEN);
	
	wire `N(`EXEC_LEN*`XLEN)        chain_this_r   `N(`RFBUF_LEN+1);
	wire `N(`EXEC_LEN*`RGBIT)       chain_this_sel `N(`RFBUF_LEN+1);
	wire `N(`EXEC_OFF)              chain_this_len `N(`RFBUF_LEN+1);
	
	wire `N(`RFBUF_LEN*`XLEN)       chain_left_r   `N(`RFBUF_LEN+`EXEC_LEN+1);
	wire `N(`RFBUF_LEN*`MEMB_OFF)   chain_left_cnt `N(`RFBUF_LEN+`EXEC_LEN+1);
	wire `N(`RFBUF_LEN*`RGBIT)      chain_left_sel `N(`RFBUF_LEN+`EXEC_LEN+1);
	wire `N(`RFBUF_OFF)             chain_left_len `N(`RFBUF_LEN+`EXEC_LEN+1);

	assign chain_this_r[0]     = 0;
	assign chain_this_sel[0]   = 0;
	assign chain_this_len[0]   = 0;
	assign chain_left_r[0]     = 0;
	assign chain_left_cnt[0]   = 0;
	assign chain_left_sel[0]   = 0;
	assign chain_left_len[0]   = 0;
	
	wire `N(`EXEC_LEN*`MEMB_OFF)    rg_count;

    generate
    genvar i;
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_buf
	    assign buf_count[`IDX(i,`MEMB_OFF)]      = subone(mem_release,buf_cnt[`IDX(i,`MEMB_OFF)]);
	
	    assign this_flag[i]                      = (i<buf_len) & (buf_count[`IDX(i,`MEMB_OFF)]==0) & (buf_sel[`IDX(i,`RGBIT)]!=0) & (chain_this_len[i]<`EXEC_LEN);
		
		assign this_shift[i]                     = this_flag[i] ? chain_this_len[i] : `EXEC_LEN;
		
		assign chain_this_r[i+1]                 = chain_this_r[i]|( buf_r[`IDX(i,`XLEN)]<<(this_shift[i]*`XLEN) );
		
		assign chain_this_sel[i+1]               = chain_this_sel[i]|( buf_sel[`IDX(i,`RGBIT)]<<(this_shift[i]*`RGBIT) );
		
		assign chain_this_len[i+1]               = chain_this_len[i] + this_flag[i];
		
		assign left_shift[i]                     = ( (i<buf_len) & (~this_flag[i]) ) ?  chain_left_len[i] : `RFBUF_LEN; 		
		
		assign chain_left_r[i+1]                 = chain_left_r[i]|( buf_r[`IDX(i,`XLEN)]<<(left_shift[i]*`XLEN) );
		
	    assign chain_left_cnt[i+1]               = chain_left_cnt[i]|( buf_count[`IDX(i,`MEMB_OFF)]<<(left_shift[i]*`MEMB_OFF) );
		
		assign chain_left_sel[i+1]               = chain_left_sel[i]|( buf_sel[`IDX(i,`RGBIT)]<<(left_shift[i]*`RGBIT) );
		
		assign chain_left_len[i+1]               = chain_left_len[i] + ( (i<buf_len) & (~this_flag[i]) );
	end
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_in
`ifdef REGISTER_EXEC
	    assign rg_count[`IDX(i,`MEMB_OFF)]       = subone(mem_release,rg_cnt[`IDX(i,`MEMB_OFF)]);
`else
        assign rg_count[`IDX(i,`MEMB_OFF)]       = rg_cnt[`IDX(i,`MEMB_OFF)];
`endif	    
    
	    assign left_shift[`RFBUF_LEN+i]          = (rg_sel[`IDX(i,`RGBIT)]!=0) ? chain_left_len[`RFBUF_LEN+i] : `RFBUF_LEN;
      
        assign chain_left_r[`RFBUF_LEN+i+1]      = chain_left_r[`RFBUF_LEN+i]|( rg_data[`IDX(i,`XLEN)]<<(left_shift[`RFBUF_LEN+i]*`XLEN) );
		
		assign chain_left_cnt[`RFBUF_LEN+i+1]    = chain_left_cnt[`RFBUF_LEN+i]|( rg_count[`IDX(i,`MEMB_OFF)]<<(left_shift[`RFBUF_LEN+i]*`MEMB_OFF) );
		
		assign chain_left_sel[`RFBUF_LEN+i+1]    = chain_left_sel[`RFBUF_LEN+i]|( rg_sel[`IDX(i,`RGBIT)]<<(left_shift[`RFBUF_LEN+i]*`RGBIT) );
		
		assign chain_left_len[`RFBUF_LEN+i+1]    = chain_left_len[`RFBUF_LEN+i] + (rg_sel[`IDX(i,`RGBIT)]!=0);
	end
    endgenerate	
	
	wire `N(`EXEC_LEN*`XLEN)        this_data    = direct_mode ? rg_data : chain_this_r[`RFBUF_LEN];
	
	wire `N(`EXEC_LEN*`RGBIT)       this_sel     = direct_mode ? rg_sel  : chain_this_sel[`RFBUF_LEN];
	
	assign rf_release =  chain_this_len[`RFBUF_LEN];	
	
    `FFx(buf_r,0)
	if ( ~direct_mode )
	    buf_r <= chain_left_r[`RFBUF_LEN+`EXEC_LEN];
	else;
	
	`FFx(buf_cnt,0)
	if ( ~direct_mode )
	    buf_cnt <= chain_left_cnt[`RFBUF_LEN+`EXEC_LEN];
	else;

	`FFx(buf_sel,0)
	if ( ~direct_mode )
	    buf_sel <= chain_left_sel[`RFBUF_LEN+`EXEC_LEN];
	else;

	`FFx(buf_len,0)
	if ( ~direct_mode )
	    buf_len <= chain_left_len[`RFBUF_LEN+`EXEC_LEN];
	else;	
	
	
	generate
    for (i=1;i<=31;i=i+1) begin:gen_rf
        `FFx(r[i],0) begin:u_r
		    integer n;
			for(n=0;n<`EXEC_LEN;n=n+1) begin
			    if (i==this_sel[`IDX(n,`RGBIT)])
				    r[i] <= this_data[`IDX(n,`XLEN)];
			end
            if ( i==mem_sel )
			    r[i] <= mem_data;			
		end
    end

    for(i=0;i<`EXEC_LEN;i=i+1) begin:gen_out
	    `COMB begin:gen_out_comb_rs0
		    integer n;
            rs0_data[`IDX(i,`XLEN)] = (rs0_sel[`IDX(i,`RGBIT)]==0) ? 0 : r[rs0_sel[`IDX(i,`RGBIT)]];
			for (n=0;n<`RFBUF_LEN;n=n+1) begin
			    if ( ( rs0_sel[`IDX(i,`RGBIT)]==buf_sel[`IDX(n,`RGBIT)] ) & (n<buf_len) )
				    rs0_data[`IDX(i,`XLEN)] = buf_r[`IDX(n,`XLEN)];
			end	
        end		

	    `COMB begin:gen_out_comb_rs1
		    integer n;
            rs1_data[`IDX(i,`XLEN)] = (rs1_sel[`IDX(i,`RGBIT)]==0) ? 0 : r[rs1_sel[`IDX(i,`RGBIT)]];
			for (n=0;n<`RFBUF_LEN;n=n+1) begin
			    if ( ( rs1_sel[`IDX(i,`RGBIT)]==buf_sel[`IDX(n,`RGBIT)] ) & (n<buf_len) )
				    rs1_data[`IDX(i,`XLEN)] = buf_r[`IDX(n,`XLEN)];
			end	
        end	
	end
	endgenerate
	
endmodule
