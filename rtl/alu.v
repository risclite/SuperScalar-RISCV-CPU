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
module alu(
    //system signals
    input                                clk,
	input                                rst,

	//from schedule
    input `N(`XLEN)                      instr,
    input `N(`XLEN)                      pc, 
	input                                vld,

	//between mprf                       
    output `N(5)                         rs0_sel,
    output `N(5)                         rs1_sel,
    input  `N(`XLEN)                     rs0_word,
    input  `N(`XLEN)                     rs1_word,

	//to mprf                            
    output     `N(5)                     rg_sel,
    output reg `N(`XLEN)                 rg_data,

	//to membuf                          
    output                               mem_vld,
    output reg `N(`MEMB_PARA)            mem_para,
    output `N(`XLEN)                     mem_addr,
    output `N(`XLEN)                     mem_wdata

);

    //To give some common parameter for one instruction
    function [23:0] rv_para(input vld,input [31:0] i);
    begin
	    if ( ~vld )
		    rv_para = 0;
	    else if ( i[1:0]==2'b11 ) 
            case(i[6:2])
            //                         mul    fencei    fence    sys    csr  jdirct   jcond    mem    alu        rd[4:0]       rs1[4:0]     rs0[4:0]
            5'b01101 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//LUI
            5'b00101 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//AUIPC
            5'b11011 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,         5'h0    };//JAL
            5'b11001 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,     i[19:15]    };//JALR
            5'b11000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b1,  1'b0,  1'b0,          5'h0,     i[24:20],     i[19:15]    };//BRANCH
            5'b00000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,          5'h0,         5'h0,     i[19:15]    };//LOAD
            5'b01000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,          5'h0,     i[24:20],     i[19:15]    };//STORE    
            5'b00100 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,     i[19:15]    };//OP_IMM
            5'b01100 :   rv_para = { i[25],     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],     i[24:20],     i[19:15]    };//OP
            5'b00011 :   rv_para = {  1'b0,    i[12],(~i[12]),  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//MISC_MEM
            5'b11100 :   if (i[14:12]==3'b0)                                                                   
                         rv_para = {  1'b0,     1'b0,    1'b0,  1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//ECALL/EBREAK
                         else                                                                                  
                         rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b1,   1'b0,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,(i[14]?5'h0:i[19:15])};//CSRR
            default  :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
            endcase 
        else
`ifdef RV32C_SUPPORTED
     		case({i[15:13],i[1:0]})                                            
            5'b000_00:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[4:2]},         5'h0,         5'h2    };//C.ADDI4SPN
            5'b010_00:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,         5'h0,{2'b1,i[9:7]}    };//C.LW
            5'b110_00:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,{2'b1,i[4:2]},{2'b1,i[9:7]}    };//C.SW
            5'b000_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,      i[11:7]    };//C.ADDI			
            5'b001_01:   rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h1,         5'h0,         5'h0    };//C.JAL			
            5'b010_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//C.LI			
            5'b011_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,((i[11:7]==5'h2)?5'h2:5'h0)};//C.ADDI16SP/C.LUI
            5'b100_01:   if (i[11:10]!=2'b11)                                       
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[9:7]},         5'h0,{2'b1,i[9:7]}    };//C.SRLI/C.SRAI/C.ANDI
                         else                                                       
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[9:7]},{2'b1,i[4:2]},{2'b1,i[9:7]}    };//C.SUB/C.XOR/C.OR/C.AND
            5'b101_01:   rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//C.J
            5'b110_01,                                                                                                           
            5'b111_01:   rv_para = {                                           1'b0,   1'b1,  1'b0,  1'b0,          5'h0,         5'h0,{2'b1,i[9:7]}    };//C.BEQZ/C.BNEZ
            5'b000_10:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,      i[11:7]    };//C.SLLI
            5'b010_10:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,         5'h0,         5'h2    };//C.LWSP
            5'b100_10:   if ( ~i[12] & (i[6:2]==5'h0) )                          
                         rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,      i[11:7]    };//C.JR
                         else if ( ~i[12] & (i[6:2]!=5'h0)  )                    
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],       i[6:2],         5'h0    };//C.MV
                         else if((i[11:7]==5'h0)&(i[6:2]==5'h0))           
                         rv_para = {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//C.EBREAK
                         else if (i[6:2]==5'h0)                                  
                         rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h1,         5'h0,      i[11:7]    };//C.JALR
                         else                                                    
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],       i[6:2],      i[11:7]    };//C.ADD 
            5'b110_10:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,       i[6:2],         5'h2    };//C.SWSP
            default  :   rv_para = {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
            endcase
`else 
            rv_para =              {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
`endif			
    end
    endfunction  

    wire          instr_is_mem,instr_is_alu;
    wire `N(5)    rd_order,rs1_order,rs0_order;

    assign {instr_is_mem,instr_is_alu,rd_order,rs1_order,rs0_order} = rv_para(vld,instr);

    assign rs0_sel = rs0_order;

    assign rs1_sel = rs1_order;

	wire `N(`XLEN) jm_rs0 = rs0_word;
	
	wire `N(`XLEN) jm_rs1 = rs1_word;
	
	assign rg_sel = rd_order;
	

`ifdef RV32C_SUPPORTED

	reg `N(`XLEN) operand1;
	`COMB
	if ( instr[1:0]==2'b11 )
	    case( instr[6:2] )
		5'b00101,
		5'b11011,
		5'b11001 :  operand1 = pc;
		default  :  operand1 = rs0_word;
		endcase
	else if ( ({instr[15:13],instr[1:0]}==5'b001_01)| ( ({instr[15:13],instr[1:0]}==5'b100_10) & instr[12] & (instr[11:7]!=5'h0) & (instr[6:2]==5'h0) ) )
	    operand1 = pc;
	else
	    operand1 = rs0_word;

	reg `N(`XLEN) operand2;
	`COMB
	if ( instr[1:0]==2'b11 )
	    case( instr[6:2] )
		5'b01101,
        5'b00101 : operand2 =  { instr[31:12],12'b0 };
		5'b11011,
		5'b11001 : operand2 =  4;
		5'b00100 : operand2 =  { {21{instr[31]}},instr[30:20] };
		default  : operand2 = rs1_word;
		endcase
	else case({instr[15:13],instr[1:0]}) 
	    5'b000_00: operand2 = { instr[10:7],instr[12:11],instr[5],instr[6],2'b0 };
		5'b000_01,
		5'b010_01: operand2 = { {27{instr[12]}},instr[6:2] };
		5'b001_01: operand2 = 2;
		5'b011_01: operand2 = (instr[11:7]==5'd2) ?  { {23{instr[12]}},instr[4:3],instr[5],instr[2],instr[6],4'b0 } : { {15{instr[12]}},instr[6:2],12'b0};
		5'b100_01: operand2 = (instr[11:10]!=2'b11) ? { {27{instr[12]}},instr[6:2] } : rs1_word;
        5'b000_10: operand2 = { {27{instr[12]}},instr[6:2] };
        5'b100_10: operand2 = ( instr[12] & (instr[11:7]!=5'h0) & (instr[6:2]==5'h0) ) ? 2 : rs1_word;
        default  : operand2 = rs1_word;
        endcase
		
    wire alu_sub = (instr[1:0]==2'b11) ? ((instr[6:2]==5'b01100)&instr[30]) : ({instr[15:13],instr[1:0]}==5'b100_01);

    wire `N(`XLEN) add_out = alu_sub ? ( operand1 - operand2 ) : ( operand1 + operand2 );
    wire `N(`XLEN) xor_out = operand1 ^ operand2;
    wire `N(`XLEN) or_out  = operand1 | operand2;
    wire `N(`XLEN) and_out = operand1 & operand2;	
   
    wire alu_arith = (instr[1:0]==2'b11) ? instr[30]  : instr[10];
   	wire `N(5)  shift_num = operand2[4:0];
    wire `N(`XLEN) shift_left_out  = rs0_word<<shift_num;
    wire `N(`XLEN) shift_right_out =  {{(`XLEN-1){alu_arith&rs0_word[`XLEN-1]}},rs0_word}>>shift_num;
	
	`COMB
	if ( instr[1:0]==2'b11 )
        if ( (instr[6:2]==5'b00100)|(instr[6:2]==5'b01100) )
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
    else if ( {instr[15:13],instr[1:0]}==5'b100_01 )
        case(instr[11:10])
        2'b00 : rg_data = shift_right_out;
        2'b01 : rg_data = shift_right_out;
        2'b10 : rg_data = and_out;
        2'b11 : case({instr[12],instr[6:5]})
                3'b000 : rg_data = add_out;
                3'b001 : rg_data = xor_out;
                3'b010 : rg_data = or_out;
                3'b011 : rg_data = and_out;
                default: rg_data = add_out;
                endcase
        endcase
    else if ( {instr[15:13],instr[1:0]}==5'b000_10 )
        rg_data = shift_left_out;
    else
        rg_data = add_out;
		
	assign mem_vld = instr_is_mem;

    assign mem_wdata = jm_rs1;	
	
    `COMB
	if ( instr[1:0]==2'b11 )
	    mem_para = {instr[11:7],instr[14:12], instr[5] };
	else case({instr[15:13],instr[1:0]})
        5'b010_00: mem_para = { {2'b1,instr[4:2]}, 3'b010, 1'b0  };
		5'b110_00: mem_para = {              5'h0, 3'b010, 1'b1  };
		5'b010_10: mem_para = {       instr[11:7], 3'b010, 1'b0  };
		5'b110_10: mem_para = {              5'h0, 3'b010, 1'b1  };
		default  : mem_para = 0;
		endcase	
	
	reg `N(`XLEN) mem_imm;
	`COMB
	if ( instr[1:0]==2'b11 )
	    mem_imm = instr[5] ?  { {20{instr[31]}},instr[31:25],instr[11:7] } :  { {20{instr[31]}},instr[31:20] };
	else if ( instr[1:0]==2'b00 )
        mem_imm = {instr[5],instr[12:10],instr[6],2'b0};
    else
        mem_imm = instr[15] ? {instr[8:7],instr[12:9],2'b0} : {instr[3:2],instr[12],instr[6:4],2'b0};

	assign mem_addr = jm_rs0 + mem_imm;

`else	
	
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
    if ( (instr[6:2]==5'b00100)|(instr[6:2]==5'b01100) )
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

    `COMB    
	mem_para = {instr[11:7],instr[14:12], instr[5] };
	
	wire `N(`XLEN)  mem_imm = instr[5] ?  { {20{instr[31]}},instr[31:25],instr[11:7] } :  { {20{instr[31]}},instr[31:20] };

	assign mem_addr = jm_rs0 + mem_imm;
`endif

endmodule