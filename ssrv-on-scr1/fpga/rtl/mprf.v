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
module mprf(
    input                                clk,
	input                                rst,
   
	input  `N(`EXEC_LEN*`RGBIT)          rd_sel,
	input  `N(`EXEC_LEN*`MMCMB_OFF)      rd_order,
	input  `N(`EXEC_LEN*`JCBUF_OFF)      rd_level,
	input  `N(`EXEC_LEN*`XLEN)           rd_data,

	input                                csr_vld,
	input  `N(`RGBIT)                    csr_rd_sel,
	input  `N(`XLEN)                     csr_data,
	
	input  `N(`MEM_LEN*`RGBIT)           mem_sel,
	input  `N(`MEM_LEN*`XLEN)            mem_data,	
	input  `N(`MEM_OFF)                  mem_release,
	
	input                                clear_pipeline,	
	input                                level_decrease,
	input                                level_clear,	

	input  `N(`EXEC_LEN*`RGBIT)          rs0_sel,
	input  `N(`EXEC_LEN*`RGBIT)          rs1_sel,    	
	output `N(`EXEC_LEN*`XLEN)           rs0_word,
	output `N(`EXEC_LEN*`XLEN)           rs1_word,
	
    input  `N(`RGBIT)                    extra_rs0_sel,
	input  `N(`RGBIT)                    extra_rs1_sel,
	output `N(`XLEN)                     extra_rs0_word,
    output `N(`XLEN)                     extra_rs1_word,

	output `N(`RFBUF_OFF)                rfbuf_alu_num,
	output `N(`RGLEN)                    rfbuf_order_list
);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

    `include "include_func.v"
	
	function `N(1+`XLEN) get_from_array(input `N(`RGBIT)                       target_sel,
	                                    input `N((`RFBUF_LEN+`MEM_LEN)*`RGBIT) array_sel,
	                                    input `N((`RFBUF_LEN+`MEM_LEN)*`XLEN)  array_data);
	    integer         i;
		reg `N(`RGBIT)  sel;
		reg `N(`XLEN)   data;
		reg             get;
		reg `N(`XLEN)   out_word;
	begin
	    get            = 0;
		out_word       = 0;
	    for (i=0;i<(`RFBUF_LEN+`MEM_LEN);i=i+1) begin
		    sel        = array_sel>>(i*`RGBIT);
			data       = array_data>>(i*`XLEN);
			get        = get|(target_sel==sel);
			out_word   = (target_sel==sel) ? data : out_word;
		end
		get            = (target_sel==0) ? 1'b0 : get;
		get_from_array = { get,out_word };
	end
	endfunction
		
	function `N(1+`XLEN) get_from_array_level
	                                   (input `N(`RGBIT)                            target_sel, 
	                                    input `N((`RFBUF_LEN+`MEM_LEN)*`RGBIT)      array_sel,
	                                    input `N((`RFBUF_LEN+`MEM_LEN)*`XLEN)       array_data,
										input `N((`RFBUF_LEN+`MEM_LEN)*`JCBUF_OFF)  array_level);
	    integer            i;
		reg `N(`RGBIT)     sel;
		reg `N(`JCBUF_OFF) level;
		reg `N(`XLEN)      data;
		reg                get;
		reg `N(`XLEN)      out_word;
	begin
	    get                  = 0;
		out_word             = 0;
	    for (i=0;i<(`RFBUF_LEN+`MEM_LEN);i=i+1) begin
		    sel              = array_sel>>(i*`RGBIT);
			level            = array_level>>(i*`JCBUF_OFF);
			data             = array_data>>(i*`XLEN);
			get              = get|((target_sel==sel) & (level==0));
			out_word         = ((target_sel==sel) & (level==0)) ? data : out_word;
		end
		get                  = (target_sel==0) ? 1'b0 : get;
		get_from_array_level = { get,out_word };
	end
	endfunction		
		
    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg `N(`XLEN)                       rbank           [31:0];
	
	wire `N(`EXEC_OFF)                  chain_in_num    `N(`EXEC_LEN+1);		
	wire `N(`EXEC_LEN*`RGBIT)           chain_in_sel    `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`MMCMB_OFF)       chain_in_order  `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`JCBUF_OFF)       chain_in_level  `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)            chain_in_data   `N(`EXEC_LEN+1);	
	wire `N(`RGLEN)                     chain_in_list   `N(`EXEC_LEN+1);
	
    reg  `N(`RFBUF_LEN*`RGBIT)          rfbuf_sel;
	reg  `N(`RFBUF_LEN*`MMCMB_OFF)      rfbuf_order;
	reg  `N(`RFBUF_LEN*`JCBUF_OFF)      rfbuf_level;
	reg  `N(`RFBUF_LEN*`XLEN)           rfbuf_data;	
	reg  `N(`RFBUF_OFF)                 rfbuf_length;
	
	wire `N(`RFINTO_LEN)                chain_away_active `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_OFF)                chain_away_num    `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_LEN*`RGBIT)         chain_away_sel    `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_LEN*`XLEN)          chain_away_data   `N(`RFBUF_LEN+1);	
	
	wire `N(`RFBUF_OFF)                 chain_stay_num    `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`RGBIT)          chain_stay_sel    `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`MMCMB_OFF)      chain_stay_order  `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`JCBUF_OFF)      chain_stay_level  `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`XLEN)           chain_stay_data   `N(`RFBUF_LEN+1);
    wire `N(`RGLEN)                     chain_stay_list   `N(`RFBUF_LEN+1);
	
	reg  `N(`RGLEN)                     zero_order_list;	
	
	wire `N(`RFINTO_LEN*`RGBIT)         away_sel;
	wire `N(`RFINTO_LEN*`XLEN)          away_data;	

    genvar i,j;

    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------	
	

    //---------------------------------------------------------------------------
    //incoming processing
    //---------------------------------------------------------------------------		
    //incoming
	assign                     chain_in_num[0] = 0;
	assign                     chain_in_sel[0] = 0;
	assign                   chain_in_order[0] = 0;
	assign                   chain_in_level[0] = 0;
	assign                    chain_in_data[0] = 0;
	assign                    chain_in_list[0] = 0;
	
	generate
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_incoming	    
		wire `N(`RGBIT)                    sel = rd_sel>>(i*`RGBIT);
		wire `N(`MMCMB_OFF)              order = rd_order>>(i*`MMCMB_OFF);
		wire `N(`JCBUF_OFF)              level = rd_level>>(i*`JCBUF_OFF);
		wire `N(`XLEN)                    data = rd_data>>(i*`XLEN);		
		wire `N(`MMCMB_OFF)           order_up = sub_order(order,mem_release);
		wire `N(`JCBUF_OFF)           level_up = sub_level(level,level_decrease);		
		wire                             clear = ( clear_pipeline & ~( (order_up==0)&(level==0) ) )|( level_clear & (level!=0) );
		
		wire                               vld = (sel!=0);
		wire `N(`EXEC_OFF)               shift = vld ? chain_in_num[i] : `EXEC_LEN;
		assign               chain_in_num[i+1] = chain_in_num[i] + vld;
		assign               chain_in_sel[i+1] = chain_in_sel[i]|( (clear ? 0 : sel)<<(shift*`RGBIT) );
		assign             chain_in_order[i+1] = chain_in_order[i]|( order_up<<(shift*`MMCMB_OFF) );
		assign             chain_in_level[i+1] = chain_in_level[i]|( level_up<<(shift*`JCBUF_OFF) );
		assign              chain_in_data[i+1] = chain_in_data[i]|( data<<(shift*`XLEN) );
		assign              chain_in_list[i+1] = chain_in_list[i]|( (vld & ~clear) <<sel );
	end
	endgenerate	
	
	wire `N(`EXEC_OFF)                  incoming_length = chain_in_num[`EXEC_LEN];		
	wire `N(`EXEC_LEN*`RGBIT)              incoming_sel = chain_in_sel[`EXEC_LEN];
	wire `N(`EXEC_LEN*`MMCMB_OFF)        incoming_order = chain_in_order[`EXEC_LEN];
	wire `N(`EXEC_LEN*`JCBUF_OFF)        incoming_level = chain_in_level[`EXEC_LEN];
	wire `N(`EXEC_LEN*`XLEN)              incoming_data = chain_in_data[`EXEC_LEN];
	wire `N(`RGLEN)                       incoming_list = chain_in_list[`EXEC_LEN];
	
    //---------------------------------------------------------------------------
    //rfbuf processing
    //---------------------------------------------------------------------------	

    //rfbuf
    assign                   chain_away_active[0] = {`RFINTO_LEN{1'b1}};
	assign                      chain_away_num[0] = 0;
	assign                      chain_away_sel[0] = 0;
	assign                     chain_away_data[0] = 0;	
	
	assign                      chain_stay_num[0] = 0;
	assign                      chain_stay_sel[0] = 0;
    assign                    chain_stay_order[0] = 0;
    assign                    chain_stay_level[0] = 0;
    assign                     chain_stay_data[0] = 0;
    assign                     chain_stay_list[0] = 0;
	
    generate 
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_rfbuf	
	    wire `N(`RGBIT)                       sel = rfbuf_sel>>(i*`RGBIT);
		wire `N(`XLEN)                       data = rfbuf_data>>(i*`XLEN);
	    wire `N(`MMCMB_OFF)                 order = rfbuf_order>>(i*`MMCMB_OFF);
	    wire `N(`MMCMB_OFF)              order_up = sub_order(order,mem_release);
		wire `N(`JCBUF_OFF)                 level = rfbuf_level>>(i*`JCBUF_OFF);
		wire `N(`JCBUF_OFF)              level_up = sub_level(level,level_decrease);
		wire                                clear = ( clear_pipeline & ~( (order_up==0)&(level==0) ))|( level_clear & (level!=0) );
	    wire                                  vld = (i<rfbuf_length) & (sel!=0);		
		
        wire                                leave = (order_up==0) & (level==0);		
		wire                                 idle = chain_away_active[i];
		wire                                 away = vld & leave & idle;
		wire `N(`RFINTO_OFF)           away_shift = away ? chain_away_num[i] : `RFINTO_LEN;
		assign             chain_away_active[i+1] = chain_away_active[i]>>away;
		assign                chain_away_num[i+1] = chain_away_num[i] + away;
		assign                chain_away_sel[i+1] = chain_away_sel[i]|(sel<<(away_shift*`RGBIT));
		assign               chain_away_data[i+1] = chain_away_data[i]|(data<<(away_shift*`XLEN));

        wire                                 stay = vld & ~away;
        wire `N(`RFBUF_OFF)            stay_shift = stay ? chain_stay_num[i] : `RFBUF_LEN;
		assign                chain_stay_num[i+1] = chain_stay_num[i] + stay;
		assign                chain_stay_sel[i+1] = chain_stay_sel[i]|( (clear ? 0 : sel)<<(stay_shift*`RGBIT) );
		assign              chain_stay_order[i+1] = chain_stay_order[i]|(order_up<<(stay_shift*`MMCMB_OFF));
		assign              chain_stay_level[i+1] = chain_stay_level[i]|(level_up<<(stay_shift*`JCBUF_OFF));
		assign               chain_stay_data[i+1] = chain_stay_data[i]|(data<<(stay_shift*`XLEN));
        assign               chain_stay_list[i+1] = chain_stay_list[i]|((stay & ~clear)<<sel);	
    end
	endgenerate
	
	`FFx(zero_order_list,0)
	zero_order_list <= chain_stay_list[`RFBUF_LEN]|incoming_list;
	
	assign                       rfbuf_order_list = zero_order_list;
	
	wire `N(`RFBUF_OFF)               stay_length = chain_stay_num[`RFBUF_LEN];
	
	`FFx(rfbuf_length,0)
	rfbuf_length <= stay_length + incoming_length;

    `FFx(rfbuf_sel,0)
	rfbuf_sel <= chain_stay_sel[`RFBUF_LEN]|(incoming_sel<<(stay_length*`RGBIT));
    
	`FFx(rfbuf_order,0)
	rfbuf_order <= chain_stay_order[`RFBUF_LEN]|(incoming_order<<(stay_length*`MMCMB_OFF));
	
	`FFx(rfbuf_level,0)
	rfbuf_level <= chain_stay_level[`RFBUF_LEN]|(incoming_level<<(stay_length*`JCBUF_OFF));
    
	`FFx(rfbuf_data,0)
	rfbuf_data <= chain_stay_data[`RFBUF_LEN]|(incoming_data<<(stay_length*`XLEN));

	
    //---------------------------------------------------------------------------
    //regfile
    //---------------------------------------------------------------------------	

    assign  away_sel = chain_away_sel[`RFBUF_LEN];
    assign away_data = chain_away_data[`RFBUF_LEN];	
	
	wire `N(`MEM_LEN*`RGBIT)   ch_sel;
	wire `N(`MEM_LEN*`XLEN)    ch_data;
	generate
	for (i=0;i<`MEM_LEN;i=i+1) begin:gen_ch_rbank
	    assign             ch_sel[`IDX(i,`RGBIT)] = ( (i==0) & csr_vld ) ? csr_rd_sel : mem_sel[`IDX(i,`RGBIT)];
		assign             ch_data[`IDX(i,`XLEN)] = ( (i==0) & csr_vld ) ? csr_data : mem_data[`IDX(i,`XLEN)];
	end
	endgenerate
	
	generate 
	for (i=0;i<32;i=i+1) begin:gen_rbank
	    `FFx(rbank[i],0) begin:ff_rbank
	        integer n;
		    for (n=0;n<`RFINTO_LEN;n=n+1) begin
		        if ( ( away_sel[`IDX(n,`RGBIT)]!=0 ) & ( away_sel[`IDX(n,`RGBIT)]==i ) ) begin
			        rbank[i] <= away_data[`IDX(n,`XLEN)];
			    end
		    end
		    for (n=0;n<`MEM_LEN;n=n+1) begin
			    if ( ( ch_sel[`IDX(n,`RGBIT)]!=0 ) & ( ch_sel[`IDX(n,`RGBIT)]==i ) ) begin
			        rbank[i] <= ch_data[`IDX(n,`XLEN)];
			    end
		    end		    
		end
	end
	endgenerate

    //---------------------------------------------------------------------------
    //output Rs0 and Rs1
    //---------------------------------------------------------------------------	

	generate
    for(i=0;i<`EXEC_LEN;i=i+1) begin:gen_rs_data
        wire `N(`RGBIT)                  rs0 = rs0_sel>>(i*`RGBIT);
		wire `N(1+`XLEN)            rs0_info = get_from_array(rs0,{mem_sel,rfbuf_sel},{mem_data,rfbuf_data});
		assign       rs0_word[`IDX(i,`XLEN)] = rs0_info[`XLEN] ? rs0_info : ( rbank[rs0] );

        wire `N(`RGBIT)                  rs1 = rs1_sel>>(i*`RGBIT);
		wire `N(1+`XLEN)            rs1_info = get_from_array(rs1,{mem_sel,rfbuf_sel},{mem_data,rfbuf_data});
		assign       rs1_word[`IDX(i,`XLEN)] = rs1_info[`XLEN] ? rs1_info : ( rbank[rs1] );
	end
	endgenerate	
	
	wire `N(1+`XLEN)          extra_rs0_info = get_from_array_level(extra_rs0_sel,{mem_sel,rfbuf_sel},{mem_data,rfbuf_data},rfbuf_level);
	assign                    extra_rs0_word = extra_rs0_info[`XLEN] ? extra_rs0_info : ( rbank[extra_rs0_sel] );
	
	wire `N(1+`XLEN)          extra_rs1_info = get_from_array_level(extra_rs1_sel,{mem_sel,rfbuf_sel},{mem_data,rfbuf_data},rfbuf_level);
	assign                    extra_rs1_word = extra_rs1_info[`XLEN] ? extra_rs1_info : ( rbank[extra_rs1_sel] );	
	
    assign                     rfbuf_alu_num = rfbuf_length;	
	
endmodule
