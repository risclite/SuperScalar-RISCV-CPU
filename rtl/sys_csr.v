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
module sys_csr(
    //system signals
    input                                clk,
	input                                rst,

	//from schedule
	input `N(`XLEN)                      instr,	
	input `N(`XLEN)                      pc,
	input                                vld,
	
	//from mprf
	input `N(`XLEN)                      rs0_word,
	input `N(`XLEN)                      rs1_word,
	
	output                               jump_vld,
	output reg `N(`XLEN)                 jump_pc,
	
	output                               direct_mode,
	output                               direct_reset,
	
	output `N(`XLEN)                     csr_data
	

);

	//csr function
	
	wire instr_is_csr = vld & (instr[1:0]==2'b11) & (instr[6:2]==5'b11100) & (instr[14:12]!=3'b0);
	
	wire `N(12) csr_addr = instr[31:20];
	
	localparam ADDR_MHARTID = 12'hf14,
	           ADDR_MTVEC   = 12'h305,
			   ADDR_MEPC    = 12'h341,
			   ADDR_MCAUSE  = 12'h342,
			   ADDR_MCYCLE  = 12'hc00,
			   ADDR_MTIME   = 12'hc01,
			   ADDR_MCYCLEH = 12'hc80
			   ;
	
	localparam DATA_MHARTID = 32'h0,
	           DATA_MCAUSE  = 11
			   ;

    reg `N(`XLEN) csr_out;	
	reg `N(`XLEN) csr_in;
	
	wire `N(3)  csr_func = instr[14:12];
	
	`COMB
	case(csr_func)
	3'b001 : csr_in = rs0_word;
	3'b010 : csr_in = rs0_word|csr_out;
	3'b011 : csr_in = (~rs0_word)&csr_out;
	3'b101 : csr_in = instr[19:15];
	3'b110 : csr_in = instr[19:15]|csr_out;
	3'b111 : csr_in = (~instr[19:15])&csr_out;
	default : csr_in = csr_out;
	endcase
	
	reg `N(`XLEN) data_mtvec;
	`FFx(data_mtvec,0)
	if ( instr_is_csr & (csr_addr==ADDR_MTVEC) )
	    data_mtvec <= csr_in;
	else;
	
	reg `N(`XLEN) data_mepc;
	`FFx(data_mepc,0)
	if ( instr_is_csr & (csr_addr==ADDR_MEPC) )
	    data_mepc <= csr_in;
	else;

    reg `N(64) mcycle;
    `FFx(mcycle,0)
    mcycle <= mcycle + 1'b1;	

	reg `N(7) mtime_cnt;
	`FFx(mtime_cnt,0)
	if ( mtime_cnt==99 )
	    mtime_cnt <= 0;
	else 
	    mtime_cnt <= mtime_cnt + 1'b1;
	
	reg `N(64) mtime;
	`FFx(mtime,0)
	if ( mtime_cnt==99 )
	    mtime <= mtime + 1;
	else;
	
	`COMB
	if ( csr_addr==ADDR_MHARTID )
	    csr_out = DATA_MHARTID;
	else if ( csr_addr==ADDR_MTVEC )
	    csr_out = data_mtvec;
	else if ( csr_addr==ADDR_MEPC )
	    csr_out = data_mepc;
	else if ( csr_addr==ADDR_MCAUSE )
	    csr_out = DATA_MCAUSE;
	else if ( csr_addr==ADDR_MCYCLE)
	    csr_out = mcycle[31:0];
	else if ( csr_addr==ADDR_MTIME )
	    csr_out = mtime[31:0];
	else if ( csr_addr==ADDR_MCYCLEH )
	    csr_out = mcycle[63:32];
	else
	    csr_out = 0;
	
	
	assign csr_data = csr_out;

	wire instr_is_ret    = vld & (instr==32'b0000000_00010_00000_000_00000_1110011)|(instr==32'b0001000_00010_00000_000_00000_1110011)|(instr==32'b0011000_00010_00000_000_00000_1110011);
	wire instr_is_ecall  = vld & (instr==32'b0000000_00000_00000_000_00000_1110011);
	wire instr_is_fencei = vld & (instr==32'b0000000_00000_00000_001_00000_0001111);
	
	assign jump_vld = (instr_is_ret|instr_is_ecall|instr_is_fencei);
	
`ifdef DIRECT_MODE	
	assign direct_mode = 1'b1;
`else
    assign direct_mode = 1'b0;
`endif
	
	assign direct_reset = 1'b0;

    `COMB
	if ( instr_is_ret )
	    jump_pc = data_mepc;
	else if ( instr_is_ecall )
	    jump_pc = data_mtvec;
	else if ( instr_is_fencei )
	    jump_pc = pc + 4;
	else
	    jump_pc = 0;
	
endmodule