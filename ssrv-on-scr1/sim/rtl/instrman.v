/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2020  Li Xinbing
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

//THis module manages instruction memory request. There are 3 methods to change PC.
//1--- jump_vld/jump_pc: System jump to PC
//2--- branch_vld/branch_pc: branch to PC
//3--- buffer_free: Keep fetching instructions

`include "define.v"
module instrman
(   
    input                           clk,
	input                           rst,

    output                          imem_req,
	output `N(`XLEN)                imem_addr,
	input                           imem_resp,
	input  `N(`BUS_WID)             imem_rdata,
	input                           imem_err,

	input                           jump_vld,
	input  `N(`XLEN)                jump_pc,
	input                           branch_vld,
	input  `N(`XLEN)                branch_pc,
	input                           buffer_free,
	
	output                          imem_vld,
	output `N(`BUS_WID)             imem_instr,
	output                          imem_status

);

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	reg `N(`XLEN)   pc;	
	reg             req_sent;
	reg             instr_verified;
	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    wire             reload_vld = jump_vld|branch_vld;
	wire `N(`XLEN)    reload_pc = ( jump_vld ? jump_pc : branch_pc ) & ( {`XLEN{1'b1}}<<1 );
	wire `N(`XLEN)   fetch_addr = reload_vld ? reload_pc : pc;
	assign            imem_addr = fetch_addr & `PC_ALIGN;		
	
	//imem_addr
	`FFx(pc,0)
	if ( imem_req )
	    pc <= fetch_addr + 4*`BUS_LEN;
	else if ( reload_vld )
	    pc <= reload_pc;
	else;	
	
	//imem_req
	wire             request_go = buffer_free|reload_vld;
	
	//if req_sent is 0, request_go can be asserted any time, if it is 1, only when imem_resp is OK.
	`FFx(req_sent,1'b0)
	if ( ~req_sent|imem_resp )
	    req_sent <= request_go;
	else;
	
	assign             imem_req = request_go & ( ~req_sent|imem_resp );	
	
	//rdata could be cancelled by "reload_vld"
	`FFx(instr_verified,1'b0)
	if ( imem_req )
	    instr_verified <= 1'b1;
	else if ( reload_vld|imem_resp )
	    instr_verified <= 1'b0;
	else;
	
	assign             imem_vld = instr_verified & imem_resp;
	assign           imem_instr = imem_rdata;
	assign          imem_status = imem_err;
	

endmodule
