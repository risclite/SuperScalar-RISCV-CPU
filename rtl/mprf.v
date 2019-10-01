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
    input                                clk,
	input                                rst,
   
	input  `N(`EXEC_LEN*`RGBIT)          rd_sel,
	input  `N(`EXEC_LEN*`MMCMB_OFF)      rd_order,
	input  `N(`EXEC_LEN*`XLEN)           rd_data,
               
	input  `N(`EXEC_LEN*`RGBIT)          rs0_sel,
	input  `N(`EXEC_LEN*`RGBIT)          rs1_sel,    	
	output reg `N(`EXEC_LEN*`XLEN)       rs0_data,
	output reg `N(`EXEC_LEN*`XLEN)       rs1_data,

    //from membuf
	input                                mem_release,
	input  `N(`RGBIT)                    mem_sel,
	input  `N(`XLEN)                     mem_data,
    //from sys_csr
	input                                clear_pipeline,
	//to schedule
	output `N(`RFBUF_OFF)                mprf_rf_num
);

    `include "include_func.v"
	
//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------
    reg `N(`XLEN)                       r [31:1];

	wire `N(`EXEC_OFF)                  exec_num         `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`RGBIT)           chain_in_sel     `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`MMCMB_OFF)       chain_in_order   `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)            chain_in_data    `N(`EXEC_LEN+1);

	wire `N(`EXEC_OFF)                  in_length;
    wire `N(`EXEC_LEN*`RGBIT)           in_sel;
	wire `N(`EXEC_LEN*`MMCMB_OFF)       in_order;
	wire `N(`EXEC_LEN*`XLEN)            in_data;

	reg `N(`RFBUF_OFF)                  rfbuf_length;
    reg `N(`RFBUF_LEN*`RGBIT)           rfbuf_sel;
	reg `N(`RFBUF_LEN*`MMCMB_OFF)       rfbuf_order;
	reg `N(`RFBUF_LEN*`XLEN)            rfbuf_data;
	
	wire `N(`WRRG_LEN*`RGBIT)           wrrg_sel;
	wire `N(`WRRG_LEN*`XLEN)            wrrg_data;
	
	wire `N(`RFBUF_OFF)                 wrrf_num         `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`RGBIT)          chain_wrrf_sel   `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`MMCMB_OFF)      chain_wrrf_order `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`XLEN)           chain_wrrf_data  `N(`RFBUF_LEN+1);
	
	wire `N(`WRRG_OFF)                  wrrg_num         `N(`RFBUF_LEN+1);
	wire `N(`WRRG_LEN*`RGBIT)           chain_wrrg_sel   `N(`RFBUF_LEN+1);
	wire `N(`WRRG_LEN*`XLEN)            chain_wrrg_data  `N(`RFBUF_LEN+1);
	


    genvar i;

//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------	

    assign exec_num[0]       = 0;
	assign chain_in_sel[0]   = 0;
	assign chain_in_order[0] = 0;
	assign chain_in_data[0]  = 0;

    generate 
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_exec
	    wire `N(`EXEC_OFF)  go_exec = (rd_sel[`IDX(i,`RGBIT)]!=0) ? exec_num[i] : `EXEC_LEN;
        
		assign exec_num[i+1] = (rd_sel[`IDX(i,`RGBIT)]!=0) ? ( exec_num[i]+1'b1 ) : exec_num[i];		
		assign chain_in_sel[i+1] = chain_in_sel[i]|( rd_sel[`IDX(i,`RGBIT)]<<(go_exec*`RGBIT) );
		assign chain_in_order[i+1] = chain_in_order[i]|( rd_order[`IDX(i,`MMCMB_OFF)]<<(go_exec*`MMCMB_OFF) );
		assign chain_in_data[i+1]  = chain_in_data[i]|( rd_data[`IDX(i,`XLEN)]<<(go_exec*`XLEN) );
    end
    endgenerate
	
	assign in_length = exec_num[`EXEC_LEN];
	assign in_sel = chain_in_sel[`EXEC_LEN];
	assign in_order = chain_in_order[`EXEC_LEN];
	assign in_data = chain_in_data[`EXEC_LEN];
	
	
	assign wrrf_num[0]                  = 0;
	assign chain_wrrf_sel[0]            = 0;
	assign chain_wrrf_order[0]          = 0;
	assign chain_wrrf_data[0]           = 0;
	assign wrrg_num[0]                  = 0;
	assign chain_wrrg_sel[0]            = 0;
	assign chain_wrrg_data[0]           = 0;

    generate 
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_main
		
		wire                buffer  = i<rfbuf_length;
		wire `N(`RFBUF_OFF) count   = buffer ? i : ( i-rfbuf_length );
		wire                fetch   = (i>=rfbuf_length) & (count<in_length);
		wire `N(`RGBIT)     sel     = buffer ? ( rfbuf_sel>>(count*`RGBIT) ) : ( in_sel>>(count*`RGBIT) );
		wire `N(`MMCMB_OFF) order_i = buffer ? ( rfbuf_order>>(count*`MMCMB_OFF) ) : ( in_order>>(count*`MMCMB_OFF) );
        wire `N(`MMCMB_OFF) order   = get_order(order_i,mem_release);
        wire `N(`XLEN)      data    = buffer ? ( rfbuf_data>>(count*`XLEN) ) : ( in_data>>(count*`XLEN) );		
		
		wire   go_wrrg = buffer & (order==0) & (wrrg_num[i]<`WRRG_LEN); 
	
        wire   go_wrrf = ( buffer & ( ( (order==0) & (wrrg_num[i]==`WRRG_LEN) )|( (order!=0) & ~clear_pipeline ) ) )|( fetch & ( ~clear_pipeline|(order==0) ) );

		assign wrrf_num[i+1] = go_wrrf ? ( wrrf_num[i] + 1'b1 ) : wrrf_num[i];
		
		wire `N(`RFBUF_OFF) wrrf_shift    = go_wrrf ? wrrf_num[i] : `RFBUF_LEN;
		
		assign chain_wrrf_sel[i+1] = chain_wrrf_sel[i]|(sel<<(wrrf_shift*`RGBIT));
		
		assign chain_wrrf_order[i+1] = chain_wrrf_order[i]|(order<<(wrrf_shift*`MMCMB_OFF));
		
		assign chain_wrrf_data[i+1] = chain_wrrf_data[i]|(data<<(wrrf_shift*`XLEN));
		
		assign wrrg_num[i+1] = go_wrrg ? ( wrrg_num[i] + 1'b1  ) : wrrg_num[i];
		
		wire `N(`WRRG_OFF) wrrg_shift = go_wrrg ? wrrg_num[i] : `WRRG_LEN;
		
		assign chain_wrrg_sel[i+1] = chain_wrrg_sel[i]|(sel<<(wrrg_shift*`RGBIT));
		
		assign chain_wrrg_data[i+1] = chain_wrrg_data[i]|(data<<(wrrg_shift*`XLEN));
	
	end
	endgenerate

	`FFx(rfbuf_length,0)
	rfbuf_length <= wrrf_num[`RFBUF_LEN];

    `FFx(rfbuf_sel,0)
	rfbuf_sel <= chain_wrrf_sel[`RFBUF_LEN];
	    
	`FFx(rfbuf_order,0)
	rfbuf_order <= chain_wrrf_order[`RFBUF_LEN];
	    
	`FFx(rfbuf_data,0)
	rfbuf_data <= chain_wrrf_data[`RFBUF_LEN];
	
    assign wrrg_sel = chain_wrrg_sel[`RFBUF_LEN];

	assign wrrg_data = chain_wrrg_data[`RFBUF_LEN];

	generate
    for (i=1;i<=31;i=i+1) begin:gen_rf
        `FFx(r[i],0) begin:ff_r
		    integer n;
			for(n=0;n<`WRRG_LEN;n=n+1) begin
			    if (i==wrrg_sel[`IDX(n,`RGBIT)])
				    r[i] <= wrrg_data[`IDX(n,`XLEN)];
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
			    if ( ( rs0_sel[`IDX(i,`RGBIT)]==rfbuf_sel[`IDX(n,`RGBIT)] ) & (n<rfbuf_length) )
				    rs0_data[`IDX(i,`XLEN)] = rfbuf_data[`IDX(n,`XLEN)];
			end	
        end		

	    `COMB begin:gen_out_comb_rs1
		    integer n;
            rs1_data[`IDX(i,`XLEN)] = (rs1_sel[`IDX(i,`RGBIT)]==0) ? 0 : r[rs1_sel[`IDX(i,`RGBIT)]];
			for (n=0;n<`RFBUF_LEN;n=n+1) begin
			    if ( ( rs1_sel[`IDX(i,`RGBIT)]==rfbuf_sel[`IDX(n,`RGBIT)] ) & (n<rfbuf_length) )
				    rs1_data[`IDX(i,`XLEN)] = rfbuf_data[`IDX(n,`XLEN)];
			end	
        end	
	end
	endgenerate	

    assign mprf_rf_num = rfbuf_length;
	
endmodule
