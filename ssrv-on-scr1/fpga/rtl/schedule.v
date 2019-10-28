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

module schedule(

    input                                                                    clk,
    input                                                                    rst,
 
    input  `N(`FETCH_LEN)                                                    fetch_vld,
    input  `N(`FETCH_LEN*`XLEN)                                              fetch_instr,
    input  `N(`FETCH_LEN*`XLEN)                                              fetch_pc,
	input  `N(`FETCH_LEN)                                                    fetch_err,
    output `N(`FETCH_OFF)                                                    fetch_offset,
 
	output reg `N(`EXEC_LEN)                                                 exec_vld,
	output reg `N(`EXEC_LEN*`XLEN)                                           exec_instr,
	output reg `N(`EXEC_LEN*`XLEN)                                           exec_pc,	
	output reg `N(`EXEC_LEN*`EXEC_PARA_LEN+`FETCH_PARA_LEN-`EXEC_PARA_LEN)   exec_para,
	output reg `N(`EXEC_LEN*`MMCMB_OFF)                                      exec_order,
 
	input  `N(`RGLEN)                                                        membuf_rd_list,
	input  `N(`MMBUF_OFF)                                                    membuf_mem_num,
	input  `N(`RFBUF_OFF)                                                    mprf_rf_num,
    input                                                                    mem_release,
    input                                                                    clear_pipeline,
	input                                                                    jump_vld,
	input  `N(`XLEN)                                                         jump_pc,
    output `N(`XLEN)                   	                                     schedule_int_pc
	
);

    `include "include_func.v"

//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------
    wire `N(`FETCH_LEN*`FETCH_PARA_LEN)      fetch_para;
	wire `N(`FETCH_LEN*`MMCMB_OFF)           fetch_order;
    wire `N(`FETCH_LEN+1)                    fetch_pick_flag;
    wire `N(`FETCH_OFF)                      chain_fetch_offset      `N(`FETCH_LEN+1);


    reg  `N(`MMBUF_OFF)                      mem_num                 `N(`SDBUF_LEN+1);
	reg  `N(`RFBUF_OFF)                      rf_num                  `N(`SDBUF_LEN+1);
	reg  `N(`RGLEN)                          rs_list                 `N(`SDBUF_LEN+1);
	reg  `N(`RGLEN)                          rd_list                 `N(`SDBUF_LEN+1);
	reg  `N(`EXEC_OFF)                       exec_num                `N(`SDBUF_LEN+1);
	reg  `N(`SDBUF_OFF)                      sdbuf_num               `N(`SDBUF_LEN+1);
	reg                                      mem_not_exec            `N(`SDBUF_LEN+1);
	reg  `N(`EXEC_OFF)                       go_exec                 `N(`SDBUF_LEN);
    reg  `N(`SDBUF_OFF)                      go_sdbuf                `N(`SDBUF_LEN);	
	
	wire                                     chain_sdbuf_has_special `N(`SDBUF_LEN+1);
	wire `N(`EXEC_OFF)                       chain_exec_mem_num      `N(`SDBUF_LEN+1);
	wire `N(`EXEC_OFF)                       chain_exec_rf_num       `N(`SDBUF_LEN+1);
	wire `N(`RGLEN)                          chain_exec_rd_list      `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_OFF)                      chain_sdbuf_mem_num     `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN)                       chain_exec_vld          `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_exec_instr        `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_exec_pc           `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`FETCH_PARA_LEN)       chain_exec_para         `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`MMCMB_OFF)            chain_exec_order        `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN)                      chain_sdbuf_vld         `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`XLEN)                chain_sdbuf_instr       `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`XLEN)                chain_sdbuf_pc          `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`FETCH_PARA_LEN)      chain_sdbuf_para        `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`MMCMB_OFF)           chain_sdbuf_order       `N(`SDBUF_LEN+1);
	wire                                     chain_find_mem          `N(`SDBUF_LEN+1);
	wire `N(`XLEN)                           chain_find_pc           `N(`SDBUF_LEN+1);	

    reg  `N(`SDBUF_LEN)                      sdbuf_vld;
    reg  `N(`SDBUF_LEN*`XLEN)                sdbuf_instr;
	reg  `N(`SDBUF_LEN*`XLEN)                sdbuf_pc;
	reg  `N(`SDBUF_LEN*`FETCH_PARA_LEN)      sdbuf_para;
	reg  `N(`SDBUF_LEN*`MMCMB_OFF)           sdbuf_order;
	reg  `N(`SDBUF_OFF)                      sdbuf_length;
    reg  `N(`EXEC_OFF)                       exec_mem_num;
	reg  `N(`EXEC_OFF)                       exec_rf_num;
	reg  `N(`RGLEN)                          exec_rd_list;
	reg  `N(`MMBUF_OFF)                      sdbuf_mem_num;
	reg                                      sdbuf_has_special;
	

    genvar i;
//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------

    //fetch processing
	
	wire `N(`SDBUF_LEN) sdbuf_left_vld = ( 1'b1<<(`SDBUF_LEN - sdbuf_length)) - 1'b1;
	
	wire `N(`MMCMB_OFF) fetch_initial_num = membuf_mem_num + sdbuf_mem_num;
	
	assign fetch_pick_flag[0]      = 1;
	assign chain_fetch_offset[0]   = 0;
	
	generate
	for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_fetch
		wire                       vld = fetch_vld[i] & sdbuf_left_vld[i];
		wire `N(`XLEN)           instr = fetch_instr[`IDX(i,`XLEN)];
		wire                       err = fetch_err[i];
        wire `N(`FETCH_PARA_LEN)  para = rv_dispatch(vld,instr,err);
		
		assign fetch_para[`IDX(i,`FETCH_PARA_LEN)] = para;
	    assign     fetch_order[`IDX(i,`MMCMB_OFF)] = ( ( i==0 ) ? fetch_initial_num : fetch_order[`IDX(i-1,`MMCMB_OFF)] ) + para[1+3*`RGBIT];
	    assign                fetch_pick_flag[i+1] = fetch_pick_flag[i] & ~(|(para>>`EXEC_PARA_LEN));   
	    assign             chain_fetch_offset[i+1] = (vld & fetch_pick_flag[i]) ? (i+1) : chain_fetch_offset[i]; 	
	end
	endgenerate

    wire `N(`FETCH_LEN) fetch_new_vld  = sdbuf_has_special ? 0 : ( fetch_vld & sdbuf_left_vld & fetch_pick_flag[`FETCH_LEN-1:0] );

    assign fetch_offset = sdbuf_has_special ? 0 : chain_fetch_offset[`FETCH_LEN];

    wire `N(`SDBUF_LEN) sdbuf_fetch_vld = fetch_new_vld<<sdbuf_length;


	
    //sdbuf processing	

	always@* begin
        mem_num[0]         =  membuf_mem_num + exec_mem_num;
        rf_num[0]          =  mprf_rf_num + exec_rf_num;
		rs_list[0]         =  membuf_rd_list|exec_rd_list;
        rd_list[0]         =  membuf_rd_list|exec_rd_list;	
	    exec_num[0]        =  0;
		sdbuf_num[0]       =  0;
		mem_not_exec[0]    =  0;
	end
	
	assign chain_sdbuf_has_special[0]    = 0;
    assign chain_exec_mem_num[0]         = 0;
	assign chain_exec_rf_num[0]          = 0;
	assign chain_exec_rd_list[0]         = 0;
	assign chain_sdbuf_mem_num[0]        = 0;
	assign chain_exec_vld[0]             = 0;
	assign chain_exec_instr[0]           = 0;
	assign chain_exec_pc[0]              = 0;
	assign chain_exec_para[0]            = 0;
	assign chain_exec_order[0]           = 0;
	assign chain_sdbuf_vld[0]            = 0;
	assign chain_sdbuf_instr[0]          = 0;
	assign chain_sdbuf_pc[0]             = 0;
	assign chain_sdbuf_para[0]           = 0;
	assign chain_sdbuf_order[0]          = 0;
	assign chain_find_mem[0]             = 0;
	assign chain_find_pc[0]              = 0;


    generate
	for (i=0;i<`SDBUF_LEN;i=i+1) begin:gen_sdbuf
	    wire special,mem,alu;
		wire `N(`RGBIT) rd,rs1,rs0;
		wire                                buffer = sdbuf_vld[i];
		wire                                 fetch = sdbuf_fetch_vld[i];
		wire `N(`SDBUF_OFF)                  count = (i<sdbuf_length) ? i : ( i-sdbuf_length );
		wire `N(`XLEN)                       instr = (i<sdbuf_length) ? ( sdbuf_instr>>(count*`XLEN) ) : ( fetch_instr>>(count*`XLEN) );
		wire `N(`XLEN)                          pc = (i<sdbuf_length) ? ( sdbuf_pc>>(count*`XLEN) ) : ( fetch_pc>>(count*`XLEN) );
		wire `N(`FETCH_PARA_LEN)              para = (i<sdbuf_length) ? ( sdbuf_para>>(count*`FETCH_PARA_LEN) ) : ( fetch_para>>(count*`FETCH_PARA_LEN) );
		wire `N(`MMCMB_OFF)                  order = (i<sdbuf_length) ? ( sdbuf_order>>(count*`MMCMB_OFF) ) : ( fetch_order>>(count*`MMCMB_OFF) );
		wire                                   vld = buffer|fetch;
		assign                             special = vld & (|(para>>`EXEC_PARA_LEN));
		assign                {mem,alu,rd,rs1,rs0} = vld ? para : 0;
		
		wire                                   hit = ( |( rs_list[i]&( ((1'b1<<rs0)|(1'b1<<rs1))>>1 ) ) )|( |( rd_list[i]&( (1'b1<<rd)>>1 ) ) );
		
	    always @( mem_num[i],rf_num[i],rs_list[i],rd_list[i],exec_num[i],sdbuf_num[i],mem_not_exec[i],mem,hit,rd,rs0,rs1,alu,special)
		begin
		    mem_num[i+1]       = mem_num[i];
			rf_num[i+1]        = rf_num[i];
			rs_list[i+1]       = rs_list[i];
			rd_list[i+1]       = rd_list[i];
		    exec_num[i+1]      = exec_num[i];
			sdbuf_num[i+1]     = sdbuf_num[i];
			mem_not_exec[i+1]  = mem_not_exec[i];
			go_exec[i]         = `EXEC_LEN;
			go_sdbuf[i]        = `SDBUF_LEN;
			
			if ( mem & ~special ) begin
			    if ( hit|mem_not_exec[i]|(exec_num[i]==`EXEC_LEN)|(mem_num[i]==`MMBUF_LEN) ) begin
				    go_sdbuf[i]       = sdbuf_num[i];
					sdbuf_num[i+1]    = sdbuf_num[i] + 1'b1;
					mem_not_exec[i+1] = 1;
					rs_list[i+1]      = rs_list[i]|( (1'b1<<rd)>>1 );
					rd_list[i+1]      = rd_list[i]|( ((1'b1<<rd)|(1'b1<<rs0)|(1'b1<<rs1))>>1 );
				end else begin
				    go_exec[i]        = exec_num[i];
					exec_num[i+1]     = (exec_num[i]==`EXEC_LEN) ? `EXEC_LEN : ( exec_num[i] + 1'b1 );
					mem_num[i+1]      = (mem_num[i]==`MMBUF_LEN) ? `MMBUF_LEN : ( mem_num[i] + 1'b1 );
					rs_list[i+1]      = rs_list[i]|( (1'b1<<rd)>>1 );
					rd_list[i+1]      = rd_list[i]|( (1'b1<<rd)>>1 );					
				end
			end
			
			if ( alu & (rd!=0) & ~special ) begin
				if ( hit|(exec_num[i]==`EXEC_LEN)|(rf_num[i]==`RFBUF_LEN) ) begin
				    go_sdbuf[i]      = sdbuf_num[i];
					sdbuf_num[i+1]   = sdbuf_num[i] + 1'b1;
					rf_num[i+1]      = (rf_num[i]==`RFBUF_LEN) ? `RFBUF_LEN : ( rf_num[i] + 1'b1 ); //add this to keep every skipped OP has its seat in RFBUF.
					rs_list[i+1]     = rs_list[i]|( (1'b1<<rd)>>1 );
					rd_list[i+1]     = rd_list[i]|( ((1'b1<<rd)|(1'b1<<rs0)|(1'b1<<rs1))>>1 );
				end else begin
				    go_exec[i]       = exec_num[i];
					exec_num[i+1]    = (exec_num[i]==`EXEC_LEN) ? `EXEC_LEN : ( exec_num[i] + 1'b1 );
					rf_num[i+1]      = (rf_num[i]==`RFBUF_LEN) ? `RFBUF_LEN : ( rf_num[i] + 1'b1 );
					rs_list[i+1]     = rs_list[i]|( (1'b1<<rd)>>1 );
				end
			end
			
            if ( special ) begin
                if ( hit|(exec_num[i]==`EXEC_LEN)|((rd!=0)&(rf_num[i]==`RFBUF_LEN))|( (|(para>>(`EXEC_PARA_LEN+3))) & ~((i==0) & (order==1)) ) ) begin
				    go_sdbuf[i]      = sdbuf_num[i];
					sdbuf_num[i+1]   = sdbuf_num[i] + 1'b1;
                end else begin
				    go_exec[i]       = `EXEC_LEN - 1'b1;
				end
			end
	    end		
		
		wire `N(`MMCMB_OFF) order_out = get_order(order,mem_release);		
		
		wire vld_out = clear_pipeline ? ( ~(fetch|(order_out!=0)|special) ) : ( jump_vld ? (~fetch) : 1'b1 );

        assign chain_sdbuf_has_special[i+1] = chain_sdbuf_has_special[i]|( vld_out&special&(go_sdbuf[i]!=`SDBUF_LEN) );
		assign chain_sdbuf_mem_num[i+1]     = chain_sdbuf_mem_num[i] + (vld_out&mem);		
		assign chain_exec_mem_num[i+1]      = (go_exec[i]!=`EXEC_LEN) ? ( chain_exec_mem_num[i] + (vld_out&mem) ) : chain_exec_mem_num[i];
		assign chain_exec_rf_num[i+1]       = (go_exec[i]!=`EXEC_LEN) ? ( chain_exec_rf_num[i] + (vld_out&alu&(rd!=0)) ) : chain_exec_rf_num[i];
		assign chain_exec_rd_list[i+1]      = ( (go_exec[i]!=`EXEC_LEN) & vld_out & mem ) ? ( chain_exec_rd_list[i]|( (1'b1<<rd)>>1) ) : chain_exec_rd_list[i];
		
		assign chain_exec_vld[i+1]          = chain_exec_vld[i]|(vld_out<<go_exec[i]); 
		assign chain_exec_instr[i+1]        = chain_exec_instr[i]|(instr<<(go_exec[i]*`XLEN));
		assign chain_exec_pc[i+1]           = chain_exec_pc[i]|(pc<<(go_exec[i]*`XLEN));
		assign chain_exec_para[i+1]         = chain_exec_para[i]|(para<<(go_exec[i]*`FETCH_PARA_LEN));
		assign chain_exec_order[i+1]        = chain_exec_order[i]|(order_out<<(go_exec[i]*`MMCMB_OFF));
		
		assign chain_sdbuf_vld[i+1]         = chain_sdbuf_vld[i]|(vld_out<<go_sdbuf[i]);
		assign chain_sdbuf_instr[i+1]       = chain_sdbuf_instr[i]|(instr<<(go_sdbuf[i]*`XLEN));
		assign chain_sdbuf_pc[i+1]          = chain_sdbuf_pc[i]|(pc<<(go_sdbuf[i]*`XLEN));
		assign chain_sdbuf_para[i+1]        = chain_sdbuf_para[i]|(para<<(go_sdbuf[i]*`FETCH_PARA_LEN));
		assign chain_sdbuf_order[i+1]       = chain_sdbuf_order[i]|(order_out<<(go_sdbuf[i]*`MMCMB_OFF));
		
		assign chain_find_mem[i+1]          = chain_find_mem[i]|( buffer & (mem|special) );
		assign chain_find_pc[i+1]           = chain_find_mem[i] ? chain_find_pc[i] : pc;		
	end
	endgenerate
	
	`FFx(sdbuf_has_special,0)
	sdbuf_has_special <= chain_sdbuf_has_special[`SDBUF_LEN];

    `FFx(exec_mem_num,0)
	exec_mem_num <= chain_exec_mem_num[`SDBUF_LEN];
	
	`FFx(exec_rf_num,0)
	exec_rf_num <= chain_exec_rf_num[`SDBUF_LEN];
	
	`FFx(exec_rd_list,0)
	exec_rd_list <= chain_exec_rd_list[`SDBUF_LEN];
	
	`FFx(sdbuf_mem_num,0)
	sdbuf_mem_num <= chain_sdbuf_mem_num[`SDBUF_LEN];	
	
	`FFx(exec_vld,0)
	exec_vld <= chain_exec_vld[`SDBUF_LEN];
	
	`FFx(exec_instr,0)
	exec_instr <= chain_exec_instr[`SDBUF_LEN];
	
	`FFx(exec_pc,0)
	exec_pc <= chain_exec_pc[`SDBUF_LEN];
	
 	generate  
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_exec_para
	    if (i==(`EXEC_LEN-1)) begin
		    `FFx(exec_para[i*`EXEC_PARA_LEN+:`FETCH_PARA_LEN],0)
	        exec_para[i*`EXEC_PARA_LEN+:`FETCH_PARA_LEN] <= chain_exec_para[`SDBUF_LEN]>>(i*`FETCH_PARA_LEN);
		end else begin
		    `FFx(exec_para[`IDX(i,`EXEC_PARA_LEN)],0)
			exec_para[`IDX(i,`EXEC_PARA_LEN)] <= chain_exec_para[`SDBUF_LEN]>>(i*`FETCH_PARA_LEN);
		end
	end
	endgenerate
	
	`FFx(exec_order,0)
	exec_order <= chain_exec_order[`SDBUF_LEN];
	
	`FFx(sdbuf_vld,0)
	sdbuf_vld <= chain_sdbuf_vld[`SDBUF_LEN];
	
	`FFx(sdbuf_instr,0)
	sdbuf_instr <= chain_sdbuf_instr[`SDBUF_LEN];
	
	`FFx(sdbuf_pc,0)
	sdbuf_pc <= chain_sdbuf_pc[`SDBUF_LEN];
	
	`FFx(sdbuf_para,0)
	sdbuf_para <= chain_sdbuf_para[`SDBUF_LEN];
	
	`FFx(sdbuf_order,0)
	sdbuf_order <= chain_sdbuf_order[`SDBUF_LEN];
	
	`FFx(sdbuf_length,0)
	sdbuf_length <= sdbuf_num[`SDBUF_LEN];

    assign schedule_int_pc = chain_find_mem[`SDBUF_LEN] ? chain_find_pc[`SDBUF_LEN] : ( jump_vld ? jump_pc : fetch_pc);
	

endmodule

