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
module mul(
	//system signals
    input                                clk,
    input                                rst,
	
	//from schedule
	input `N(`XLEN)                      instr,	
	input `N(`XLEN)                      pc,
	input                                vld,
	input `N(`MEMB_OFF)                  cnt,
	
	//from mprf
	input `N(`XLEN)                      rs0_word,
	input `N(`XLEN)                      rs1_word,

	//from membuf
	input                                mem_release,
    input `N(5)                          mem_sel,
    input `N(`XLEN)                      mem_data,	
	
	//to schedule
	output                               mul_is_busy,
	
	//to mprf
	output `N(5)                         m2_sel,
	output `N(`XLEN)                     m2_data
	
);

    function `N($clog2(`XLEN+1)) highest_pos(input `N(`XLEN) d);
	integer i;
	begin
	    highest_pos = 0;
	    for (i=0;i<`XLEN;i=i+1)
		    if ( d[i] )
	            highest_pos = i;
	end
	endfunction

	function `N($clog2(`XLEN+1)) sumbits(input `N(`XLEN) d);
	integer i;
	begin
	    sumbits = 0;
		for (i=0;i<`XLEN;i=i+1)
		    sumbits = sumbits + d[i];
	end
	endfunction

	reg                           calc_flag;
	reg  `N(3)                    calc_para;
	reg  `N(5)                    calc_rd;
	reg                           calc_sign_xor,calc_sign_rs0;
	reg  `N(`XLEN)                calc_a,calc_b,calc_x,calc_y;
	reg  `N($clog2(`XLEN+1))      calc_a_pos,calc_b_pos;
	wire                          calc_over;
	wire `N(`XLEN)                calc_a_in,calc_b_in,calc_x_in,calc_y_in;	
	
	reg                           write_flag;
	reg  `N(`XLEN)                write_data;
	
	wire `N(`XLEN)                rs0_data,rs1_data;
	reg `N(`MEMB_OFF)             mul_cnt;	
	
	wire  instr_is_mul = vld & (instr[1:0]==2'b11) & (instr[6:2]==5'b01100) & instr[25];

`ifdef REGISTER_EXEC	
	assign mul_is_busy = instr_is_mul|calc_flag|(write_flag & ~((mul_cnt==0) & (mem_sel==5'h0)));
`else
    assign mul_is_busy = calc_flag|write_flag;
`endif

    wire    mul_direct = instr[14] ? ((rs1_word==0)|(rs0_data<rs1_data)) : ((rs0_word==0)|(rs1_word==0));	
	
	`FFx(mul_cnt,0)
	if ( instr_is_mul )
`ifdef REGISTER_EXEC
	    mul_cnt <= mem_release ? ( (cnt==0) ? 0 : ( cnt - 1'b1 ) ) : cnt;
`else
        mul_cnt <= cnt;
`endif
	else
	    mul_cnt <= mem_release ? ( (mul_cnt==0) ? 0 : ( mul_cnt - 1'b1 ) ) : mul_cnt; 
	
	//to calcuate MUL/DIV function
	
	wire calc_start = instr_is_mul & ~mul_direct;	
	
	`FFx(calc_flag,0)
	if ( calc_start )
	    calc_flag <= 1'b1;
	else if ( calc_over )
	    calc_flag <= 1'b0;
	else;
	
	`FFx(calc_para,0)
	if ( instr_is_mul )
	    calc_para <= instr[14:12];
	else;
	
	`FFx(calc_rd,0)
	if ( instr_is_mul )
	    calc_rd <= instr[11:7];
	else;
	
	wire rs0_sign = instr[14] ? (~instr[12] & rs0_word[31]) : ( (instr[13:12]!=2'b11) & rs0_word[31] );

	wire rs1_sign = instr[14] ? (~instr[12] & rs1_word[31]) : ( ~instr[13] & rs1_word[31] );
	
	`FFx(calc_sign_xor,0)
	if ( instr_is_mul )
	    calc_sign_xor <= (instr[14]&(rs1_word==0)) ? 0 : (rs0_sign^rs1_sign);
	else;
	
	`FFx(calc_sign_rs0,0)
	if ( instr_is_mul )
	    calc_sign_rs0 <= rs0_sign;
    else;

	assign rs0_data = rs0_sign ? ( ~rs0_word + 1'b1 ) : rs0_word;

	assign rs1_data = rs1_sign ? ( ~rs1_word + 1'b1 ) : rs1_word;

	wire num_less_compare = sumbits(rs0_data)<sumbits(rs1_data);

	`FFx(calc_a,0)
	if ( instr_is_mul )
	    if ( instr[14] )
		    calc_a <= rs0_data;
		else
		    calc_a <= num_less_compare ? rs1_data : rs0_data;
	else if ( calc_flag )
	    calc_a <= calc_a_in;
	else;
	
	`FFx(calc_b,0)
	if ( instr_is_mul )
	    if ( instr[14] )
		    calc_b <= rs1_data;
		else
		    calc_b <= num_less_compare ? rs0_data : rs1_data;
	else if ( calc_flag )
	    calc_b <= calc_b_in;
	else;
	
	`FFx(calc_x,0)
	if ( instr_is_mul )
	    if ( instr[14] )
		    calc_x <= ( rs1_word==0 ) ? 32'hffffffff : 0;
		else
		    calc_x <= 0;
	else if ( calc_flag )
	    calc_x <= calc_x_in;
	else;
	
	`FFx(calc_y,0)
	if ( instr_is_mul )
	    calc_y <= 0;
	else if ( calc_flag )
	    calc_y <= calc_y_in;
	else;
	
    wire `N(`XLEN) pos_a_in = calc_flag ? calc_a_in : rs0_data;

    wire `N(5) pos_a_out = highest_pos(pos_a_in);

    wire `N(`XLEN) pos_b_in = calc_flag ? calc_b_in : rs1_data;

    wire `N(5) pos_b_out = highest_pos(pos_b_in);

    `FFx(calc_a_pos,0)
	if ( instr_is_mul )
        if ( instr[14] )
            calc_a_pos <= pos_a_out;
        else 
            calc_a_pos <= num_less_compare ? pos_b_out : pos_a_out;
	else if ( calc_flag )
	    calc_a_pos <= pos_a_out;
    else;

    `FFx(calc_b_pos,0)
	if ( instr_is_mul )
        if ( instr[14] )
            calc_b_pos <= pos_b_out;
        else 
            calc_b_pos <= num_less_compare ? pos_a_out : pos_b_out;
	else if ( calc_flag )
	    calc_b_pos <= pos_b_out;
    else;
	
	wire `N($clog2(`XLEN+1))  calc_ab_gap  = calc_a_pos - calc_b_pos;
	
	wire `N($clog2(`XLEN))    calc_ab_diff = calc_ab_gap;

	wire `N(2*`XLEN) mul_shift    = calc_a<<calc_b_pos;

	wire `N(`XLEN)   low_add_in0  = calc_para[2] ? calc_a : calc_x;
	
	wire `N(`XLEN)   low_add_in1  = calc_para[2] ? ( calc_b<<calc_ab_diff ) : mul_shift;
	
	wire             sub_sign     = calc_para[2] ? 1'b1 : calc_sign_xor;

    wire `N(`XLEN+1) low_add_out  = sub_sign ? (low_add_in0 - low_add_in1) : (low_add_in0 + low_add_in1);
	
	wire             carry_bit    = low_add_out[`XLEN];

    wire `N(`XLEN)   high_add_in0 = calc_para[2] ? calc_a : calc_y;

    wire `N(`XLEN)   high_add_in1 = calc_para[2] ? ( ( calc_b<<calc_ab_diff )>>1 ) : (mul_shift>>`XLEN);
	
	wire             high_add_bit = calc_para[2] ? 1'b0 : carry_bit;

    wire `N(`XLEN)   high_add_out = sub_sign ? (high_add_in0 - high_add_in1 - high_add_bit) : (high_add_in0 + high_add_in1 + high_add_bit);

	assign           calc_a_in    = calc_para[2] ?  ( carry_bit ? high_add_out : low_add_out ) : calc_a;

	assign           calc_b_in    = calc_para[2] ? calc_b : ( calc_b ^ (1'b1<<calc_b_pos) );

	assign           calc_x_in    = calc_para[2] ? ( calc_x|( (1'b1<<calc_ab_diff)>>carry_bit ) ) : low_add_out;
	
	assign           calc_y_in    = calc_para[2] ? calc_y : high_add_out;
	
	assign           calc_over    = calc_flag & ( calc_para[2] ? ( calc_a_in<calc_b ) : (calc_b_in==0) );
	
	//write from mem channel
	
	`FFx(write_flag,0)
	if( (instr_is_mul & mul_direct)|calc_over )
	    write_flag <= 1'b1;
	else if ( write_flag & (mem_sel==0) & (mul_cnt==0) )
	    write_flag <= 1'b0;
	else;
	
	`COMB
	case(calc_para)
	3'h0          :  write_data = calc_x;
	3'h1,3'h2,3'h3:  write_data = calc_y;
    3'h4,3'h5     :  write_data = calc_sign_xor ? (~calc_x+1'b1) : calc_x;
    3'h6,3'h7     :  write_data = calc_sign_rs0 ? (~calc_a+1'b1) : calc_a;
    endcase

    assign m2_sel  = (write_flag & (mem_sel==0) & (mul_cnt==0) ) ? calc_rd : mem_sel;	
	
	assign m2_data = (write_flag & (mem_sel==0) & (mul_cnt==0) ) ? write_data : mem_data;	

endmodule

