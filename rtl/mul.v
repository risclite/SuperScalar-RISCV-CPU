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
    input                                    clk,
    input                                    rst,
	
	input                                    mul_initial,
	input  `N(3)                             mul_para,
	input  `N(`XLEN)                         mul_rs0,
	input  `N(`XLEN)                         mul_rs1,
	output                                   mul_ready,
	
	input                                    clear_pipeline,

	output                                   mul_finished,
	output `N(`XLEN)                         mul_data,	
	input                                    mul_ack
	
);


    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

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

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------

	reg                           calc_flag;
	reg  `N(3)                    calc_para;
	reg                           calc_sign_xor,calc_sign_rs0;
	reg  `N(`XLEN)                calc_a,calc_b,calc_x,calc_y;
	reg  `N($clog2(`XLEN+1))      calc_a_pos,calc_b_pos;
	wire                          calc_over;
	wire `N(`XLEN)                calc_a_in,calc_b_in,calc_x_in,calc_y_in;	
	
	reg                           write_flag;
	reg  `N(`XLEN)                write_data;
    wire                          write_over;
	
    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------	

	wire `N(`XLEN)              rs0_word = mul_rs0;
	wire `N(`XLEN)              rs1_word = mul_rs1;
	wire                        rs0_sign = mul_para[2] ? (~mul_para[0] & rs0_word[31]) : ( (mul_para[1:0]!=2'b11) & rs0_word[31] );
	wire                        rs1_sign = mul_para[2] ? (~mul_para[0] & rs1_word[31]) : ( ~mul_para[1] & rs1_word[31] );	
	wire `N(`XLEN)              rs0_data = rs0_sign ? ( ~rs0_word + 1'b1 ) : rs0_word;
	wire `N(`XLEN)              rs1_data = rs1_sign ? ( ~rs1_word + 1'b1 ) : rs1_word;	

    wire                      mul_direct = mul_para[2] ? ((rs1_word==0)|(rs0_data<rs1_data)) : ((rs0_word==0)|(rs1_word==0));	
    wire                     mul_is_busy = calc_flag|(write_flag & ~write_over);
	assign                     mul_ready = ~mul_is_busy;
	
	//to calcuate MUL/DIV function
	wire                      calc_start = mul_initial & ~mul_direct & ~mul_is_busy & ~clear_pipeline;	
	wire                     write_start = mul_initial &  mul_direct & ~mul_is_busy & ~clear_pipeline;
	
	`FFx(calc_flag,0)
	if ( calc_start )
	    calc_flag <= 1'b1;
	else if ( calc_over|clear_pipeline )
	    calc_flag <= 1'b0;
	else;
	
	`FFx(calc_para,0)
	if ( calc_start|write_start )
	    calc_para <= mul_para[2:0];
	else;
	
	`FFx(calc_sign_xor,0)
	if ( calc_start|write_start )
	    calc_sign_xor <= (mul_para[2]&(rs1_word==0)) ? 0 : (rs0_sign^rs1_sign);
	else;
	
	`FFx(calc_sign_rs0,0)
	if ( calc_start|write_start )
	    calc_sign_rs0 <= rs0_sign;
    else;

	wire                num_less_compare = sumbits(rs0_data)<sumbits(rs1_data);

	`FFx(calc_a,0)
	if ( calc_start|write_start )
	    if ( mul_para[2] )
		    calc_a <= rs0_data;
		else
		    calc_a <= num_less_compare ? rs1_data : rs0_data;
	else if ( calc_flag )
	    calc_a <= calc_a_in;
	else;
	
	`FFx(calc_b,0)
	if ( calc_start|write_start )
	    if ( mul_para[2] )
		    calc_b <= rs1_data;
		else
		    calc_b <= num_less_compare ? rs0_data : rs1_data;
	else if ( calc_flag )
	    calc_b <= calc_b_in;
	else;
	
	`FFx(calc_x,0)
	if ( calc_start|write_start )
	    if ( mul_para[2] )
		    calc_x <= ( rs1_word==0 ) ? 32'hffffffff : 0;
		else
		    calc_x <= 0;
	else if ( calc_flag )
	    calc_x <= calc_x_in;
	else;
	
	`FFx(calc_y,0)
	if ( calc_start|write_start )
	    calc_y <= 0;
	else if ( calc_flag )
	    calc_y <= calc_y_in;
	else;
	
    wire `N(`XLEN)              pos_a_in = calc_flag ? calc_a_in : rs0_data;
    wire `N(5)                 pos_a_out = highest_pos(pos_a_in);
    wire `N(`XLEN)              pos_b_in = calc_flag ? calc_b_in : rs1_data;
    wire `N(5)                 pos_b_out = highest_pos(pos_b_in);

    `FFx(calc_a_pos,0)
	if ( calc_start|write_start )
        if ( mul_para[2] )
            calc_a_pos <= pos_a_out;
        else 
            calc_a_pos <= num_less_compare ? pos_b_out : pos_a_out;
	else if ( calc_flag )
	    calc_a_pos <= pos_a_out;
    else;

    `FFx(calc_b_pos,0)
	if ( calc_start|write_start )
        if ( mul_para[2] )
            calc_b_pos <= pos_b_out;
        else 
            calc_b_pos <= num_less_compare ? pos_a_out : pos_b_out;
	else if ( calc_flag )
	    calc_b_pos <= pos_b_out;
    else;
	
	wire `N($clog2(`XLEN+1)) calc_ab_gap = calc_a_pos - calc_b_pos;
	wire `N($clog2(`XLEN))  calc_ab_diff = calc_ab_gap;

	wire `N(2*`XLEN)           mul_shift = calc_a<<calc_b_pos;
	wire                        sub_sign = calc_para[2] ? 1'b1 : calc_sign_xor;

	wire `N(`XLEN)           low_add_in0 = calc_para[2] ? calc_a : calc_x;
	wire `N(`XLEN)           low_add_in1 = calc_para[2] ? ( calc_b<<calc_ab_diff ) : mul_shift;
    wire `N(`XLEN+1)         low_add_out = sub_sign ? (low_add_in0 - low_add_in1) : (low_add_in0 + low_add_in1);
	
	wire                       carry_bit = low_add_out[`XLEN];
	wire                    high_add_bit = calc_para[2] ? 1'b0 : carry_bit;

    wire `N(`XLEN)          high_add_in0 = calc_para[2] ? calc_a : calc_y;
    wire `N(`XLEN)          high_add_in1 = calc_para[2] ? ( ( calc_b<<calc_ab_diff )>>1 ) : (mul_shift>>`XLEN);
    wire `N(`XLEN)          high_add_out = sub_sign ? (high_add_in0 - high_add_in1 - high_add_bit) : (high_add_in0 + high_add_in1 + high_add_bit);

	assign                     calc_a_in = calc_para[2] ?  ( carry_bit ? high_add_out : low_add_out ) : calc_a;
	assign                     calc_b_in = calc_para[2] ? calc_b : ( calc_b ^ (1'b1<<calc_b_pos) );
	assign                     calc_x_in = calc_para[2] ? ( calc_x|( (1'b1<<calc_ab_diff)>>carry_bit ) ) : low_add_out;
	assign                     calc_y_in = calc_para[2] ? calc_y : high_add_out;
	
	assign                     calc_over = calc_flag & ( calc_para[2] ? ( calc_a_in<calc_b ) : (calc_b_in==0) );
	
	//write from mem channel
	
	`FFx(write_flag,0)
	if( write_start|calc_over )
	    write_flag <= 1'b1;
	else if ( write_over|clear_pipeline )
	    write_flag <= 1'b0;
	else;
	
	always @*
	if ( write_flag )
	    case(calc_para)
	    3'h0          :  write_data = calc_x;
	    3'h1,3'h2,3'h3:  write_data = calc_y;
        3'h4,3'h5     :  write_data = calc_sign_xor ? (~calc_x+1'b1) : calc_x;
        3'h6,3'h7     :  write_data = calc_sign_rs0 ? (~calc_a+1'b1) : calc_a;
        endcase
	else
	    write_data = 0;

    //mul buffer
	reg  `N(`MULBUF_LEN*`XLEN) mulbuf_data;
	reg  `N(`MULBUF_OFF)       mulbuf_length;
	
	wire `N(`MULBUF_LEN*`XLEN) primary_data   = mulbuf_data|(write_data<<(mulbuf_length*`XLEN));
	wire `N(`MULBUF_OFF)       primary_length = (mulbuf_length==`MULBUF_LEN) ? `MULBUF_LEN : (mulbuf_length + write_flag);

    assign write_over = write_flag & (mulbuf_length<`MULBUF_LEN);

    assign mul_finished   = primary_length!=0;
    assign mul_data       = primary_data;
	
    `FFx(mulbuf_data,0)
    if ( clear_pipeline )	
	    mulbuf_data <= 0;
	else
	    mulbuf_data <= primary_data>>(mul_ack*`XLEN);
		
	`FFx(mulbuf_length,0)
	if ( clear_pipeline )
	    mulbuf_length <= 0;
	else
	    mulbuf_length <= primary_length - mul_ack;
endmodule

