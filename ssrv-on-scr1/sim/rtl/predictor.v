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


module predictor(
    input                       clk,
	input                       rst,
	
	input                       imem_req,
	input  `N(`XLEN)            imem_addr,	
    output `N(2*`BUS_LEN)       imem_predict,
	
	input                       jcond_vld,
	input  `N(`XLEN)            jcond_pc,
	input                       jcond_hit,
	input                       jcond_satisfied

);


    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

    function predict_bit( input `N(`PDT_BLEN) bits );
	begin
	    case(bits)
		5'b00000 : predict_bit = 0;
		5'b00001 : predict_bit = 0;
		5'b00010 : predict_bit = 0;
		5'b00011 : predict_bit = 1;
        5'b00100 : predict_bit = 0;
		5'b00101 : predict_bit = 0;
		5'b00110 : predict_bit = 0;
		5'b00111 : predict_bit = 1;
		5'b01000 : predict_bit = 0;
		5'b01001 : predict_bit = 0;
		5'b01010 : predict_bit = 1;
		5'b01011 : predict_bit = 0;
		5'b01100 : predict_bit = 1;
		5'b01101 : predict_bit = 1;
		5'b01110 : predict_bit = 1;
		5'b01111 : predict_bit = 1;
		5'b10000 : predict_bit = 0;
		5'b10001 : predict_bit = 0;
		5'b10010 : predict_bit = 0;
		5'b10011 : predict_bit = 0;
        5'b10100 : predict_bit = 1;
		5'b10101 : predict_bit = 0;
		5'b10110 : predict_bit = 1;
		5'b10111 : predict_bit = 1;
		5'b11000 : predict_bit = 0;
		5'b11001 : predict_bit = 1;
		5'b11010 : predict_bit = 1;
		5'b11011 : predict_bit = 1;
		5'b11100 : predict_bit = 0;
		5'b11101 : predict_bit = 1;
		5'b11110 : predict_bit = 1;
		5'b11111 : predict_bit = 1;		
        endcase
    end
    endfunction	


    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg  `N(`PDT_LEN)                 pdt_vld;
	reg  `N(`PDT_ADDR*`PDT_LEN)       pdt_address;
	reg  `N(`PDT_BLEN*`PDT_LEN)       pdt_bits;

    wire `N(2*`BUS_LEN)               chain_predict      `N(`PDT_LEN+1);

    reg  `N(2*`BUS_LEN)               get_predict;

    genvar i;
    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------
	
    //---------------------------------------------------------------------------
	//output predict bit
	//---------------------------------------------------------------------------	
	
	assign                              chain_predict[0] = 0;

	wire `N(`PDT_ADDR-`BUS_OFF)           target_address = imem_addr>>(1+`BUS_OFF);

    generate
	for (i=0;i<`PDT_LEN;i=i+1) begin:gen_imem_predict
		wire `N(`BUS_OFF)                     this_shift = pdt_address[`IDX(i,`PDT_ADDR)];
		wire `N(`PDT_ADDR-`BUS_OFF)         this_address = pdt_address[`IDX(i,`PDT_ADDR)]>>`BUS_OFF;
		wire                                    this_bit = pdt_vld[i] & (target_address==this_address) & predict_bit(pdt_bits[`IDX(i,`PDT_BLEN)]);
	    assign                        chain_predict[i+1] = chain_predict[i]|(this_bit<<this_shift);
	end
	endgenerate

	`FFx(get_predict,0)
	if ( imem_req )
	    get_predict <= chain_predict[`PDT_LEN];
	else;
	
	assign imem_predict = get_predict;

    //---------------------------------------------------------------------------
	//update predict items
	//---------------------------------------------------------------------------	

    wire `N(`PDT_LEN+1)  chain_find_vld;
	wire `N(`PDT_OFF)    chain_find_index `N(`PDT_LEN+1);
	
	assign                          chain_find_vld[0] = 0;
	assign                        chain_find_index[0] = 0;
	
	wire `N(`PDT_ADDR)                       find_aim = jcond_pc>>1;
	
	generate
	for (i=0;i<`PDT_LEN;i=i+1) begin:gen_find_index
	    assign                    chain_find_vld[i+1] = chain_find_vld[i]|(pdt_vld[i] & (pdt_address[`IDX(i,`PDT_ADDR)]==find_aim));
		assign                  chain_find_index[i+1] = (pdt_vld[i] & (pdt_address[`IDX(i,`PDT_ADDR)]==find_aim)) ? i : chain_find_index[i];
	end
	endgenerate
    
    wire                                     find_vld = chain_find_vld[`PDT_LEN];
	wire  `N(`PDT_OFF)                     find_index = chain_find_index[`PDT_LEN];
	
    wire  `N(`PDT_OFF)                     high_shift = find_index + find_vld;
    wire  `N(`PDT_LEN)                       high_vld = pdt_vld & ( ~((1'b1<<high_shift)-1'b1) );
    wire  `N(`PDT_ADDR*`PDT_LEN)         high_address = pdt_address & ( ~((1'b1<<(high_shift*`PDT_ADDR))-1'b1) );
	wire  `N(`PDT_BLEN*`PDT_LEN)            high_bits = pdt_bits & ( ~((1'b1<<(high_shift*`PDT_BLEN))-1'b1) );
	
	wire  `N(`PDT_OFF)                      low_shift = find_index;
	wire  `N(`PDT_LEN)                        low_vld = pdt_vld & ( (1'b1<<low_shift)-1'b1 );
    wire  `N(`PDT_ADDR*`PDT_LEN)          low_address = pdt_address & ( (1'b1<<(low_shift*`PDT_ADDR))-1'b1 );
	wire  `N(`PDT_BLEN*`PDT_LEN)             low_bits = pdt_bits & ( (1'b1<<(low_shift*`PDT_BLEN))-1'b1 );    

    wire                                      new_vld = jcond_vld & ( find_vld|(~jcond_hit) );
	wire `N(`PDT_ADDR)                    new_address = find_aim;
	wire `N(`PDT_BLEN)                       old_bits = find_vld ? ( pdt_bits>>(find_index*`PDT_BLEN) ) : 5'b11111;
	wire `N(`PDT_BLEN)                       new_bits = { old_bits,jcond_satisfied };

    wire `N(`PDT_LEN)                          go_vld = ( high_vld<<(find_vld ? 1'b0 : 1'b1) )|( low_vld<<1 )|new_vld;
	wire `N(`PDT_ADDR*`PDT_LEN)            go_address = ( high_address<<(find_vld ? 0 : `PDT_ADDR) )|( low_address<<`PDT_ADDR )|new_address;
    wire `N(`PDT_BLEN*`PDT_LEN)               go_bits = ( high_bits<<(find_vld ? 0 : `PDT_BLEN) )|( low_bits<<`PDT_BLEN )|new_bits;
	
	`FFx(pdt_vld,0)
	if ( new_vld )
	    pdt_vld <= go_vld;
	else;
	
	`FFx(pdt_address,0)
	if ( new_vld )
	    pdt_address <= go_address;
	else;
	
	`FFx(pdt_bits,0)
	if ( new_vld )
	    pdt_bits <= go_bits;
	else;

endmodule
