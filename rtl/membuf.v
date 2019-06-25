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
	
	//from sys_csr
	input                                    direct_mode,
	input                                    direct_reset,
	
	//from alu/alu_mul
	input  `N(`EXEC_LEN)                     mem_vld,
	input  `N(`EXEC_LEN*`MEMB_PARA)          mem_para,
	input  `N(`EXEC_LEN*`XLEN)               mem_addr,
	input  `N(`EXEC_LEN*`XLEN)               mem_wdata,
	input  `N(`EXEC_LEN*`XLEN)               mem_pc,
	
	//to schedule
    output                                   mem_release,

	//to mprf
    output     `N(5)                         mem_sel,
    output reg `N(`XLEN)                     mem_data,	

	//to top level
    output  reg                              dmem_req,
	output                                   dmem_cmd,
	output `N(2)                             dmem_width,
	output reg `N(`XLEN)                     dmem_addr,
	output `N(`XLEN)                         dmem_wdata,
	input  `N(`XLEN)                         dmem_rdata,
	input                                    dmem_resp

);
  
	reg  `N(`MEMB_LEN*`MEMB_PARA)            buff_para;
	reg  `N(`MEMB_LEN*`XLEN)                 buff_addr;
	reg  `N(`MEMB_LEN*`XLEN)                 buff_wdata;
	reg  `N(`MEMB_LEN*`XLEN)                 buff_pc;	
	reg  `N(`MEMB_OFF)                       buff_len;
    
	wire                                     this_op;
	
    wire `N(`EXEC_OFF)                       chain_len   `N(`EXEC_LEN+1);
    wire `N(`EXEC_LEN*`MEMB_PARA)            chain_para  `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_addr  `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_wdata `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_pc    `N(`EXEC_LEN+1);
    wire `N(`EXEC_OFF)                       chain_shift `N(`EXEC_LEN);
	
	reg                                      req_sent;	
	
    assign chain_len[0]        = 0;
    assign chain_para[0]       = 0;
	assign chain_addr[0]       = 0;
	assign chain_wdata[0]      = 0;
	assign chain_pc[0]         = 0;

    generate
    genvar i;
    for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_exec
    	assign chain_len[i+1]   = chain_len[i] + mem_vld[i];

    	assign chain_shift[i]   = mem_vld[i] ? chain_len[i] : `EXEC_LEN;

    	assign chain_para[i+1]  = chain_para[i]|(mem_para[`IDX(i,`MEMB_PARA)]<<(chain_shift[i]*`MEMB_PARA));
		
		assign chain_addr[i+1]  = chain_addr[i]|(mem_addr[`IDX(i,`XLEN)]<<(chain_shift[i]*`XLEN));
		
		assign chain_wdata[i+1] = chain_wdata[i]|(mem_wdata[`IDX(i,`XLEN)]<<(chain_shift[i]*`XLEN));
		
		assign chain_pc[i+1]    = chain_pc[i]|(mem_pc[`IDX(i,`XLEN)]<<(chain_shift[i]*`XLEN));
    end	
    endgenerate
	
	wire `N((`MEMB_LEN+1)*`MEMB_PARA) all_para  =  direct_mode ? chain_para[`EXEC_LEN]  : ( buff_para|(chain_para[`EXEC_LEN]<<(buff_len*`MEMB_PARA)) );
	
    wire `N((`MEMB_LEN+1)*`XLEN) all_addr       =  direct_mode ? chain_addr[`EXEC_LEN]  : ( buff_addr|(chain_addr[`EXEC_LEN]<<(buff_len*`XLEN)) );

    wire `N((`MEMB_LEN+1)*`XLEN) all_wdata      =  direct_mode ? chain_wdata[`EXEC_LEN] : ( buff_wdata|(chain_wdata[`EXEC_LEN]<<(buff_len*`XLEN)) );

    wire `N((`MEMB_LEN+1)*`XLEN) all_pc         =  direct_mode ? chain_pc[`EXEC_LEN]    : ( buff_pc|(chain_pc[`EXEC_LEN]<<(buff_len*`XLEN)) );
	
	`FFx(buff_para,0)
	if ( ~direct_mode )
	    buff_para <= all_para>>(this_op*`MEMB_PARA);
		
	`FFx(buff_addr,0)
	if ( ~direct_mode )
	    buff_addr <= all_addr>>(this_op*`XLEN);
	else;

    `FFx(buff_wdata,0)
	if ( ~direct_mode )
	    buff_wdata <= all_wdata>>(this_op*`XLEN);
	else;
	
	`FFx(buff_pc,0)
	if ( ~direct_mode )
	    buff_pc <= all_pc>>(this_op*`XLEN);
	else;
	
	wire `N(`MEMB_OFF+1) mem_len =  buff_len + chain_len[`EXEC_LEN];
	
	`FFx(buff_len,0)
	if ( ~direct_mode )
	    buff_len <= mem_len - this_op;
	else;
	
	wire  bus_is_ready = dmem_resp;	
	
	`FFx(req_sent,1'b0)
	if ( direct_reset )
	    req_sent <= 1'b0;
	else if ( ~req_sent )
	    req_sent <= direct_mode ? (|mem_vld) : ((buff_len!=0)|(|mem_vld));
	else if ( bus_is_ready )
	    req_sent <= direct_mode ? 1'b0 : (mem_len>=2);
	else;
	
	assign this_op = req_sent & bus_is_ready;
	
	`COMB 
	if ( ~req_sent )
	    dmem_req = direct_mode ? (|mem_vld) : ((buff_len!=0)|(|mem_vld));
	else if ( bus_is_ready )
	    dmem_req = direct_mode ? 1'b0 : (mem_len>=2);
	else
	    dmem_req = 0;
    
	assign dmem_cmd                 = (req_sent & bus_is_ready) ? all_para[`MEMB_PARA] : all_para[0];
   
	assign dmem_width               = (req_sent & bus_is_ready) ? all_para[`MEMB_PARA+1+:2] : all_para[1+:2];
    
	`COMB begin
	    if ( req_sent & bus_is_ready ) begin
		    dmem_addr[2+:(`XLEN-2)] = all_addr[`XLEN+2+:(`XLEN-2)];
			dmem_addr[1:0]          = (dmem_width==2'b00) ? all_addr[`XLEN+:2] : ( (dmem_width==2'b01) ? {all_addr[`XLEN+1],1'b0} : 2'b00 ); 
		end else begin
		    dmem_addr[2+:(`XLEN-2)] = all_addr[2+:(`XLEN-2)];
			dmem_addr[1:0]          = (dmem_width==2'b00) ? all_addr[0+:2] : ( (dmem_width==2'b01) ? {all_addr[1],1'b0} : 2'b00 ); 		
		end
	end
   
	assign dmem_wdata               = (req_sent & bus_is_ready) ? all_wdata[`IDX(1,`XLEN)] : all_wdata[`IDX(0,`XLEN)];

    reg `N(`MEMB_PARA) req_para;
	`FFx(req_para,0)
	if ( dmem_req )
	    if ( req_sent & bus_is_ready & ~direct_mode & (mem_len>=2) )
		    req_para <= all_para[`IDX(1,`MEMB_PARA)];
		else
		    req_para <= all_para[`IDX(0,`MEMB_PARA)];
	else;

	wire load_vld                   = ~req_para[0];
	
	wire `N(3)  load_para           = req_para[3:1];
	
	wire `N(5)  load_rg             = req_para[8:4];
	
	assign mem_sel                  = (this_op & load_vld) ? load_rg : 5'h0;
	
	`COMB
	if ( load_para[2] )
	    mem_data = load_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	else if ( load_para[1] )
	    mem_data = dmem_rdata;
	else 
	    mem_data = load_para[0] ? { {16{dmem_rdata[15]}}, dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	
    assign mem_release             = this_op;
	
endmodule