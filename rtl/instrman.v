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
module instrman
#(
    parameter START_ADDR = 'h200
)
(
	//system signal    
    input                           clk,
	input                           rst,

    //from top level	
    output                          imem_req,
	output `N(`XLEN)                imem_addr,
	input  `N(`BUS_WID)             imem_rdata,
	input                           imem_resp,
	
	//from sys	
	input                           sysjmp_vld,
	input  `N(`XLEN)                sysjmp_pc,
	
	//from alu	
	input                           alujmp_vld,
	input  `N(`XLEN)                alujmp_pc,
	
	//from instrbits
	input                           buffer_free,	
	
    //to instrbits	
	output                          jump_vld,
	output reg `N(`XLEN)            jump_pc,
	output                          line_vld,
	output `N(`BUS_WID)             line_data

);

    reg            reset_state;
	reg `N(`XLEN)  pc;
		
	`FFx(reset_state,1'b1)
	reset_state <= 1'b0;

    assign jump_vld = reset_state|sysjmp_vld|alujmp_vld;
	
	`COMB begin
    if ( reset_state )
	    jump_pc = START_ADDR;
	else if ( sysjmp_vld )
	    jump_pc = sysjmp_pc;
    else
        jump_pc = alujmp_pc;	
	jump_pc[0] = 1'b0;
	end	
	
	
	wire bus_is_ready = imem_resp;	
	
	reg  req_sent;
	`FFx(req_sent,1'b0)
	if ( ~req_sent|bus_is_ready )
	    req_sent <= (buffer_free|jump_vld);
	else;
	
	assign imem_req = (buffer_free|jump_vld) & ( ~req_sent|bus_is_ready );	
	
	wire `N(`XLEN)  fetch_addr = jump_vld ? jump_pc : pc;

	assign imem_addr = fetch_addr & `PC_ALIGN;	
	
	`FFx(pc,0)
	if ( imem_req )
	    pc <= fetch_addr + 4*`BUS_LEN;
	else if ( jump_vld )
	    pc <= jump_pc;
	else;

	reg line_requested;
	`FFx(line_requested,1'b0)
	if ( imem_req )
	    line_requested <= 1'b1;
	else if ( jump_vld|bus_is_ready )
	    line_requested <= 1'b0;
	else;
	
	assign line_vld = line_requested & bus_is_ready;
	
	assign line_data = imem_rdata;

endmodule
