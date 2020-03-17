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
	
	input  `N(`RGBIT)                    mem_sel,
	input  `N(`XLEN)                     mem_data,	

	input                                mem_release,
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

    `include "include_func.v"
	
    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg `N(`XLEN)                       r [31:1];
	
    wire `N(`EXEC_OFF)                  rd_num       `N(`EXEC_LEN+1);
    wire `N(`EXEC_OFF)                  rd_shift     `N(`EXEC_LEN);
	wire `N(`EXEC_LEN*`MMCMB_OFF)       rd_order_up;	
	wire `N(`EXEC_LEN*`JCBUF_OFF)       rd_level_up;
	
	reg  `N(`EXEC_LEN*`RGBIT)           incoming_sel;
	reg  `N(`EXEC_LEN*`MMCMB_OFF)       incoming_order;
	reg  `N(`EXEC_LEN*`JCBUF_OFF)       incoming_level;
	reg  `N(`EXEC_LEN*`XLEN)            incoming_data;
	wire `N(`EXEC_OFF)                  incoming_length;
	
    reg  `N(`RFBUF_LEN*`RGBIT)          rfbuf_sel;
	reg  `N(`RFBUF_LEN*`MMCMB_OFF)      rfbuf_order;
	reg  `N(`RFBUF_LEN*`JCBUF_OFF)      rfbuf_level;
	reg  `N(`RFBUF_LEN*`XLEN)           rfbuf_data;	
	reg  `N(`RFBUF_OFF)                 rfbuf_length;

	wire `N(`RFINTO_OFF)                away_num         `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_LEN)                away_active      `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_LEN*`RGBIT)         chain_away_sel   `N(`RFBUF_LEN+1);
	wire `N(`RFINTO_LEN*`XLEN)          chain_away_data  `N(`RFBUF_LEN+1);	
	
	wire `N(`RFBUF_OFF)                 stay_num         `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`RGBIT)          chain_stay_sel   `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`MMCMB_OFF)      chain_stay_order `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`JCBUF_OFF)      chain_stay_level `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_LEN*`XLEN)           chain_stay_data  `N(`RFBUF_LEN+1);
	
	wire `N(`RFBUF_OFF)                 zero_num         `N(`RFBUF_LEN+1);
	wire `N(`RGLEN)                     chain_order_list `N(`RFBUF_LEN+1);
	
	wire `N(`RFINTO_LEN*`RGBIT)         away_sel;
	wire `N(`RFINTO_LEN*`XLEN)          away_data;	

	reg  `N(`RGLEN)                     tomm_order_list;

    genvar i,j;

    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------	
    //incoming
	assign                           rd_num[0] = 0;
	
	generate
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_rd_shift
	    wire `N(`MMCMB_OFF)              order = rd_order[`IDX(i,`MMCMB_OFF)];
	    wire `N(`MMCMB_OFF)           order_up = sub_order(order,mem_release);
		wire `N(`JCBUF_OFF)              level = rd_level[`IDX(i,`JCBUF_OFF)];
		wire `N(`JCBUF_OFF)           level_up = sub_level(level,level_decrease);
		wire                             clear = ( clear_pipeline & ~( (order_up==0)&(level_up==0) ) )|( level_clear & (level!=0) );
        wire                               vld = (rd_sel[`IDX(i,`RGBIT)]!=0) & ~clear;
		assign                     rd_num[i+1] = rd_num[i] + vld;
		assign                     rd_shift[i] = vld ? rd_num[i] : `EXEC_LEN;
	    assign rd_order_up[`IDX(i,`MMCMB_OFF)] = order_up;
		assign rd_level_up[`IDX(i,`JCBUF_OFF)] = level_up;
	end
	endgenerate

    always @* begin:comb_incoming
	    integer i;
	    incoming_sel   = 0;
		incoming_order = 0;
		incoming_level = 0;
	    incoming_data  = 0;
		for (i=0;i<`EXEC_LEN;i=i+1) begin
		    incoming_sel   = incoming_sel|(rd_sel[`IDX(i,`RGBIT)]<<(rd_shift[i]*`RGBIT));
			incoming_order = incoming_order|(rd_order_up[`IDX(i,`MMCMB_OFF)]<<(rd_shift[i]*`MMCMB_OFF));
			incoming_level = incoming_level|(rd_level_up[`IDX(i,`JCBUF_OFF)]<<(rd_shift[i]*`JCBUF_OFF));
			incoming_data  = incoming_data|(rd_data[`IDX(i,`XLEN)]<<(rd_shift[i]*`XLEN));
		end
	end

    assign                        incoming_length = rd_num[`EXEC_LEN];

    //rfbuf
	assign                            away_num[0] = 0;
	assign                         away_active[0] = {`RFINTO_LEN{1'b1}};
	assign                      chain_away_sel[0] = 0;
	assign                     chain_away_data[0] = 0;
	
	assign                            stay_num[0] = 0;
	assign                      chain_stay_sel[0] = 0;
	assign                    chain_stay_order[0] = 0;
	assign                    chain_stay_level[0] = 0;
	assign                     chain_stay_data[0] = 0;

    assign                            zero_num[0] = 0;
    assign                    chain_order_list[0] = 0;

    generate 
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_rfbuf
	    wire `N(`MMCMB_OFF)                 order = rfbuf_order[`IDX(i,`MMCMB_OFF)];
	    wire `N(`MMCMB_OFF)              order_up = sub_order(order,mem_release);
		wire `N(`JCBUF_OFF)                 level = rfbuf_level[`IDX(i,`JCBUF_OFF)];
		wire `N(`JCBUF_OFF)              level_up = sub_level(level,level_decrease);
		wire                                clear = ( clear_pipeline & ~( (order_up==0)&(level==0) ))|( level_clear & (level!=0) );
		
        wire                                 idle = away_active[i];
		wire                              go_away = (i<rfbuf_length) & ( order_up==0 ) & ( level_up==0 ) & idle;
		wire `N(`RFINTO_OFF)           away_shift = go_away ? away_num[i] : `RFINTO_LEN;
		assign                      away_num[i+1] = away_num[i] + go_away;
		assign                   away_active[i+1] = away_active[i]>>go_away;
		assign                chain_away_sel[i+1] = chain_away_sel[i]|(rfbuf_sel[`IDX(i,`RGBIT)]<<(away_shift*`RGBIT));
		assign               chain_away_data[i+1] = chain_away_data[i]|(rfbuf_data[`IDX(i,`XLEN)]<<(away_shift*`XLEN));
		
		wire                              go_stay = (i<rfbuf_length) & ~clear & ~go_away;
		wire `N(`RFBUF_OFF)            stay_shift = go_stay ? stay_num[i] : `RFBUF_LEN;
		assign                      stay_num[i+1] = stay_num[i] + go_stay;
		assign                chain_stay_sel[i+1] = chain_stay_sel[i]|(rfbuf_sel[`IDX(i,`RGBIT)]<<(stay_shift*`RGBIT));
		assign              chain_stay_order[i+1] = chain_stay_order[i]|(order_up<<(stay_shift*`MMCMB_OFF));
		assign              chain_stay_level[i+1] = chain_stay_level[i]|(level_up<<(stay_shift*`JCBUF_OFF));
		assign               chain_stay_data[i+1] = chain_stay_data[i]|(rfbuf_data[`IDX(i,`XLEN)]<<(stay_shift*`XLEN));
		
		assign                      zero_num[i+1] = zero_num[i] + ( go_stay & (order_up==0) );
		assign              chain_order_list[i+1] = chain_order_list[i]|( (go_stay & (order_up==0) & (zero_num[i]>=`RFINTO_LEN))<<rfbuf_sel[`IDX(i,`RGBIT)] );
    end

	endgenerate
	
	`FFx(tomm_order_list,0)
	tomm_order_list <= chain_order_list[`RFBUF_LEN];
	
	assign                       rfbuf_order_list = tomm_order_list;
	
	
	wire `N(`RFBUF_LEN*`RGBIT)           stay_sel = chain_stay_sel[`RFBUF_LEN];
	wire `N(`RFBUF_LEN*`MMCMB_OFF)     stay_order = chain_stay_order[`RFBUF_LEN];
	wire `N(`RFBUF_LEN*`JCBUF_OFF)     stay_level = chain_stay_level[`RFBUF_LEN];
    wire `N(`RFBUF_LEN*`XLEN)           stay_data = chain_stay_data[`RFBUF_LEN];
    wire `N(`RFBUF_OFF)               stay_length = stay_num[`RFBUF_LEN];

	`FFx(rfbuf_length,0)
	rfbuf_length <= stay_length + incoming_length;

    `FFx(rfbuf_sel,0)
	rfbuf_sel <= stay_sel|(incoming_sel<<(stay_length*`RGBIT));
    
	`FFx(rfbuf_order,0)
	rfbuf_order <= stay_order|(incoming_order<<(stay_length*`MMCMB_OFF));
	
	`FFx(rfbuf_level,0)
	rfbuf_level <= stay_level|(incoming_level<<(stay_length*`JCBUF_OFF));
    
	`FFx(rfbuf_data,0)
	rfbuf_data <= stay_data|(incoming_data<<(stay_length*`XLEN));
	
	//register file
    assign                 away_sel = chain_away_sel[`RFBUF_LEN];
	assign                away_data = chain_away_data[`RFBUF_LEN];

    wire `N(`RGBIT) torg_single_sel = csr_vld ? csr_rd_sel : mem_sel;
    wire `N(`XLEN) torg_single_data = csr_vld ? csr_data : mem_data;

	generate
    for (i=1;i<=31;i=i+1) begin:gen_rf
        `FFx(r[i],0) begin:ff_r
		    integer n;
			for(n=0;n<`RFINTO_LEN;n=n+1) begin
			    if (i==away_sel[`IDX(n,`RGBIT)])
				    r[i] <= away_data[`IDX(n,`XLEN)];
				else;
			end
            if ( i==torg_single_sel )
			    r[i] <= torg_single_data;
            else;				
		end
    end
	endgenerate
	
	//output rs0 and rs1
    wire `N(`EXEC_LEN*`XLEN) rs0_data,rs1_data;	
	
	generate
    for(i=0;i<`EXEC_LEN;i=i+1) begin:gen_rs_data
	    //rs0 
		wire `N(`RGBIT)                   rs0_index = rs0_sel>>(i*`RGBIT);
		
		wire                 chain_rs0_rfbuf_vld `N(`RFBUF_LEN+1);
		wire `N(`RFBUF_OFF)  chain_rs0_rfbuf_num `N(`RFBUF_LEN+1);
		
		assign               chain_rs0_rfbuf_vld[0] = 0;
		assign               chain_rs0_rfbuf_num[0] = `RFBUF_LEN;
		
		for (j=0;j<`RFBUF_LEN;j=j+1) begin:gen_sub_rs0
		    wire `N(`RGBIT)                     sel = rfbuf_sel>>(j*`RGBIT);
			wire                                get = ( rs0_index==sel ) & ( j<rfbuf_length ); 
		    assign         chain_rs0_rfbuf_vld[j+1] = chain_rs0_rfbuf_vld[j]|get;
			assign         chain_rs0_rfbuf_num[j+1] = get ? j : chain_rs0_rfbuf_num[j];
		end
		
		wire                          rs0_rfbuf_vld = chain_rs0_rfbuf_vld[`RFBUF_LEN];
		wire `N(`RFBUF_OFF)           rs0_rfbuf_num = chain_rs0_rfbuf_num[`RFBUF_LEN];
		wire `N(`XLEN)               rs0_rfbuf_data = rfbuf_data>>(rs0_rfbuf_num*`XLEN);
		
		wire `N(`XLEN)              rs0_rgfile_data = (rs0_index==0) ? 0 : r[rs0_index];
		
		wire                            rs0_mem_vld = (mem_sel!=0) & (mem_sel==rs0_index);
		wire `N(`XLEN)                 rs0_mem_data = mem_data;
		
		assign              rs0_data[`IDX(i,`XLEN)] = rs0_mem_vld ? rs0_mem_data : ( rs0_rfbuf_vld ? rs0_rfbuf_data : rs0_rgfile_data );
		
		//rs1
	    wire `N(`RGBIT)                   rs1_index = rs1_sel>>(i*`RGBIT);
		
		wire                 chain_rs1_rfbuf_vld `N(`RFBUF_LEN+1);
		wire `N(`RFBUF_OFF)  chain_rs1_rfbuf_num `N(`RFBUF_LEN+1);
		
		assign               chain_rs1_rfbuf_vld[0] = 0;
		assign               chain_rs1_rfbuf_num[0] = `RFBUF_LEN;
		
		for (j=0;j<`RFBUF_LEN;j=j+1) begin:gen_sub_rs1
		    wire `N(`RGBIT)                     sel = rfbuf_sel>>(j*`RGBIT);
			wire                                get = ( rs1_index==sel ) & ( j<rfbuf_length ); 
		    assign         chain_rs1_rfbuf_vld[j+1] = chain_rs1_rfbuf_vld[j]|get;
			assign         chain_rs1_rfbuf_num[j+1] = get ? j : chain_rs1_rfbuf_num[j];
		end
		
		wire                          rs1_rfbuf_vld = chain_rs1_rfbuf_vld[`RFBUF_LEN];
		wire `N(`RFBUF_OFF)           rs1_rfbuf_num = chain_rs1_rfbuf_num[`RFBUF_LEN];
		wire `N(`XLEN)               rs1_rfbuf_data = rfbuf_data>>(rs1_rfbuf_num*`XLEN);
		
		wire `N(`XLEN)              rs1_rgfile_data = (rs1_index==0) ? 0 : r[rs1_index];
		
		wire                            rs1_mem_vld = (mem_sel!=0) & (mem_sel==rs1_index);
		wire `N(`XLEN)                 rs1_mem_data = mem_data;
		
		assign              rs1_data[`IDX(i,`XLEN)] = rs1_mem_vld ? rs1_mem_data : ( rs1_rfbuf_vld ? rs1_rfbuf_data : rs1_rgfile_data );
		
	end
	endgenerate	
	
	assign rs0_word = rs0_data;
	assign rs1_word = rs1_data;
	
	wire `N(`XLEN) extra_rs0_data,extra_rs1_data;
	
	//extra_rs0
    wire `N(`RGBIT)                       es0_index = extra_rs0_sel;
		
	wire                 chain_es0_rfbuf_vld `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_OFF)  chain_es0_rfbuf_num `N(`RFBUF_LEN+1);
		
	assign                   chain_es0_rfbuf_vld[0] = 0;
	assign                   chain_es0_rfbuf_num[0] = `RFBUF_LEN;
	
    generate	
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_sub_es0
	    wire `N(`RGBIT)                         sel = rfbuf_sel>>(i*`RGBIT);
		wire `N(`JCBUF_OFF)                   level = rfbuf_level>>(i*`JCBUF_OFF);
		wire                                    get = ( es0_index==sel ) & ( level==0 ) & ( i<rfbuf_length ); 
		assign             chain_es0_rfbuf_vld[i+1] = chain_es0_rfbuf_vld[i]|get;
		assign             chain_es0_rfbuf_num[i+1] = get ? i : chain_es0_rfbuf_num[i];
	end
	endgenerate
		
	wire                              es0_rfbuf_vld = chain_es0_rfbuf_vld[`RFBUF_LEN];
	wire `N(`RFBUF_OFF)               es0_rfbuf_num = chain_es0_rfbuf_num[`RFBUF_LEN];
	wire `N(`XLEN)                   es0_rfbuf_data = rfbuf_data>>(es0_rfbuf_num*`XLEN);
		
	wire `N(`XLEN)                  es0_rgfile_data = (es0_index==0) ? 0 : r[es0_index];
		
	wire                                es0_mem_vld = ( mem_sel!=0) & (mem_sel==es0_index);
	wire `N(`XLEN)                     es0_mem_data = mem_data;
		
	assign                           extra_rs0_data = es0_mem_vld ? es0_mem_data : ( es0_rfbuf_vld ? es0_rfbuf_data : es0_rgfile_data );
	
	//extra_rs1
    wire `N(`RGBIT)                       es1_index = extra_rs1_sel;
		
	wire                 chain_es1_rfbuf_vld `N(`RFBUF_LEN+1);
	wire `N(`RFBUF_OFF)  chain_es1_rfbuf_num `N(`RFBUF_LEN+1);
		
	assign                   chain_es1_rfbuf_vld[0] = 0;
	assign                   chain_es1_rfbuf_num[0] = `RFBUF_LEN;
	
    generate	
	for (i=0;i<`RFBUF_LEN;i=i+1) begin:gen_sub_es1
	    wire `N(`RGBIT)                         sel = rfbuf_sel>>(i*`RGBIT);
		wire `N(`JCBUF_OFF)                   level = rfbuf_level>>(i*`JCBUF_OFF);
		wire                                    get = ( es1_index==sel ) & ( level==0 ) & ( i<rfbuf_length ); 
		assign             chain_es1_rfbuf_vld[i+1] = chain_es1_rfbuf_vld[i]|get;
		assign             chain_es1_rfbuf_num[i+1] = get ? i : chain_es1_rfbuf_num[i];
	end
	endgenerate
		
	wire                              es1_rfbuf_vld = chain_es1_rfbuf_vld[`RFBUF_LEN];
	wire `N(`RFBUF_OFF)               es1_rfbuf_num = chain_es1_rfbuf_num[`RFBUF_LEN];
	wire `N(`XLEN)                   es1_rfbuf_data = rfbuf_data>>(es1_rfbuf_num*`XLEN);
		
	wire `N(`XLEN)                  es1_rgfile_data = (es1_index==0) ? 0 : r[es1_index];
		
	wire                                es1_mem_vld = ( mem_sel!=0) & (mem_sel==es1_index);
	wire `N(`XLEN)                     es1_mem_data = mem_data;
		
	assign                           extra_rs1_data = es1_mem_vld ? es1_mem_data : ( es1_rfbuf_vld ? es1_rfbuf_data : es1_rgfile_data );
	
	assign                           extra_rs0_word = extra_rs0_data;
	assign                           extra_rs1_word = extra_rs1_data;
	
    assign                            rfbuf_alu_num = rfbuf_length;
	
endmodule
