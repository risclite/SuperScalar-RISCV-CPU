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
module membuf(
    input                                    clk,
	input                                    rst,

    //interface with mul
    output `N(`MUL_LEN)                      mul_initial,
	output `N(`MUL_LEN*3)                    mul_para,
	output `N(`MUL_LEN*`XLEN)                mul_rs0,
	output `N(`MUL_LEN*`XLEN)                mul_rs1,
	input  `N(`MUL_LEN)                      mul_ready,
	input  `N(`MUL_LEN)                      mul_finished,
	input  `N(`MUL_LEN*`XLEN)                mul_data,
	output `N(`MUL_LEN)                      mul_ack,
	
	//interface with lsu
    output                                   lsu_initial,
	output `N(`MMBUF_PARA_LEN)               lsu_para,
	output `N(`XLEN)                         lsu_addr,
	output `N(`XLEN)                         lsu_wdata,
	input                                    lsu_ready,
	input                                    lsu_finished,
	input                                    lsu_status,
	input  `N(`XLEN)                         lsu_rdata,
    output                                   lsu_ack,	

    //interface with mprf
	input  `N(`EXEC_LEN)                     mem_vld,
	input  `N(`EXEC_LEN*`MMBUF_PARA_LEN)     mem_para,
	input  `N(`EXEC_LEN*`XLEN)               mem_addr,
	input  `N(`EXEC_LEN*`XLEN)               mem_wdata,
	input  `N(`EXEC_LEN*`XLEN)               mem_pc,
	input  `N(`EXEC_LEN*`JCBUF_OFF)          mem_level,
    output `N(`MEM_LEN*`RGBIT)               mem_sel,
    output `N(`MEM_LEN*`XLEN)                mem_data,	
    output `N(`MEM_OFF)                      mem_release,
	
	//misc signals
	input                                    clear_pipeline,
	input                                    level_decrease,
	input                                    level_clear,
	input  `N(`RGLEN)                        rfbuf_order_list,
	output `N(`RGBIT)                        mmbuf_check_rdnum,
    output `N(`RGLEN)                        mmbuf_check_rdlist,	
	output `N(`RGLEN)                        mmbuf_instr_rdlist,
	output `N(`MMBUF_OFF)                    mmbuf_mem_num,	    
	output                                   mmbuf_intflag,
    output `N(`XLEN)                         mmbuf_intpc,
    output `N(2)                             dmem_exception,
	output                                   mem_busy


);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------
	
	function `N(`MUL_OFF) lowest_mul( input `N(`MUL_LEN) d );
	    integer i;
	begin
	    lowest_mul = 0;
	    for (i=0;i<`MUL_LEN;i=i+1) 
		    if ( d[`MUL_LEN-1-i] )
			    lowest_mul = `MUL_LEN-1-i;
	end
	endfunction

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	wire `N(`EXEC_OFF)                       chain_in_num            `N(`EXEC_LEN+1);
	wire `N(`EXEC_OFF)                       array_in_shift          `N(`EXEC_LEN);

	reg  `N(`EXEC_LEN*`MMBUF_PARA_LEN)       in_para;
	reg  `N(`EXEC_LEN*`XLEN)                 in_addr;
	reg  `N(`EXEC_LEN*`XLEN)                 in_wdata;
	reg  `N(`EXEC_LEN*`XLEN)                 in_pc;
	reg  `N(`EXEC_LEN*`JCBUF_OFF)            in_level;
    wire `N(`EXEC_OFF)                       in_length;	
	
	wire `N(`MMBUF_LEN*`MMBUF_PARA_LEN)      comb_para;
	wire `N(`MMBUF_LEN*`XLEN)                comb_addr;
	wire `N(`MMBUF_LEN*`XLEN)                comb_wdata;
	wire `N(`MMBUF_LEN*`XLEN)                comb_pc;	
	wire `N(`MMBUF_LEN*`JCBUF_OFF)           comb_level;	
	wire `N(`MMBUF_OFF)                      comb_length;	
	
	wire `N(`MMBUF_LEN*`MMBUF_PARA_LEN)      out_para;
	wire `N(`MMBUF_LEN*`XLEN)                out_addr;
	wire `N(`MMBUF_LEN*`XLEN)                out_wdata;
	wire `N(`MMBUF_LEN*`XLEN)                out_pc;	
	wire `N(`MMBUF_LEN*`JCBUF_OFF)           out_level;
	wire `N(`MMBUF_OFF)                      out_length;
	
	wire `N(`MMBUF_OFF)                      chain_ot_length         `N(`MMBUF_LEN+1);
	wire `N(`MMBUF_OFF)                      chain_mul_next          `N(`MMBUF_LEN+1);	
	wire `N(`MMBUF_LEN)                      array_lsu_start;
	wire `N(`MMBUF_LEN)                      array_mul_flag;
	wire `N(`MMBUF_LEN*`RGBIT)               array_mem_check;
	
    reg  `N(`MMBUF_OFF)                      mmbuf_length;
	reg  `N(`MMBUF_LEN*`MMBUF_PARA_LEN)      mmbuf_para;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_addr;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_wdata;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_pc;
	reg  `N(`MMBUF_LEN*`JCBUF_OFF)           mmbuf_level;

	reg  `N(`MMBUF_OFF)                      mul_bottom;
    reg  `N(`MMBUF_OFF)                      mul_order;

    reg  `N(`MMBUF_OFF)                      lsu_order;


    genvar i;
	
	`include "include_func.v"
    //---------------------------------------------------------------------------
    //Statement area
    //---------------------------------------------------------------------------



    //---------------------------------------------------------------------------
    //remove redundant instructions 
    //---------------------------------------------------------------------------

	assign       chain_in_num[0] = 0;
	
	generate
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_in_num
		assign array_in_shift[i] = mem_vld[i] ? chain_in_num[i] : `EXEC_LEN;
		assign chain_in_num[i+1] = chain_in_num[i] + mem_vld[i];
	end
	endgenerate
	
    always @* begin:comb_in_series
	    integer i;
		in_para  = 0;
		in_addr  = 0;
		in_wdata = 0;
		in_pc    = 0;
		in_level = 0;
	    for (i=0;i<`EXEC_LEN;i=i+1) begin
		    in_para  = in_para|( mem_para[`IDX(i,`MMBUF_PARA_LEN)]<<(array_in_shift[i]*`MMBUF_PARA_LEN) );
			in_addr  = in_addr|( mem_addr[`IDX(i,`XLEN)]<<(array_in_shift[i]*`XLEN) );
			in_wdata = in_wdata|( mem_wdata[`IDX(i,`XLEN)]<<(array_in_shift[i]*`XLEN) );
			in_pc    = in_pc|( mem_pc[`IDX(i,`XLEN)]<<(array_in_shift[i]*`XLEN) );
			in_level = in_level|( mem_level[`IDX(i,`JCBUF_OFF)]<<(array_in_shift[i]*`JCBUF_OFF) );
		end
	end

    assign in_length = chain_in_num[`EXEC_LEN];
	
	
    //---------------------------------------------------------------------------
    //main generate statement
    //---------------------------------------------------------------------------	
	
	//processing	
	assign                                    comb_para = mmbuf_para|( in_para<<(mmbuf_length*`MMBUF_PARA_LEN) );
	assign                                    comb_addr = mmbuf_addr|( in_addr<<(mmbuf_length*`XLEN) );
	assign                                   comb_wdata = mmbuf_wdata|( in_wdata<<(mmbuf_length*`XLEN) );
	assign                                      comb_pc = mmbuf_pc|( in_pc<<(mmbuf_length*`XLEN) );
	assign                                   comb_level = mmbuf_level|( in_level<<(mmbuf_length*`JCBUF_OFF) );
	assign                                  comb_length = mmbuf_length + in_length;	
	
	assign                           chain_ot_length[0] = 0;	
	assign                            chain_mul_next[0] = `MMBUF_LEN;
	
	generate
    for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mmbuf_update	
	    //basic info
    	wire                                        vld = i<comb_length;
		wire `N(`MMBUF_PARA_LEN)                   para = comb_para>>(i*`MMBUF_PARA_LEN);
        wire `N(`XLEN)                             addr = comb_addr>>(i*`XLEN);
        wire `N(`XLEN)                            wdata = comb_wdata>>(i*`XLEN);
        wire `N(`XLEN)                               pc = comb_pc>>(i*`XLEN);		
		//para
		wire                                        mul = para>>(`MMBUF_PARA_LEN-1);
		wire                                        lsu = ~mul;
		//level
		wire `N(`JCBUF_OFF)                       level = comb_level>>(i*`JCBUF_OFF);
		wire `N(`JCBUF_OFF)                    level_up = sub_level(level,level_decrease);
		wire                                 level_zero = level_up==0;
		wire                                      clear = level_clear & (level!=0);
		wire                                       pass = vld & ~clear;
		//out
        assign        out_para[`IDX(i,`MMBUF_PARA_LEN)] = pass ? para : 0;  
        assign                  out_addr[`IDX(i,`XLEN)] = pass ? addr : 0;
        assign                 out_wdata[`IDX(i,`XLEN)] = pass ? wdata : 0;
        assign                    out_pc[`IDX(i,`XLEN)] = pass ? pc : 0;		
		assign            out_level[`IDX(i,`JCBUF_OFF)] = level_up;
		assign                     chain_ot_length[i+1] = pass ? (i+1) : chain_ot_length[i];
        //mul
		assign                      chain_mul_next[i+1] = ( (i>=mul_bottom) & vld & mul & level_zero & (chain_mul_next[i]==`MMBUF_LEN) ) ? i : chain_mul_next[i];
		//lsu
		assign                       array_lsu_start[i] = vld & lsu & level_zero;
		assign                        array_mul_flag[i] = vld & mul & level_zero;
		//mem check
		wire `N(`RGBIT)                              rd = para>>4;
		assign          array_mem_check[`IDX(i,`RGBIT)] = rd;
	end
	endgenerate

	assign                                   out_length = chain_ot_length[`MMBUF_LEN];
	
	`FFx(mmbuf_para,0)
	mmbuf_para <= clear_pipeline ? 0 : ( out_para>>(mem_release*`MMBUF_PARA_LEN) );

    `FFx(mmbuf_addr,0)
	mmbuf_addr <= clear_pipeline ? 0 : ( out_addr>>(mem_release*`XLEN) );

    `FFx(mmbuf_wdata,0)
	mmbuf_wdata <= clear_pipeline ? 0 : ( out_wdata>>(mem_release*`XLEN) );

    `FFx(mmbuf_pc,0)
	mmbuf_pc <= clear_pipeline ? 0 : ( out_pc>>(mem_release*`XLEN) );

    `FFx(mmbuf_level,0)
	mmbuf_level <= (clear_pipeline|level_clear) ? 0 : ( out_level>>(mem_release*`JCBUF_OFF) );

	`FFx(mmbuf_length,0)
	mmbuf_length <= clear_pipeline ? 0 : (out_length - mem_release);		
	

    //---------------------------------------------------------------------------
    //mul processing
    //---------------------------------------------------------------------------
	
	wire                                    mul_get_vld = mul_order!=`MMBUF_LEN;
	wire `N(3)                             mul_get_para = mmbuf_para>>(mul_order*`MMBUF_PARA_LEN);
	wire `N(`XLEN)                          mul_get_rs0 = mmbuf_addr>>(mul_order*`XLEN);
	wire `N(`XLEN)                          mul_get_rs1 = mmbuf_wdata>>(mul_order*`XLEN);	

	wire                                   mul_idle_vld = |mul_ready;
	wire `N(`MUL_OFF)                      mul_idle_num = lowest_mul(mul_ready);
	
	wire                                    mul_hit_vld = mul_get_vld & mul_idle_vld;	
	wire `N(`MUL_OFF)                       mul_hit_pos = mul_hit_vld ? mul_idle_num : 0;
	
	assign                                  mul_initial = mul_hit_vld<<mul_idle_num;
	assign                                     mul_para = {`MUL_LEN{mul_get_para}};
	assign                                      mul_rs0 = {`MUL_LEN{mul_get_rs0}};
	assign                                      mul_rs1 = {`MUL_LEN{mul_get_rs1}};

    wire `N(`MMBUF_OFF)                  mul_next_order = chain_mul_next[`MMBUF_LEN];

    `FFx(mul_bottom,0)
    if ( clear_pipeline )
        mul_bottom <= 0;
    else if ( ((mul_order==`MMBUF_LEN)|mul_hit_vld) & (mul_next_order!=`MMBUF_LEN) )
	    mul_bottom <= mul_next_order + 1'b1 - mem_release;
	else
	    mul_bottom <= (mul_bottom < mem_release) ? 0 : (mul_bottom - mem_release);


    `FFx(mul_order,`MMBUF_LEN)
    if ( clear_pipeline )
        mul_order <= `MMBUF_LEN;
    else if ( (mul_order==`MMBUF_LEN)|mul_hit_vld )
        mul_order <= (mul_next_order==`MMBUF_LEN) ? `MMBUF_LEN : (mul_next_order - mem_release);
	else
	    mul_order <= mul_order - mem_release;


    //---------------------------------------------------------------------------
    //lsu processing
    //---------------------------------------------------------------------------

    assign                                  lsu_initial = array_lsu_start>>lsu_order;
	assign                                     lsu_para = comb_para>>(lsu_order*`MMBUF_PARA_LEN);
	assign                                     lsu_addr = comb_addr>>(lsu_order*`XLEN);
	assign                                    lsu_wdata = comb_wdata>>(lsu_order*`XLEN);         

    wire                                     lsu_accept = lsu_initial & lsu_ready;
    wire                                        lsu_inc = lsu_accept|( array_mul_flag>>lsu_order );
	wire `N(`MMBUF_OFF)                    lsu_order_in = lsu_order + lsu_inc;
	
	`FFx(lsu_order,0)
	lsu_order <= clear_pipeline ? 0 : ( ( lsu_order_in < mem_release ) ? 0 : ( lsu_order_in - mem_release ) );
	

    //---------------------------------------------------------------------------
    //mem release
    //---------------------------------------------------------------------------

	reg  `N(`MMBUF_LEN)             mmbuf_done_vld;
	reg  `N(`MMBUF_LEN)             mmbuf_done_sel;
	reg  `N(`MMBUF_LEN*`MUL_OFF)    mmbuf_done_mul;
	
	`FFx(mmbuf_done_vld,0)
	mmbuf_done_vld <= clear_pipeline ? 0 : ( ( mmbuf_done_vld|(mul_hit_vld<<mul_order)|(lsu_accept<<lsu_order) )>>mem_release );
	
	`FFx(mmbuf_done_sel,0)
	mmbuf_done_sel <= clear_pipeline ? 0 : ( ( mmbuf_done_sel|(mul_hit_vld<<mul_order) )>>mem_release );
	
	`FFx(mmbuf_done_mul,0)
	mmbuf_done_mul <= clear_pipeline ? 0 : ( ( mmbuf_done_mul|(mul_hit_pos<<(mul_order*`MUL_OFF)) )>>(mem_release*`MUL_OFF) );
	
	
	wire `N(`MUL_LEN)    chain_mul_finished `N(`MEM_LEN+1);
	wire                 chain_lsu_finished `N(`MEM_LEN+1);
	wire              chain_last_unfinished `N(`MEM_LEN+1);
	wire `N(`MEM_OFF)         chain_release `N(`MEM_LEN+1);
	wire `N(`MUL_LEN)         chain_mul_ack `N(`MEM_LEN+1);
	wire                      chain_lsu_ack `N(`MEM_LEN+1);
	
	assign                        chain_mul_finished[0] = mul_finished;
	assign                        chain_lsu_finished[0] = lsu_finished;
	assign                     chain_last_unfinished[0] = 0;
    assign                             chain_release[0] = 0;	
	assign                             chain_mul_ack[0] = 0;
	assign                             chain_lsu_ack[0] = 0;
	
	generate
	for (i=0;i<`MEM_LEN;i=i+1) begin:gen_mem_data
	    //data
	    wire                                        vld = mmbuf_done_vld>>i;
		wire                                        sel = mmbuf_done_sel>>i;
	    wire `N(`MUL_OFF)                    mul_offset = mmbuf_done_mul>>(i*`MUL_OFF);
		wire `N(`XLEN)                          mul_out = mul_data>>(mul_offset*`XLEN);
        wire `N(`XLEN)                          lsu_out = lsu_rdata;
        wire `N(`XLEN)                          mem_out = sel ? mul_out : lsu_out;
		//hit
		wire `N(`MMBUF_PARA_LEN)                   para = mmbuf_para>>(i*`MMBUF_PARA_LEN);
		wire `N(`RGBIT)                              rd = para>>4;
		wire                                        hit = ( rfbuf_order_list & `LASTBIT_MASK ) >> rd;
		//mark
		wire                                     mul_ok = chain_mul_finished[i]>>mul_offset;
        wire                                     lsu_ok = chain_lsu_finished[i];		
		wire                                    this_ok = sel ? mul_ok : lsu_ok;
		assign                  chain_mul_finished[i+1] = chain_mul_finished[i]^( (sel&mul_ok)<<mul_offset );
		assign                  chain_lsu_finished[i+1] = chain_lsu_finished[i]^( ~sel&lsu_ok );
		//output
		wire                                     permit = vld & this_ok & ~hit;
		assign               chain_last_unfinished[i+1] = chain_last_unfinished[i]|(~permit);
		wire                                        mok = permit & ~chain_last_unfinished[i];
		assign                  mem_sel[`IDX(i,`RGBIT)] = mok ? rd : 0;
		assign                  mem_data[`IDX(i,`XLEN)] = mem_out;
	    assign                       chain_release[i+1] = chain_release[i] + mok;
		assign                       chain_mul_ack[i+1] = chain_mul_ack[i]|( (mok & sel)<<mul_offset );
		assign                       chain_lsu_ack[i+1] = chain_lsu_ack[i]|( mok & ~sel );
	end
	endgenerate
	
	assign                                  mem_release = chain_release[`MEM_LEN];
	assign                                      mul_ack = chain_mul_ack[`MEM_LEN];
	assign                                      lsu_ack = chain_lsu_ack[`MEM_LEN];
	
	
    //---------------------------------------------------------------------------
    //info collection
    //---------------------------------------------------------------------------	
	
	//"check" : list all Rds. 
    assign                            mmbuf_check_rdnum = array_mem_check>>(mem_release*`RGBIT);
	
	wire `N(`RGLEN)                    chain_mem_check `N(`MMBUF_LEN+1);
	
	assign                           chain_mem_check[0] = 0;
	
	generate
	for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mem_check
	    wire `N(`RGBIT)                              rd = array_mem_check>>(i*`RGBIT);
		wire                                     remove = (i<=mem_release);
		wire                                        get = ~remove;
		assign                     chain_mem_check[i+1] = chain_mem_check[i]|(get<<rd);
	end
	endgenerate
	
	assign                           mmbuf_check_rdlist = chain_mem_check[`MMBUF_LEN];
	
	//"level" : only list Rds (level==0) of membuf

    wire `N(`RGLEN)                  chain_mem_level `N(`MMBUF_LEN+1);

    assign                           chain_mem_level[0] = 0;
  
    generate
	for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mem_level
	    wire `N(`MMBUF_PARA_LEN)                   para = mmbuf_para>>(i*`MMBUF_PARA_LEN);
		wire `N(`RGBIT)                              rd = para>>4;
		wire `N(`JCBUF_OFF)                       level = mmbuf_level>>(i*`JCBUF_OFF);
		wire                                 level_zero = level==0;
		wire                                     remove = (i<mem_release);
        wire                                        get = level_zero & ~remove;		
		assign                     chain_mem_level[i+1] = chain_mem_level[i]|(get<<rd);
	end
	endgenerate

    assign                           mmbuf_instr_rdlist = chain_mem_level[`MMBUF_LEN];

    //others

	assign                                mmbuf_mem_num = mmbuf_length;

    assign                            dmem_exception[1] = 0;

    assign                            dmem_exception[0] = 0;
 
    assign                                mmbuf_intflag = 0;

    assign                                  mmbuf_intpc = 0;
	
	assign                                     mem_busy = 0;
	
endmodule