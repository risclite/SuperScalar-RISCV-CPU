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
module sys_csr
#(
    parameter START_ADDR = 'h200
)
(
    input                                          clk,
	input                                          rst,
  
	input                                          alujmp_vld,
	input  `N(`XLEN)                               alujmp_pc,	
 
    input                                          sys_vld,
    input  `N(`XLEN)                               sys_instr,
	input  `N(`XLEN)                               sys_pc,
    input  `N(`FETCH_PARA_LEN-`EXEC_PARA_LEN-3)    sys_extra_para, //3 : err, illegal, sys
    input  `N(`XLEN)                               csr_rs,
	output `N(`XLEN)                               csr_data,
	
	input  `N(2)                                   dmem_exception,
	input  `N(`XLEN)                               int_pc,
	input                                          mem_busy,
	
	output                                         clear_pipeline,
    output                                         sys_resp,
	output                                         jump_vld,
	output `N(`XLEN)                               jump_pc,
	
	//interface between SCR1
	output                                         exu2csr_r_req,
	output `N(12)                                  exu2csr_rw_addr,
	input  `N(`XLEN)                               csr2exu_r_data,
	output                                         exu2csr_w_req,
	output `N(2)                                   exu2csr_w_cmd,
	output `N(`XLEN)                               exu2csr_w_data,
	input                                          csr2exu_rw_exc,
	
	input                                          csr2exu_irq,
	output                                         exu2csr_take_irq,
	
	output                                         exu2csr_mret_instr,
	output                                         exu2csr_mret_update,
	
	output                                         exu2csr_take_exc,
	output `N(4)                                   exu2csr_exc_code,
	output `N(`XLEN)                               exu2csr_trap_val,
	
	input  `N(`XLEN)                               csr2exu_new_pc,
	output `N(`XLEN)                               curr_pc, //exc PC
	output `N(`XLEN)                               next_pc  //IRQ PC
	
);

	//csr function	
	wire instr_csr  = sys_vld & ( sys_extra_para==0 );
	
	wire `N(12) csr_addr = sys_instr[31:20];
	
	wire `N(3)  csr_func = sys_instr[14:12];
	
	assign exu2csr_r_req = instr_csr & ( sys_instr[11:7]!=5'b0 );
	
	assign exu2csr_rw_addr = csr_addr;
	
	assign csr_data = csr2exu_r_data;
	
	assign exu2csr_w_req = instr_csr & ~( csr_func[1] & ( sys_instr[19:15]==5'b0 ) );
	
	assign exu2csr_w_cmd = csr_func;
	
	assign exu2csr_w_data = csr_func[2] ? sys_instr[19:15] : csr_rs;
	
	//mret
	wire instr_fencei = sys_vld & sys_extra_para[0] & ( sys_instr[6:2]==5'b00011 );
 
    wire instr_sys = sys_vld & sys_extra_para[0] & ~( sys_instr[6:2]==5'b00011 );   
	
	wire instr_mret = instr_sys & ( sys_instr[31:20]==12'h302 );
	
	assign exu2csr_mret_instr = instr_mret;
	
	assign exu2csr_mret_update = exu2csr_mret_instr;
	
	//exception	
	wire instr_err = sys_vld & sys_extra_para[2];
	
	wire instr_illegal = sys_vld & sys_extra_para[1]; 
	
	assign exu2csr_take_exc = dmem_exception[1]|instr_err|instr_illegal|(instr_sys & ~instr_mret)|(instr_csr & csr2exu_rw_exc);
	
	reg `N(4) exec_code;
	always @* begin
	    exec_code = 4'd11; //ecall_m
	    case(1'b1)
		dmem_exception[1] : exec_code = dmem_exception[0] ? 4'd7 : 4'd5; //st_access_fault:ld_access_fault
		instr_err         : exec_code = 4'd1; //instr_access_fault
		instr_illegal     : exec_code = 4'd2; //illegal_instr
		instr_csr         : exec_code = 4'd2; //illegal_instr
		endcase
	end
	
	assign exu2csr_exc_code = exec_code;
	
	assign exu2csr_trap_val = sys_pc;
	
	assign curr_pc = sys_pc;
	
	//IRQ
	assign exu2csr_take_irq = csr2exu_irq & ~mem_busy & ~exu2csr_take_exc & ~exu2csr_mret_instr & ~instr_fencei;
	
	assign next_pc = int_pc;	
	
	//jump
    reg   reset_state;	
	`FFx(reset_state,1'b1)
	reset_state <= 1'b0;

    assign jump_vld = reset_state|alujmp_vld|instr_fencei|exu2csr_take_exc|exu2csr_mret_instr|exu2csr_take_irq;
	
	assign jump_pc = ( exu2csr_take_exc|exu2csr_mret_instr|exu2csr_take_irq ) ? csr2exu_new_pc : ( instr_fencei ? ( sys_pc + 3'd4 ) : ( reset_state ? START_ADDR : alujmp_pc ) );
	
	assign clear_pipeline = exu2csr_take_exc|exu2csr_mret_instr|exu2csr_take_irq|instr_fencei;
	
	assign sys_resp = sys_vld & ~exu2csr_take_exc & ~exu2csr_mret_instr & ~instr_fencei;
	
endmodule