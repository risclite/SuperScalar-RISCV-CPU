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
module instrbits
(
    input                              clk,
    input                              rst,

    input                              jump_vld,
	input `N(`XLEN)                    jump_pc,	
    input                              line_vld,
    input `N(`BUS_WID)                 line_data,
	input                              line_err,	
    output                             buffer_free,

	output `N(`FETCH_LEN)              fetch_vld,
    output `N(`FETCH_LEN*`XLEN)        fetch_instr,
	output `N(`FETCH_LEN*`XLEN)        fetch_pc,
	output `N(`FETCH_LEN)              fetch_err,
    input  `N(`FETCH_OFF)              fetch_offset

);

//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------

	reg  `N(`BUS_OFF)                        line_offset;
    reg  `N(`INBUF_LEN*`BUS_WID)             buff_data;
	reg  `N(`INBUF_LEN*`BUS_LEN*2)           buff_err;
	reg  `N(`INBUF_HLEN_OFF)                 buff_len;
	reg  `N(`XLEN)                           buff_pc;

    wire `N(`FETCH_HLEN_OFF)                 fetch_hlen_offset;
    wire `N(`FETCH_HLEN_OFF)                 start             `N(`FETCH_LEN+1);	
	wire `N((`FETCH_LEN+1)*`FETCH_HLEN_OFF)  fetch_addup_array `N(`FETCH_LEN+1);

//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------
	
    //to remove redundant part of line_data;
	`FFx(line_offset,0)
	if ( jump_vld )
	    line_offset <= jump_pc[`BUS_OFF:1];
	else if ( line_vld )
	    line_offset <= 0;
	else;
 	
    wire `N(`BUS_WID)   imem_data   = line_vld ? (line_data>>(line_offset*`HLEN)) : 0; 
	
	wire `N(`BUS_LEN*2) imem_err    = line_vld ? ( { (`BUS_LEN*2){line_err} }>>line_offset ) : 0;

    wire `N(`BUS_OFF+1) imem_length = line_vld ? ((2*`BUS_LEN) - line_offset) : 0;
	
	//accept line_data into buff 
	wire `N(`INBUF_HLEN_OFF)    inbits_length = buff_len + imem_length;
	
	wire `N(`INBUF_LEN*`BUS_WID)  inbits_data = buff_data|(imem_data<<(buff_len*`HLEN));
	
	wire `N(`INBUF_LEN*`BUS_LEN*2) inbits_err = buff_err|(imem_err<<buff_len);
	
	assign fetch_hlen_offset = ( fetch_addup_array[`FETCH_LEN]<<`FETCH_HLEN_OFF )>>(fetch_offset*`FETCH_HLEN_OFF);
	
	`FFx(buff_data,0)
	if ( jump_vld )
	    buff_data <= 0;
	else
	    buff_data <= inbits_data>>(fetch_hlen_offset*`HLEN);
		
	`FFx(buff_err,0)
	if ( jump_vld )
	    buff_err <= 0;
    else
        buff_err <= inbits_err>>fetch_hlen_offset; 	
	
	`FFx(buff_len,0)
	if ( jump_vld )
	    buff_len <= 0;
	else
	    buff_len <= inbits_length - fetch_hlen_offset;
		
	`FFx(buff_pc,0)
	if ( jump_vld )
	    buff_pc <= jump_pc;
	else
	    buff_pc <= buff_pc + (fetch_hlen_offset<<1);
		
	assign buffer_free = inbits_length <= ((`INBUF_LEN-1)*2*`BUS_LEN);

    //prepare fetch data
	
    assign start[0]             = 0;
	assign fetch_addup_array[0] = 0;
	
	generate
	genvar i;
	    for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_fetch
		    wire `N(`XLEN) instr = inbits_data>>(start[i]*`HLEN);
			
			wire `N(2)     err   = inbits_err[start[i]+:2];
			
			wire `N(`XLEN) pc    = buff_pc + (start[i]<<1);
			
		    assign fetch_instr[`IDX(i,`XLEN)] = instr;
			
			assign fetch_err[i] = (instr[1:0]==2'b11) ? ( |err ) : err[0];
			
			assign fetch_pc[`IDX(i,`XLEN)] = pc;
			
			assign start[i+1] = start[i] + ((instr[1:0]==2'b11) ? 2'b10 : 2'b1);
			
			assign fetch_vld[i] = ( start[i+1] <= inbits_length );
			
			assign fetch_addup_array[i+1] = fetch_addup_array[i]|( start[i+1]<<(i*`FETCH_HLEN_OFF) );
		end
	endgenerate		
	
	
endmodule
