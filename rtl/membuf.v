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
    //system signals
    input                                    clk,
	input                                    rst,
	
	//from alu/alu_mul
	input  `N(`EXEC_LEN)                     mem_vld,
	input  `N(`EXEC_LEN*`MEMB_PARA)          mem_para,
	input  `N(`EXEC_LEN*`XLEN)               mem_addr,
	input  `N(`EXEC_LEN*`XLEN)               mem_wdata,
	
	//to schedule
    output                                   mem_release,

	//to mprf
    output     `N(5)                         mem_sel,
    output reg `N(`XLEN)                     mem_data,	

	//to top level
    output                                   dmem_req,
	output                                   dmem_cmd,
	output `N(2)                             dmem_width,
	output `N(`XLEN)                         dmem_addr,
	output `N(`XLEN)                         dmem_wdata,
	input  `N(`XLEN)                         dmem_rdata,
	input                                    dmem_resp

);
  
	reg  `N(`MEMB_LEN*`MEMB_UNIT)            buff_bits;
	reg  `N(`MEMB_OFF)                       buff_len;
    
	wire                                     this_op;
	reg                                      load_vld;
	reg [2:0]                                load_para;
	reg [4:0]                                load_rg;
	
    wire `N(`EXEC_OFF)                       chain_len `N(`EXEC_LEN+1);
    wire `N(`EXEC_LEN*`MEMB_UNIT)            chain_bits `N(`EXEC_LEN+1);

    assign chain_len[0]        = 0;
    assign chain_bits[0]       = 0;

    wire `N(`EXEC_OFF)                       chain_shift `N(`EXEC_LEN);

    generate
    genvar i;
    for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_exec
    	assign chain_len[i+1]  = chain_len[i] + mem_vld[i];

    	assign chain_shift[i]  = mem_vld[i] ? chain_len[i] : `EXEC_LEN;

    	assign chain_bits[i+1] = chain_bits[i]|({mem_wdata[`IDX(i,`XLEN)],mem_addr[`IDX(i,`XLEN)],mem_para[`IDX(i,`MEMB_PARA)]}<<(chain_shift[i]*`MEMB_UNIT));
    end	
    endgenerate

    wire `N(`MEMB_LEN*`MEMB_UNIT) this_bits = buff_bits | ( chain_bits[`EXEC_LEN]<<(buff_len*`MEMB_UNIT) );

    `FFx(buff_bits,0)
	buff_bits <= this_bits>>(this_op*`MEMB_UNIT);
	
	`FFx(buff_len,0)
	buff_len <= buff_len + chain_len[`EXEC_LEN] - this_op;
	
	
	wire  bus_is_ready = dmem_resp;	
	
	reg  req_sent;
	`FFx(req_sent,1'b0)
	if ( ~req_sent|bus_is_ready )
	    req_sent <= ((buff_len!=0)|(|mem_vld));
	else;
	
	assign this_op = ((buff_len!=0)|(|mem_vld)) & (~req_sent|bus_is_ready);
	
	assign dmem_req = ((buff_len!=0)|(|mem_vld)) & (~req_sent|bus_is_ready);
	
	wire `N(`MEMB_UNIT) op_bits = this_bits[`IDX(0,`MEMB_UNIT)];
	
	assign dmem_cmd = op_bits[0];
	
	assign dmem_width = op_bits[2:1];
	
	assign dmem_addr[`XLEN-1:2] = op_bits[(`MEMB_PARA+2)+:(`XLEN-2)];
	
	assign dmem_addr[1:0] = (dmem_width==2'b00) ?  op_bits[`MEMB_PARA+:2] : ( (dmem_width==2'b01) ? {op_bits[`MEMB_PARA+1],1'b0} : 2'b00  );
	
	assign dmem_wdata = op_bits[(`MEMB_PARA+`XLEN)+:`XLEN];
		
	`FFx(load_vld,1'b0)
	if ( this_op )
	    load_vld <= ~op_bits[0];
	else if ( bus_is_ready )
	    load_vld <= 1'b0;
	else;
	
	`FFx(load_para,3'b0)
	if ( this_op )
	    load_para <= op_bits[3:1];
	else;
	
	`FFx(load_rg,0)
	if ( this_op )
	    load_rg <= op_bits[8:4];
	else;
	
	assign mem_sel = (load_vld & bus_is_ready) ? load_rg : 5'h0;
	
	`COMB
	if ( load_para[2] )
	    mem_data = load_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	else if ( load_para[1] )
	    mem_data = dmem_rdata;
	else 
	    mem_data = load_para[0] ? { {16{dmem_rdata[15]}}, dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	
    assign mem_release = this_op;
	
endmodule