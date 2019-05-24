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
module alu_with_jump(
    //system signals
    input                                clk,
	input                                rst,

	//from schedule
    input `N(`XLEN)                      instr,
    input `N(`XLEN)                      pc, 

	//between mprf                       
    output `N(5)                         rs0_sel,
    output `N(5)                         rs1_sel,
    input  `N(`XLEN)                     rs0_word,
    input  `N(`XLEN)                     rs1_word,

	//to instrman                        
    output                               jump_vld,
    output `N(`XLEN)                     jump_pc,

	//to mprf                            
    output     `N(5)                     rg_sel,
    output reg `N(`XLEN)                 rg_data,

	//to membuf                          
    output                               mem_vld,
    output `N(`MEMB_PARA)                mem_para,
    output `N(`XLEN)                     mem_addr,
    output `N(`XLEN)                     mem_wdata,
	
	//from csr 
    input  `N(`XLEN)                     csr_data

);

    //To give some common parameter for one instruction
    function [22:0] rv_para(input [31:0] i);
    begin
	    if ( i[1:0]==2'b11 )
            case(i[6:2])
            //                       SYS(fencei/fence/others)    csr  jdirct   jcond    mem    alu     rd[4:0]       rs1[4:0]     rs0[4:0]
            5'b01101 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,         5'h0    };//LUI
            5'b00101 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,         5'h0    };//AUIPC
            5'b11011 :   rv_para = {                     3'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,         5'h0    };//JAL
            5'b11001 :   rv_para = {                     3'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,     i[19:15]    };//JALR
            5'b11000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b1,  1'b0,  1'b0,       5'h0,     i[24:20],     i[19:15]    };//BRANCH
            5'b00000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,       5'h0,         5'h0,     i[19:15]    };//LOAD
            5'b01000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,       5'h0,     i[24:20],     i[19:15]    };//STORE    
            5'b00100 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,     i[19:15]    };//OP_IMM
            5'b01100 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],     i[24:20],     i[19:15]    };//OP
            5'b00011 :   rv_para = {(i[12] ? 3'b100 : 3'b010),  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };//MISC_MEM
            5'b11100 :   if (i[14:12]==3'b0)                                              
                         rv_para = {                     3'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };//ECALL/EBREAK
                         else                                                          
                         rv_para = {                     3'b0,  1'b1,   1'b0,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,(i[14]?5'h0:i[19:15])};//CSRR
            default  :   rv_para = {                     3'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };
            endcase 
        else
            rv_para = 0;		
    end
    endfunction

    wire          instr_is_csr,instr_is_jdirct,instr_is_jcond,instr_is_mem,instr_is_alu;
    wire `N(5)    rd_order,rs1_order,rs0_order;

    assign {instr_is_csr,instr_is_jdirct,instr_is_jcond,instr_is_mem,instr_is_alu,rd_order,rs1_order,rs0_order} = rv_para(instr);

    assign rs0_sel = rs0_order;

    assign rs1_sel = rs1_order;

	reg           cond_permit;

	wire `N(`XLEN) jm_rs0 = rs0_word;
	
	wire `N(`XLEN) jm_rs1 = rs1_word;
	
    `COMB
    case(instr[14:12])
    3'b000 : cond_permit =    jm_rs0==jm_rs1;
    3'b001 : cond_permit = ~( jm_rs0==jm_rs1);
    3'b100 : cond_permit =    (jm_rs0[31]^jm_rs1[31]) ? jm_rs0[31] : (jm_rs0<jm_rs1);
    3'b101 : cond_permit = ~( (jm_rs0[31]^jm_rs1[31]) ? jm_rs0[31] : (jm_rs0<jm_rs1) );
    3'b110 : cond_permit =    jm_rs0<jm_rs1;
    3'b111 : cond_permit = ~( jm_rs0<jm_rs1 );
    default: cond_permit = 1'b0;
    endcase

    assign jump_vld = instr_is_jdirct|(instr_is_jcond & cond_permit);

    wire `N(`XLEN) jump_add_rg = ( instr[6:2]==5'b11001 ) ? jm_rs0 : pc; 

    reg `N(`XLEN) jump_add_imm;
	`COMB 
	case( instr[6:2] )
	5'b11011 : jump_add_imm = { {12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0 };
	5'b11001 : jump_add_imm = { {21{instr[31]}},instr[30:20] };
	5'b11000 : jump_add_imm = { {20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0 };
	default  : jump_add_imm = 0;
	endcase
	
    assign jump_pc = jump_add_rg + jump_add_imm;


	
	assign rg_sel = rd_order;
	
	reg `N(`XLEN) operand1;
	`COMB
	case( instr[6:2] )
	5'b00101,
	5'b11011,
	5'b11001 :  operand1 = pc;
	default  :  operand1 = rs0_word;
	endcase
		
	reg `N(`XLEN) operand2;
	`COMB
	case( instr[6:2] )
	5'b01101,
    5'b00101 : operand2 =  { instr[31:12],12'b0 };
	5'b11011,
	5'b11001 : operand2 =  4;
	5'b00100 : operand2 =  { {21{instr[31]}},instr[30:20] };
	default  : operand2 = rs1_word;
	endcase
		
    wire alu_sub = (instr[6:2]==5'b01100) & instr[30];

    wire `N(`XLEN) add_out = alu_sub ? ( operand1 - operand2 ) : ( operand1 + operand2 );
    wire `N(`XLEN) xor_out = operand1 ^ operand2;
    wire `N(`XLEN) or_out  = operand1 | operand2;
    wire `N(`XLEN) and_out = operand1 & operand2;	
   
    wire alu_arith =  instr[30];
   	wire `N(5)  shift_num = operand2[4:0];
    wire `N(`XLEN) shift_left_out  = rs0_word<<shift_num;
    wire `N(`XLEN) shift_right_out =  {{(`XLEN-1){alu_arith&rs0_word[`XLEN-1]}},rs0_word}>>shift_num;
   
   `COMB
    if ( instr_is_csr )
	    rg_data = csr_data;
	else if ( (instr[6:2]==5'b00100)|(instr[6:2]==5'b01100) )
        case( instr[14:12] )
	    3'b000  : rg_data = add_out;
	    3'b010  : rg_data = (operand1[31]^operand2[31]) ? operand1[31] : (operand1<operand2);
	    3'b011  : rg_data = (operand1<operand2);
	    3'b100  : rg_data = xor_out;
	    3'b110  : rg_data = or_out;
	    3'b111  : rg_data = and_out;
	    3'b001  : rg_data = shift_left_out;
	    3'b101  : rg_data = shift_right_out;
	    default : rg_data = add_out;
	    endcase
    else 
        rg_data = add_out;
		
		
	assign mem_vld = instr_is_mem;

    assign mem_wdata = jm_rs1;	
   
    assign mem_para = {instr[11:7],instr[14:12], instr[5] };
	
	wire `N(`XLEN)  mem_imm = instr[5] ?  { {20{instr[31]}},instr[31:25],instr[11:7] } :  { {20{instr[31]}},instr[31:20] };

	assign mem_addr = jm_rs0 + mem_imm;

endmodule