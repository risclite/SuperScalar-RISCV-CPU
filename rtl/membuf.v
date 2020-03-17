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

	input  `N(`EXEC_LEN)                     mem_vld,
	input  `N(`EXEC_LEN*`MMBUF_PARA_LEN)     mem_para,
	input  `N(`EXEC_LEN*`XLEN)               mem_addr,
	input  `N(`EXEC_LEN*`XLEN)               mem_wdata,
	input  `N(`EXEC_LEN*`XLEN)               mem_pc,
	input  `N(`EXEC_LEN*`JCBUF_OFF)          mem_level,

    output `N(`RGBIT)                        mem_sel,
    output `N(`XLEN)                         mem_data,	

    output                                   mem_release,
	input                                    clear_pipeline,
	input                                    level_decrease,
	input                                    level_clear,
	input  `N(`RGLEN)                        rfbuf_order_list,
	output                                   mmbuf_check_flag,
	output `N(`RGBIT)                        mmbuf_check_rdnum,
	output `N(`RGLEN)                        mmbuf_check_rdlist,
	output `N(`RGLEN)                        mmbuf_level_rdlist,
	output `N(`MMBUF_OFF)                    mmbuf_mem_num,	    
	output                                   mmbuf_intflag,
    output `N(`XLEN)                         mmbuf_intpc,
    output `N(2)                             dmem_exception,
	output                                   mem_busy,	

    output `N(`MUL_LEN)                      mul_initial,
	output `N(`MUL_LEN*3)                    mul_para,
	output `N(`MUL_LEN*`XLEN)                mul_rs0,
	output `N(`MUL_LEN*`XLEN)                mul_rs1,
	input  `N(`MUL_LEN)                      mul_ready,
	input  `N(`MUL_LEN)                      mul_finished,
	input  `N(`MUL_LEN*`XLEN)                mul_data,
	output `N(`MUL_LEN)                      mul_ack,
	
    output                                   dmem_req,
	output                                   dmem_cmd,
	output `N(2)                             dmem_width,
	output `N(`XLEN)                         dmem_addr,
	output `N(`XLEN)                         dmem_wdata,
	input  `N(`XLEN)                         dmem_rdata,
	input                                    dmem_resp,
	input                                    dmem_err

);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------
	
	function `N(`MUL_OFF) lowest_one( input `N(`MUL_LEN) d );
	    integer i;
	begin
	    lowest_one = 0;
	    for (i=0;i<`MUL_LEN;i=i+1) 
		    if ( d[`MUL_LEN-1-i] )
			    lowest_one = `MUL_LEN-1-i;
	end
	endfunction

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	wire `N(`EXEC_OFF)                       chain_in_num            `N(`EXEC_LEN+1);
	wire `N(`EXEC_OFF)                       in_shift                `N(`EXEC_LEN);

	reg  `N(`EXEC_LEN*`MMBUF_PARA_LEN)       in_para;
	reg  `N(`EXEC_LEN*`XLEN)                 in_addr,in_wdata,in_pc;
	reg  `N(`EXEC_LEN*`JCBUF_OFF)            in_level;
    wire `N(`EXEC_OFF)                       in_length;	

    reg  `N(`MMBUF_OFF)                      mmbuf_length;
	reg  `N(`MMBUF_LEN*`MMBUF_PARA_LEN)      mmbuf_para;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_addr;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_wdata;
	reg  `N(`MMBUF_LEN*`XLEN)                mmbuf_pc;
	reg  `N(`MMBUF_LEN*`JCBUF_OFF)           mmbuf_level;

	wire `N(`EXEC_LEN*`MMBUF_PARA_LEN)       chain_in_para           `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_addr           `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_wdata          `N(`EXEC_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_in_pc             `N(`EXEC_LEN+1);	

	wire `N(`MMBUF_LEN*`JCBUF_OFF)           combine_level_up;
	wire `N(`MMBUF_OFF)                      chain_real_length       `N(`MMBUF_LEN+1);
	
    wire `N(`MMBUF_LEN)                      chain_out_vld;
	wire `N(`MMBUF_LEN*`RGBIT)               chain_out_rd;
	wire `N(`MMBUF_LEN)                      chain_out_zero;

	wire `N(`MMBUF_OFF)                      chain_get_num           `N(`MMAREA_LEN+1);
	wire `N(`MMBUF_OFF)                      chain_get_order         `N(`MMAREA_LEN+1);
	
	reg  `N(`MMBUF_OFF)                      mul_next_order;
	reg  `N(`MMAREA_LEN)                     mul_fetch_vld;
	reg  `N(`MMAREA_LEN*`MUL_OFF)            mul_fetch_sel;	
	
	wire `N(`RGLEN)                          chain_check_rdlist      `N(`MMBUF_LEN+1);
	wire `N(`RGLEN)                          chain_level_rdlist      `N(`MMBUF_LEN+1);

    wire                                     check_idx0_flag,check_idx1_flag,check_idx2_flag;
	wire `N(`RGBIT)                          check_idx0_rdnum,check_idx1_rdnum,check_idx2_rdnum;
	wire `N(`RGBIT)                          level_idx0_rdnum,level_idx1_rdnum;

    reg                                      mmbuf_check_flag_ch0,mmbuf_check_flag_ch1;
	reg  `N(`RGBIT)                          mmbuf_check_rdnum_ch0,mmbuf_check_rdnum_ch1;
	reg  `N(`RGLEN)                          mmbuf_check_rdlist_rg;
    reg  `N(`RGBIT)                          mmbuf_level_rdnum;
	reg  `N(`RGLEN)                          mmbuf_level_rdlist_rg;

    reg                                      command_lag;
	reg  `N(`XLEN)                           command_data;

	reg                                      command_busy;	
    reg                                      req_sent;	

    genvar i;
	
	`include "include_func.v"
    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------

    //---------------------------------------------------------------------------
    //membuf update
    //---------------------------------------------------------------------------

    //incoming processing
	assign       chain_in_num[0] = 0;
	
	generate
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_in_num
		assign       in_shift[i] = mem_vld[i] ? chain_in_num[i] : `EXEC_LEN;
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
		    in_para  = in_para|( mem_para[`IDX(i,`MMBUF_PARA_LEN)]<<(in_shift[i]*`MMBUF_PARA_LEN) );
			in_addr  = in_addr|( mem_addr[`IDX(i,`XLEN)]<<(in_shift[i]*`XLEN) );
			in_wdata = in_wdata|( mem_wdata[`IDX(i,`XLEN)]<<(in_shift[i]*`XLEN) );
			in_pc    = in_pc|( mem_pc[`IDX(i,`XLEN)]<<(in_shift[i]*`XLEN) );
			in_level = in_level|( mem_level[`IDX(i,`JCBUF_OFF)]<<(in_shift[i]*`JCBUF_OFF) );
		end
	end

    assign in_length = chain_in_num[`EXEC_LEN];
	
	//mul & csr processing	
	wire `N(`MMBUF_LEN*`MMBUF_PARA_LEN)    combine_para = mmbuf_para|( in_para<<(mmbuf_length*`MMBUF_PARA_LEN) );
	wire `N(`MMBUF_LEN*`XLEN)              combine_addr = mmbuf_addr|( in_addr<<(mmbuf_length*`XLEN) );
	wire `N(`MMBUF_LEN*`XLEN)             combine_wdata = mmbuf_wdata|( in_wdata<<(mmbuf_length*`XLEN) );
	wire `N(`MMBUF_LEN*`XLEN)                combine_pc = mmbuf_pc|( in_pc<<(mmbuf_length*`XLEN) );
	wire `N(`MMBUF_LEN*`JCBUF_OFF)        combine_level = mmbuf_level|( in_level<<(mmbuf_length*`JCBUF_OFF) );
	wire `N(`MMBUF_OFF)                  combine_length = mmbuf_length + in_length;	
	
	wire `N(`MMBUF_LEN*`MMBUF_PARA_LEN)   future_para;
	wire `N(`MMBUF_LEN*`XLEN)             future_addr;
	wire `N(`MMBUF_LEN*`XLEN)             future_wdata;
	wire `N(`MMBUF_LEN*`XLEN)             future_pc;
	
	assign                         chain_real_length[0] = 0;	
	
	generate
    for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mmbuf_update	
		wire                                        vld = i<combine_length;
		wire `N(`JCBUF_OFF)                       level = combine_level>>(i*`JCBUF_OFF);
		wire `N(`JCBUF_OFF)                    level_up = sub_level(level,level_decrease);
		wire                                      clear = level_clear & (level!=0);
		wire                                       pass = vld & ~clear;
		assign     combine_level_up[`IDX(i,`JCBUF_OFF)] = level_up;
		assign                   chain_real_length[i+1] = pass ? (i+1) : chain_real_length[i];
        assign     future_para[`IDX(i,`MMBUF_PARA_LEN)] = pass ? ( combine_para>>(i*`MMBUF_PARA_LEN) ) : 0;  
        assign               future_addr[`IDX(i,`XLEN)] = pass ? ( combine_addr>>(i*`XLEN) ) : 0;
        assign              future_wdata[`IDX(i,`XLEN)] = pass ? ( combine_wdata>>(i*`XLEN) ) : 0;
        assign                 future_pc[`IDX(i,`XLEN)] = pass ? ( combine_pc>>(i*`XLEN) ) : 0;		
	end
	endgenerate

	//membuf
	wire `N(`MMBUF_OFF)      real_length = chain_real_length[`MMBUF_LEN];
	
	`FFx(mmbuf_para,0)
	mmbuf_para <= clear_pipeline ? 0 : ( future_para>>(mem_release*`MMBUF_PARA_LEN) );

    `FFx(mmbuf_addr,0)
	mmbuf_addr <= clear_pipeline ? 0 : ( future_addr>>(mem_release*`XLEN) );

    `FFx(mmbuf_wdata,0)
	mmbuf_wdata <= clear_pipeline ? 0 : ( future_wdata>>(mem_release*`XLEN) );

    `FFx(mmbuf_pc,0)
	mmbuf_pc <= clear_pipeline ? 0 : ( future_pc>>(mem_release*`XLEN) );

    `FFx(mmbuf_level,0)
	mmbuf_level <= (clear_pipeline|level_clear) ? 0 : ( combine_level_up>>(mem_release*`JCBUF_OFF) );

	`FFx(mmbuf_length,0)
	mmbuf_length <= clear_pipeline ? 0 : (real_length - mem_release);		
	

    //---------------------------------------------------------------------------
    //mul processing
    //---------------------------------------------------------------------------

	assign                             chain_get_num[0] = 0;
	assign                           chain_get_order[0] = `MMBUF_LEN;	
	
    generate
	for (i=0;i<`MMAREA_LEN;i=i+1) begin:gen_mmbuf_mul
		wire `N(`MMBUF_PARA_LEN)                   para = mmbuf_para>>(i*`MMBUF_PARA_LEN);
		wire                                        mul = ( para>>(`MMBUF_PARA_LEN-1) );	
		wire `N(`JCBUF_OFF)                       level = mmbuf_level>>(i*`JCBUF_OFF);	
		wire                                   real_mul = mul & (level==0);
		assign                       chain_get_num[i+1] = chain_get_num[i] + real_mul;
		assign                     chain_get_order[i+1] = ( (chain_get_num[i]==mul_next_order) & real_mul ) ? i : chain_get_order[i];	
	end
	endgenerate

	wire `N(`MMBUF_OFF)                   mul_get_order = chain_get_order[`MMAREA_LEN];
    wire                                    mul_get_vld = mul_get_order!=`MMBUF_LEN;
	wire `N(3)                             mul_get_para = mmbuf_para>>(mul_get_order*`MMBUF_PARA_LEN);
	wire `N(`XLEN)                          mul_get_rs0 = mmbuf_addr>>(mul_get_order*`XLEN);
	wire `N(`XLEN)                          mul_get_rs1 = mmbuf_wdata>>(mul_get_order*`XLEN);
	
	wire                                   mul_idle_vld = |mul_ready;
	wire `N(`MUL_OFF)                      mul_idle_num = lowest_one(mul_ready);
	
	wire                                    mul_new_vld = mul_get_vld & mul_idle_vld;	
	wire `N(`MUL_OFF)                       mul_new_sel = mul_new_vld ? mul_idle_num : 0;
	
	assign                                  mul_initial = mul_new_vld<<mul_idle_num;
	assign                                     mul_para = {`MUL_LEN{mul_get_para}};
	assign                                      mul_rs0 = {`MUL_LEN{mul_get_rs0}};
	assign                                      mul_rs1 = {`MUL_LEN{mul_get_rs1}};

    wire                                   mul_this_vld = mul_fetch_vld;
	wire `N(`MUL_OFF)                      mul_this_sel = mul_fetch_sel;
    wire                              mul_this_finished = mul_finished>>mul_this_sel;
	
	wire                                 mul_this_ready = mul_this_vld & mul_this_finished;
	wire `N(`XLEN)                        mul_this_data = mul_data>>(mul_this_sel*`XLEN);
	
	wire                                    mul_release = mul_this_vld & mem_release;	
	assign                                      mul_ack = mul_release<<mul_this_sel;

    `FFx(mul_fetch_vld,0)
    mul_fetch_vld <= clear_pipeline ? 0 : ( ( mul_fetch_vld|(mul_new_vld<<mul_get_order) )>>mem_release );	
		
	`FFx(mul_fetch_sel,0)
	mul_fetch_sel <= clear_pipeline ? 0 : ( ( mul_fetch_sel|(mul_new_sel<<(mul_get_order*`MUL_OFF)) )>>(mem_release*`MUL_OFF) );

    `FFx(mul_next_order,0)
    mul_next_order <= clear_pipeline ? 0 : ( mul_next_order + mul_new_vld - mul_release );

    //---------------------------------------------------------------------------
    //dmem response
    //---------------------------------------------------------------------------		
	
	wire `N(`MMBUF_PARA_LEN)   resp_para = mmbuf_para;
	wire                 resp_para_hibit = resp_para>>(`MMBUF_PARA_LEN-1);
	wire                        resp_mul =  resp_para_hibit;
	wire                        resp_mem = ~resp_para_hibit;
    wire                        resp_vld = ( mmbuf_length!=0 );	

	wire `N(`XLEN)          mem_unsigned = resp_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	wire `N(`XLEN)            mem_signed = resp_para[0] ? { {16{dmem_rdata[15]}}, dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	wire `N(`XLEN)              mem_word = resp_para[2] ? mem_unsigned : ( resp_para[1] ? dmem_rdata : mem_signed);
	
	wire `N(`XLEN)         mem_prep_data = resp_mul ? mul_this_data : mem_word;	
	
    //mem processing	
    wire                 command_release = resp_vld & ( (resp_mul & mul_this_ready)|(resp_mem & req_sent & dmem_resp & ~dmem_err) );
	wire                     command_hit = ( rfbuf_order_list & `LASTBIT_MASK ) >> resp_para[8:4];

    `FFx(command_lag,0)
    if ( ~command_lag & command_release & command_hit )
        command_lag <= 1'b1;
    else if ( command_lag & ~command_hit )
        command_lag <= 1'b0;
    else;		
   
    `FFx(command_data,0)
    if ( ~command_lag & command_release & command_hit )
        command_data <= mem_prep_data;
    else;

	assign                   mem_release = (command_lag|command_release) & ~command_hit;	
	assign                       mem_sel = (mem_release & ~resp_para[3]) ? resp_para[8:4] : 5'b0;
	assign                      mem_data = command_lag ? command_data : mem_prep_data;

    //---------------------------------------------------------------------------
    //dmem request
    //---------------------------------------------------------------------------	
	
	wire `N(`JCBUF_OFF)     active_level = combine_level_up;
	wire                      active_vld = ( combine_length!=0 ) & (active_level==0);	
	wire `N(`MMBUF_PARA_LEN) active_para = combine_para;
	wire               active_para_hibit = active_para>>(`MMBUF_PARA_LEN-1);
	wire                      active_mul =  active_para_hibit;
	wire                      active_mem = ~active_para_hibit;
	wire `N(`XLEN)           active_addr = combine_addr;
	wire `N(`XLEN)          active_wdata = combine_wdata;
	wire `N(`XLEN)             active_pc = combine_pc;
	
	wire `N(`JCBUF_OFF)      alter_level = combine_level_up>>`JCBUF_OFF;
	wire                       alter_vld = ( combine_length!=0 ) &  ( combine_length!=1 ) & (alter_level==0);
	wire `N(`MMBUF_PARA_LEN)  alter_para = combine_para>>`MMBUF_PARA_LEN;
	wire                alter_para_hibit = alter_para>>(`MMBUF_PARA_LEN-1);
	wire                       alter_mul =  alter_para_hibit;
	wire                       alter_mem = ~alter_para_hibit;	
	wire `N(`XLEN)            alter_addr = combine_addr>>`XLEN;
	wire `N(`XLEN)           alter_wdata = combine_wdata>>`XLEN;
	wire `N(`XLEN)              alter_pc = combine_pc>>`XLEN;  		
	
    wire                      request_go = ( active_vld & active_mem & ~req_sent )|( alter_vld & alter_mem );
	
	wire                     mem_is_idle = (active_mem & ~req_sent)|mem_release;
	
	`FFx(req_sent,1'b0)
	if ( mem_is_idle )
	    req_sent <= request_go;
	else;	

    wire                    alter_select = active_mul|req_sent;
    assign                      dmem_req = request_go & mem_is_idle;
	assign                      dmem_cmd = alter_select ? alter_para[3] : active_para[3];
    assign                    dmem_width = alter_select ? alter_para[1:0] : active_para[1:0];
	assign       dmem_addr[2+:(`XLEN-2)] = alter_select ? alter_addr[2+:(`XLEN-2)] : active_addr[2+:(`XLEN-2)];
    assign  	          dmem_addr[1:0] = alter_select ? ( (dmem_width==2'b00) ? alter_addr[1:0] : ( (dmem_width==2'b01) ? {alter_addr[1],1'b0} : 2'b00 ) ) : ( (dmem_width==2'b00) ? active_addr[1:0] : ( (dmem_width==2'b01) ? {active_addr[1],1'b0} : 2'b00 ) );
	assign                    dmem_wdata = alter_select ? alter_wdata : active_wdata;	
	
	
    //---------------------------------------------------------------------------
    //info collection
    //---------------------------------------------------------------------------	
	
	assign                        chain_check_rdlist[0] = 0;
	assign                        chain_level_rdlist[0] = 0;	
	
    generate
	for (i=0;i<`MMBUF_LEN;i=i+1) begin:gen_mmbuf_info
        //para:  mul-->{ 1'b1, instr[11:7], 1'b0, instr[14:12] }; mem-->{ instr[11:7], instr[5] ,instr[14:12] };	
		wire                                        vld = i<combine_length;
		wire `N(`MMBUF_PARA_LEN)                   para = combine_para>>(i*`MMBUF_PARA_LEN);
		wire `N(`RGBIT)                              rd = para[3] ? 0 : (para>>4);
		wire `N(`JCBUF_OFF)                       level = combine_level>>(i*`JCBUF_OFF);
		wire                                 level_zero = (level==0)|((level==1)&level_decrease);

		assign                         chain_out_vld[i] = vld;
		assign             chain_out_rd[`IDX(i,`RGBIT)] = rd;
		assign                        chain_out_zero[i] = level_zero;		
		
        assign                  chain_check_rdlist[i+1] = chain_check_rdlist[i]|( ((i==0)|(i==1)|(i==2)) ? 0 : (1'b1<<rd) ); 
        assign                  chain_level_rdlist[i+1] = chain_level_rdlist[i]|( ((i==0)|(i==1)) ? 0 : (level_zero<<rd) );
	end
	endgenerate

	assign	                            check_idx0_flag = chain_out_vld;
	assign		                       check_idx0_rdnum = chain_out_rd;
	wire                                level_idx0_zero = chain_out_zero;
	assign		                       level_idx0_rdnum = level_idx0_zero ? chain_out_rd : 0;

	assign	                            check_idx1_flag = chain_out_vld>>1;
	assign		                       check_idx1_rdnum = chain_out_rd>>`RGBIT;
	wire                                level_idx1_zero = chain_out_zero>>1;	
	assign		                       level_idx1_rdnum = level_idx1_zero ? (chain_out_rd>>`RGBIT) : 0;

	assign	                            check_idx2_flag = chain_out_vld>>2;
	assign		                       check_idx2_rdnum = chain_out_rd>>(2*`RGBIT);

    //misc processing	
    `FFx(mmbuf_check_flag_ch0,0)
	mmbuf_check_flag_ch0 <= clear_pipeline ? 0 : ( mem_release ? check_idx1_flag : check_idx0_flag );
	
	`FFx(mmbuf_check_flag_ch1,0)
	mmbuf_check_flag_ch1 <= clear_pipeline ? 0 : ( mem_release ? check_idx2_flag : check_idx1_flag );
	
	assign mmbuf_check_flag = mem_release ? mmbuf_check_flag_ch1 : mmbuf_check_flag_ch0;
	
	`FFx(mmbuf_check_rdnum_ch0,0)
	mmbuf_check_rdnum_ch0 <= clear_pipeline ? 0 : ( mem_release ? check_idx1_rdnum : check_idx0_rdnum );
	
	`FFx(mmbuf_check_rdnum_ch1,0)
	mmbuf_check_rdnum_ch1 <= clear_pipeline ? 0 : ( mem_release ? check_idx2_rdnum : check_idx1_rdnum );
	
	assign mmbuf_check_rdnum = mem_release ? mmbuf_check_rdnum_ch1 : mmbuf_check_rdnum_ch0;
	
	`FFx(mmbuf_check_rdlist_rg,0)
	mmbuf_check_rdlist_rg <= clear_pipeline ? 0 : ( ( mem_release ? 0 : (1'b1<<check_idx2_rdnum) )|chain_check_rdlist[`MMBUF_LEN] );
	
	assign mmbuf_check_rdlist = mmbuf_check_rdlist_rg | ( mem_release ? 0 : (1'b1<<mmbuf_check_rdnum_ch1) );
	
	`FFx(mmbuf_level_rdnum,0)
	mmbuf_level_rdnum <= clear_pipeline ? 0 : ( mem_release ? level_idx1_rdnum : level_idx0_rdnum );
	
	`FFx(mmbuf_level_rdlist_rg,0)
	mmbuf_level_rdlist_rg <= clear_pipeline ? 0 : ( ( mem_release ? 0 : (1'b1<<level_idx1_rdnum) )|chain_level_rdlist[`MMBUF_LEN] );
	
	assign mmbuf_level_rdlist = mmbuf_level_rdlist_rg | ( mem_release ? 0 : (1'b1<<mmbuf_level_rdnum) );

	assign      mmbuf_mem_num = mmbuf_length;

    assign  dmem_exception[1] = req_sent & dmem_resp & dmem_err;

    assign  dmem_exception[0] = active_para[3];
 
    assign      mmbuf_intflag = 0;

    assign        mmbuf_intpc = 0;
	
	assign           mem_busy = resp_vld & ~mem_release;
	
endmodule