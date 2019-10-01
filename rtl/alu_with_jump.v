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
    input                                clk,
	input                                rst,

	input                                vld,
    input `N(`XLEN)                      instr,
	input `N(`FETCH_PARA_LEN)            para,
    input `N(`XLEN)                      pc, 
                      
    output `N(`RGBIT)                    rs0_sel,
    output `N(`RGBIT)                    rs1_sel,
    input  `N(`XLEN)                     rs0_word,
    input  `N(`XLEN)                     rs1_word,

                           
    output `N(`RGBIT)                    rd_sel,
    output `N(`XLEN)                     rd_data,

    output                               mem_vld,
    output `N(`MMBUF_PARA_LEN)           mem_para,
    output `N(`XLEN)                     mem_addr,
    output `N(`XLEN)                     mem_wdata,
	output `N(`FETCH_PARA_LEN-`EXEC_PARA_LEN-3) mem_extra_para,
	
	output                               branch_vld,
	output `N(`XLEN)                     branch_pc

);

    `include "include_func.v"

//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------
    wire                      mem, alu;
	wire `N(`RGBIT)           rd,rs1,rs0;
	reg  `N(`XLEN)            operand1;	
	reg  `N(`XLEN)            operand2;
	reg  `N(`XLEN)            rg_data;
	reg  `N(`MMBUF_PARA_LEN)  lsu_para;
	reg  `N(`XLEN)            mem_imm;


//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------

	assign { mem,alu,rd,rs1,rs0 } = para;
	
	assign rs0_sel = rs0;
	
	assign rs1_sel = rs1;
	
	assign rd_sel  = (vld & alu) ? rd : 0;

	always @*
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

	always @*
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
	
	always @*
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

    assign rd_data = rg_data;


    assign mem_vld = vld & mem;
	
	assign mem_extra_para = para>>(4+`EXEC_PARA_LEN);	
	
    `COMB
	if ( |mem_extra_para )
	    lsu_para = { 2'b11, instr[11:7], 1'b0, instr[14:12] };
	else if ( instr[1:0]==2'b11 )
	    if ( instr[6:4]==3'b111 )  //csr
		    lsu_para = { 2'b11, instr[11:7], 1'b0, instr[14:12] };
	    else if ( instr[6:4]==3'b011 ) //mul
		    lsu_para = { 2'b10, instr[11:7], 1'b0, instr[14:12] };
	    else
	        lsu_para = { instr[11:7], instr[5] ,instr[14:12] };
	else case({instr[15:13],instr[1:0]})
        5'b010_00: lsu_para = { {2'b1,instr[4:2]}, 1'b0, 3'b010  };
		5'b110_00: lsu_para = {              5'h0, 1'b1, 3'b010  };
		5'b010_10: lsu_para = {       instr[11:7], 1'b0, 3'b010  };
		5'b110_10: lsu_para = {              5'h0, 1'b1, 3'b010  };
		default  : lsu_para = 0;
		endcase		
    
    assign mem_para =  lsu_para;
	
	`COMB
	if ( instr[1:0]==2'b11 )
	    if ( (instr[6:4]==3'b011)|(instr[6:4]==3'b111) )
		    mem_imm = 0;
		else 
	        mem_imm = instr[5] ?  { {20{instr[31]}},instr[31:25],instr[11:7] } :  { {20{instr[31]}},instr[31:20] };
	else if ( instr[1:0]==2'b00 )
        mem_imm = {instr[5],instr[12:10],instr[6],2'b0};
    else
        mem_imm = instr[15] ? {instr[8:7],instr[12:9],2'b0} : {instr[3:2],instr[12],instr[6:4],2'b0};

	assign mem_addr = rs0_word + mem_imm;	

    assign mem_wdata = ((|mem_extra_para)|((instr[1:0]==2'b11)&(instr[6:4]==3'b111))) ? instr : rs1_word;	

    
    //branch	
	
	wire `N(`FETCH_PARA_LEN-`EXEC_PARA_LEN) point = para>>`EXEC_PARA_LEN;
	
	reg cond_satisfy;
    always @*
    if ( instr[1:0]==2'b11 )
        case(instr[14:12])
        3'b000 : cond_satisfy =    rs0_word==rs1_word;
        3'b001 : cond_satisfy = ~( rs0_word==rs1_word);
        3'b100 : cond_satisfy =    (rs0_word[31]^rs1_word[31]) ? rs0_word[31] : (rs0_word<rs1_word);
        3'b101 : cond_satisfy = ~( (rs0_word[31]^rs1_word[31]) ? rs0_word[31] : (rs0_word<rs1_word) );
        3'b110 : cond_satisfy =    rs0_word<rs1_word;
        3'b111 : cond_satisfy = ~( rs0_word<rs1_word );
        default: cond_satisfy = 1'b0;
        endcase
    else if ( instr[13] )
        cond_satisfy = rs0_word != rs1_word;
    else
        cond_satisfy = rs0_word == rs1_word;    

 
    assign branch_vld = vld & ( point[2]|point[1]|(point[0] & cond_satisfy) );

	wire `N(`XLEN) branch_add0 = point[2] ? rs0_word : pc;
	
	wire `N(`XLEN) branch_add1 =  point[2] ? jalr_offset(instr) : ( point[1] ? jal_offset(instr) : jcond_offset(instr) );
	
	wire `N(`XLEN) branch_add_out = branch_add0 + branch_add1;
   	
    assign branch_pc = branch_add_out;
	
	
endmodule