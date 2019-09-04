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
module membuf(
    input                                    clk,
	input                                    rst,

	input  `N(`EXEC_LEN)                     mem_vld,
	input  `N(`EXEC_LEN*`MMBUF_PARA_LEN)     mem_para,
	input  `N(`EXEC_LEN*`XLEN)               mem_addr,
	input  `N(`EXEC_LEN*`XLEN)               mem_wdata,
	input  `N(`EXEC_LEN*`XLEN)               mem_pc,
	
    output                                   mem_release,
	output `N(`RGLEN)                        membuf_rd_list,
	output `N(`MMBUF_OFF)                    membuf_mem_num,

    output `N(`RGBIT)                        mem_sel,
    output reg `N(`XLEN)                     mem_data,	

	output                                   sys_vld,
	output `N(`XLEN)                         sys_instr,
	output `N(`XLEN)                         sys_pc,
	output `N(`XLEN)                         csr_rs,
	input  `N(`XLEN)                         csr_data,
	
	input  `N(`MULBUF_OFF)                   mul_this_order,
	output                                   mul_vld,
	output `N(3)                             mul_para,
	output `N(`XLEN)                         mul_rs0,
	output `N(`XLEN)                         mul_rs1,
	output                                   mul_accept,
	input                                    mul_in_vld,
	input  `N(`XLEN)                         mul_in_data,

	input                                    clear_pipeline,	
	input   `N(`XLEN)                        schedule_int_pc,
    output  `N(`XLEN)                        membuf_int_pc,
    output                                   dmem_exception,	

    output                                   dmem_req,
	output                                   dmem_cmd,
	output `N(2)                             dmem_width,
	output reg `N(`XLEN)                     dmem_addr,
	output `N(`XLEN)                         dmem_wdata,
	input  `N(`XLEN)                         dmem_rdata,
	input                                    dmem_resp,
	input                                    dmem_err

);


//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------
    reg  `N(`MMBUF_OFF)                      mmbuf_length;
	reg  `N(`MMBUF_LEN*`MMBUF_PARA_LEN)      mmbuf_para;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_addr;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_wdata;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_pc;
	reg  `N(`RGLEN)                          membuf_rd_list_ch0,membuf_rd_list_ch1;

    wire `N(`EXEC_OFF)                       in_length;
	wire `N(`EXEC_LEN*`MMBUF_PARA_LEN)       in_para;
	wire `N(`EXEC_LEN*`XLEN)                 in_addr,in_wdata,in_pc;

    wire `N(`EXEC_OFF)                       exec_num        `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`MMBUF_PARA_LEN)       chain_in_para   `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_addr   `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_wdata  `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_pc     `N(`EXEC_LEN+1);	

	wire `N(`MMBUF_OFF)                      mul_num         `N(`MMBUF_LEN+1);
	wire `N(`MMBUF_OFF)                      mul_order       `N(`MMBUF_LEN+1);
	wire `N(`RGLEN)                          chain_rd_list0  `N(`MMBUF_LEN+1);
	wire `N(`RGLEN)                          chain_rd_list1  `N(`MMBUF_LEN+1);
	wire `N(`RGLEN)                          chain_rd_list2  `N(`MMBUF_LEN+1);	

	reg                                      command_release;
    reg                                      request_go;
    reg                                      req_sent;	

    genvar i;
//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------

    //exec processing

    assign exec_num[0]          = 0;
    assign chain_in_para[0]     = 0;
	assign chain_in_addr[0]     = 0;
	assign chain_in_wdata[0]    = 0;
	assign chain_in_pc[0]       = 0;
	
	generate 
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_exec
	    wire `N(`EXEC_OFF) go_exec = mem_vld[i] ? exec_num[i] : `EXEC_LEN;
		
		assign exec_num[i+1]       = mem_vld[i] ? ( exec_num[i] + 1'b1 ) : exec_num[i];
		assign chain_in_para[i+1]  = chain_in_para[i]|( mem_para[`IDX(i,`MMBUF_PARA_LEN)]<<(go_exec*`MMBUF_PARA_LEN) );
		assign chain_in_addr[i+1]  = chain_in_addr[i]|( mem_addr[`IDX(i,`XLEN)]<<(go_exec*`XLEN) );
		assign chain_in_wdata[i+1] = chain_in_wdata[i]|( mem_wdata[`IDX(i,`XLEN)]<<(go_exec*`XLEN) );
		assign chain_in_pc[i+1]    = chain_in_pc[i]|( mem_pc[`IDX(i,`XLEN)]<<(go_exec*`XLEN) );
	end
	endgenerate
	
	//mul processing
	
	assign in_length = exec_num[`EXEC_LEN];
	assign in_para   = chain_in_para[`EXEC_LEN];
	assign in_addr   = chain_in_addr[`EXEC_LEN];
	assign in_wdata  = chain_in_wdata[`EXEC_LEN];
	assign in_pc     = chain_in_pc[`EXEC_LEN];
	
	wire `N(`MMBUF_OFF)                       combine_length = mmbuf_length + in_length;
	wire `N(`MMBUF_LEN*`MMBUF_PARA_LEN)       combine_para   = mmbuf_para|( in_para<<(mmbuf_length*`MMBUF_PARA_LEN) );
	wire `N(`MMBUF_LEN*`XLEN)                 combine_addr   = mmbuf_addr|( in_addr<<(mmbuf_length*`XLEN) );
	wire `N(`MMBUF_LEN*`XLEN)                 combine_wdata  = mmbuf_wdata|( in_wdata<<(mmbuf_length*`XLEN) );
	wire `N(`MMBUF_LEN*`XLEN)                 combine_pc     = mmbuf_pc|( in_pc<<(mmbuf_length*`XLEN) );
	
	assign mul_num[0]            = 0;
	assign mul_order[0]          = `MMBUF_LEN;
	assign chain_rd_list0[0]     = 0;
	assign chain_rd_list1[0]     = 0;
	assign chain_rd_list2[0]     = 0;
	
    generate
	for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mmbuf		
		wire `N(`MMBUF_PARA_LEN)    para = combine_para>>(i*`MMBUF_PARA_LEN);
		
		wire                        mul  = ( para>>(`MMBUF_PARA_LEN-2) )==2'b10;
		
		wire `N(`RGBIT)             rd   = para[3] ? 0 : (para>>4);
		
		assign mul_num[i+1]              = mul_num[i] + mul;
		
		assign mul_order[i+1]            = ( (mul_num[i]==mul_this_order) & mul ) ? i : mul_order[i];
	
	    assign chain_rd_list0[i+1]       = chain_rd_list0[i]|( (1'b1<<rd)>>1 );
		
		assign chain_rd_list1[i+1]       = (i==0) ? chain_rd_list1[i] : ( chain_rd_list1[i]|( (1'b1<<rd)>>1 ) );
		
		assign chain_rd_list2[i+1]       = ((i==0)|(i==1)) ? chain_rd_list2[i] : ( chain_rd_list2[i]|( (1'b1<<rd)>>1 ) );		
	end
	endgenerate
	
	wire active_vld = ( combine_length!=0 );	
	wire `N(`MMBUF_PARA_LEN) active_para = combine_para;
	wire `N(`XLEN) active_addr = combine_addr;
	wire `N(`XLEN) active_wdata = combine_wdata;
	wire `N(`XLEN) active_pc = combine_pc;
	
	wire alter_vld =  ( combine_length!=0 ) &  ( combine_length!=1 );
	wire `N(`MMBUF_PARA_LEN) alter_para = combine_para>>`MMBUF_PARA_LEN;
	wire `N(`XLEN) alter_addr = combine_addr>>`XLEN;
	wire `N(`XLEN) alter_wdata = combine_wdata>>`XLEN;
	wire `N(`XLEN) alter_pc = combine_pc>>`XLEN;    	
	
	
    assign mul_vld = mul_order[`MMBUF_LEN]!=`MMBUF_LEN;
	
	assign mul_para = combine_para>>(mul_order[`MMBUF_LEN]*`MMBUF_PARA_LEN);
	
	assign mul_rs0  = combine_addr>>(mul_order[`MMBUF_LEN]*`XLEN);
	
	assign mul_rs1  = combine_wdata>>(mul_order[`MMBUF_LEN]*`XLEN);
	
	assign mul_accept = active_vld & ( ( active_para>>(`MMBUF_PARA_LEN-2) )==2'b10 ) & mul_in_vld;

    //csr processing	
    assign sys_vld = active_vld & ( ( active_para>>(`MMBUF_PARA_LEN-2) )==2'b11 );
	
	assign sys_instr = active_wdata;	
	
	assign sys_pc = active_pc;
	
	assign csr_rs = active_addr;
	
    //mem processing		
	
	always @* 
	if ( active_vld & ~clear_pipeline )
	    if ( active_para[`MMBUF_PARA_LEN-1] )
		    command_release = active_para[`MMBUF_PARA_LEN-2] ? 1'b1 : mul_in_vld;
		else
		    command_release = req_sent & dmem_resp & ~dmem_err;
	else
	    command_release = 1'b0;
		
	assign mem_release = command_release;	

	always @*
	if ( active_vld )
	    if ( active_para[`MMBUF_PARA_LEN-1] )
		    request_go = ( active_para[`MMBUF_PARA_LEN-2] ? 1'b1 : mul_in_vld ) & ( alter_vld & ~alter_para[`MMBUF_PARA_LEN-1] );
		else
		    request_go = ~req_sent|( alter_vld & ~alter_para[`MMBUF_PARA_LEN-1] );
	else 
	    request_go = 1'b0;

    wire alter_select = active_para[`MMBUF_PARA_LEN-1]|req_sent;
    	
	`FFx(req_sent,1'b0)
	if ( ~req_sent|dmem_resp )
	    req_sent <= request_go;
	else;

    assign dmem_req = request_go & (~req_sent|dmem_resp);
	
	assign dmem_cmd = alter_select ? alter_para[3] : active_para[3];

    assign dmem_width = alter_select ? alter_para[1:0] : active_para[1:0];
	
	always @* begin
	    if ( alter_select ) begin
		    dmem_addr[2+:(`XLEN-2)] = alter_addr[2+:(`XLEN-2)];
			dmem_addr[1:0]          = (dmem_width==2'b00) ? alter_addr[1:0] : ( (dmem_width==2'b01) ? {alter_addr[1],1'b0} : 2'b00 ); 
		end else begin
		    dmem_addr[2+:(`XLEN-2)] = active_addr[2+:(`XLEN-2)];
			dmem_addr[1:0]          = (dmem_width==2'b00) ? active_addr[1:0] : ( (dmem_width==2'b01) ? {active_addr[1],1'b0} : 2'b00 ); 		
		end
	end	

	assign dmem_wdata               = alter_select ? alter_wdata : active_wdata;

	
	wire mem_to_mprf = active_vld & ( active_para[`MMBUF_PARA_LEN-1] ? ( active_para[`MMBUF_PARA_LEN-2] ? 1'b1 : mul_in_vld ) : ( req_sent & dmem_resp & ~dmem_err & ~active_para[3] ) );
	
	assign mem_sel = mem_to_mprf ? active_para[8:4] : 5'b0;
	
	`COMB
	if ( active_para[`MMBUF_PARA_LEN-1] )
	    mem_data = active_para[`MMBUF_PARA_LEN-2] ? csr_data : mul_in_data;
	else if ( active_para[2] )
	    mem_data = active_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	else if ( active_para[1] )
	    mem_data = dmem_rdata;
	else 
	    mem_data = active_para[0] ? { {16{dmem_rdata[15]}}, dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	

    //misc processing	

    assign dmem_exception =  req_sent & dmem_resp & dmem_err;

    assign membuf_int_pc = active_vld ? active_pc : schedule_int_pc;
	
	`FFx(mmbuf_length,0)
	mmbuf_length <= clear_pipeline ? 0 : (combine_length - command_release);
	
	assign membuf_mem_num = mmbuf_length;
	
	`FFx(mmbuf_para,0)
	mmbuf_para <= clear_pipeline ? 0 : (combine_para>>(command_release*`MMBUF_PARA_LEN));

    `FFx(mmbuf_addr,0)
	mmbuf_addr <= clear_pipeline ? 0 : (combine_addr>>(command_release*`XLEN));

    `FFx(mmbuf_wdata,0)
	mmbuf_wdata <= clear_pipeline ? 0 : (combine_wdata>>(command_release*`XLEN));

    `FFx(mmbuf_pc,0)
	mmbuf_pc <= clear_pipeline ? 0 : (combine_pc>>(command_release*`XLEN));
	
    `FFx(membuf_rd_list_ch0,0)
	membuf_rd_list_ch0 <= clear_pipeline ? 0 : (command_release ? chain_rd_list1[`MMBUF_LEN] : chain_rd_list0[`MMBUF_LEN]);

    `FFx(membuf_rd_list_ch1,0)
    membuf_rd_list_ch1 <= clear_pipeline ? 0 : (command_release ? chain_rd_list2[`MMBUF_LEN] : chain_rd_list1[`MMBUF_LEN]);	

    assign membuf_rd_list = command_release ? membuf_rd_list_ch1 : membuf_rd_list_ch0;		
	
endmodule