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
	//system signal
    input                       clk,
    input                       rst,

    //from instrman
    input                       jump_vld,
	input `N(`XLEN)             jump_pc,	
    input                       line_vld,
    input `N(`BUS_WID)          line_data,
    
    //from schedule	
    input `N(`FETCH_OFF)        core_offset,
   
    //to instrman								
    output                      buffer_free,
    
    //to schedule	
    output `N(`FETCH_LEN*`XLEN) fetch_instr,
	output `N(`FETCH_LEN*`XLEN) fetch_pc,
	output `N(`FETCH_LEN)       fetch_vld

);

    reg `N(`BUF_LEN*`BUS_WID)   buffer;
	reg `N(`BUF_OFF)            buff_len;
	reg `N(`XLEN)               buff_pc;
	reg `N(`FETCH_OFF)          last_offset;
	reg `N(`BUS_OFF)            line_offset;

	`FFx(line_offset,0)
	if ( jump_vld )
	    line_offset <= jump_pc[`BUS_OFF:1];
	else if ( line_vld )
	    line_offset <= 0;
	else;
 	
    wire `N(`BUS_WID) line_in = line_vld ? (line_data>>(line_offset*`HLEN)) : 0; 
	
	`FFx(last_offset,0)
	if ( jump_vld )
	    last_offset <= 0;
	else 
	    last_offset <= core_offset;
		
	wire `N(`BUF_OFF) line_shift = buff_len - last_offset;
	
	wire `N(`BUF_LEN*`BUS_WID) all_bits = (buffer>>(last_offset*`HLEN))|(line_in<<(line_shift*`HLEN));
	
	wire `N(`FETCH_LEN*`XLEN) out_bits = all_bits;
	
	`FFx(buffer,0)
	if ( jump_vld )
	    buffer <= 0;
	else
	    buffer <= all_bits;
 
    wire `N(`BUS_OFF+1) line_width = line_vld ? ((2*`BUS_LEN) - line_offset) : 0;
	
	wire `N(`BUF_OFF+1) buf_width = buff_len + line_width - last_offset;
	
	`FFx(buff_len,0)
	if ( jump_vld )
	    buff_len <= 0;
	else
	    buff_len <= buf_width;
		
	`FFx(buff_pc,0)
	if ( jump_vld )
	    buff_pc <= jump_pc;
	else 
	    buff_pc <= fetch_pc;	
	
    wire `N(`XLEN) out_pc = buff_pc + (last_offset<<1);

    assign buffer_free = buf_width <= ((`BUF_LEN-1)*2*`BUS_LEN);

`ifdef RV32C_SUPPORTED
    wire `N(`BUF_OFF+1) start `N(`FETCH_LEN+1);
	assign start[0] = 0;
	generate
	genvar i;
	    for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_fetch
		    assign fetch_instr[`IDX(i,`XLEN)] = out_bits[(start[i]*`HLEN)+:`XLEN];
			
			assign fetch_pc[`IDX(i,`XLEN)] = out_pc + (start[i]<<1);
			
			assign start[i+1] = start[i] + ((fetch_instr[i*`XLEN+:2]==2'b11) ? 2'b10 : 2'b1);
			
			assign fetch_vld[i] = ( start[i+1] <= buf_width );
		end
	endgenerate		
`else	
	generate
	genvar i;
	    for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_fetch
		    assign fetch_instr[`IDX(i,`XLEN)] = out_bits[`IDX(i,`XLEN)];
			
			assign fetch_pc[`IDX(i,`XLEN)] = (i==0) ? out_pc : ( fetch_pc[`IDX(i-1,`XLEN)] + 3'd4 );
			
			assign fetch_vld[i] = ( (2*i) < buf_width );
		end
	endgenerate
`endif	
	
endmodule
