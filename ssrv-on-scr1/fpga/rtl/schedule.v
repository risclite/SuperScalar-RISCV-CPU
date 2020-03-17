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

module schedule(

    input                                                                    clk,
    input                                                                    rst,
 
    input  `N(`FETCH_LEN)                                                    fetch_vld,
    input  `N(`FETCH_LEN*`XLEN)                                              fetch_instr,
    input  `N(`FETCH_LEN*`XLEN)                                              fetch_pc,
    input  `N(`FETCH_LEN*`EXEC_PARA_LEN)                                     fetch_para,
	input  `N(`FETCH_LEN*`JCBUF_OFF)                                         fetch_level,
 
	output `N(`EXEC_LEN)                                                     exec_vld,
	output reg `N(`EXEC_LEN*`XLEN)                                           exec_instr,
	output reg `N(`EXEC_LEN*`XLEN)                                           exec_pc,	
	output reg `N(`EXEC_LEN*`EXEC_PARA_LEN)                                  exec_para,
	output reg `N(`EXEC_LEN*`MMCMB_OFF)                                      exec_order,
	output reg `N(`EXEC_LEN*`JCBUF_OFF)                                      exec_level,
 
	input                                                                    mmbuf_check_flag,
	input  `N(`RGBIT)                                                        mmbuf_check_rdnum,
	input  `N(`RGLEN)                                                        mmbuf_check_rdlist,
	input  `N(`RGLEN)                                                        mmbuf_level_rdlist,
	input  `N(`MMBUF_OFF)                                                    mmbuf_mem_num,
	input  `N(`RFBUF_OFF)                                                    rfbuf_alu_num,
    input                                                                    mem_release,
    input                                                                    clear_pipeline,
	input                                                                    level_decrease,
	input                                                                    level_clear,
    output `N(`SDBUF_OFF)                                                    sdbuf_left_num,
    output `N(`RGLEN)                                                        pipeline_level_rdlist,
    output                                                                   pipeline_is_empty,	
	output                                                                   schd_intflag,
    output `N(`XLEN)                   	                                     schd_intpc
	
);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

    `include "include_func.v"
	
	function check_both( input `N(`EXEC_PARA_LEN) para, input `N(`RGLEN) rd_list,rs_list );
        reg `N(`RGBIT) rs0,rs1,rd;	
        reg    rd_hit, rs_hit;		
	begin
        rs0        = para;
		rs1        = para>>`RGBIT;
		rd         = para>>(2*`RGBIT);
        
        rd_hit     = |( ( rd_list & `LASTBIT_MASK ) & ( 1'b1<<rd ) );
        rs_hit     = |( ( rs_list & `LASTBIT_MASK ) & ( ( 1'b1<<rs0 )|( 1'b1<<rs1 ) ) );
        
        check_both = rd_hit|rs_hit; 		
	end
	endfunction
	
	function check_gray( input `N(`EXEC_PARA_LEN) para, input `N(`RGBIT) gray_num );
        reg `N(`RGBIT) rs0,rs1,rd;	 
	begin
        rs0        = para;
		rs1        = para>>`RGBIT;
		rd         = para>>(2*`RGBIT);

        check_gray = |( ( ( 1'b1<<gray_num ) & `LASTBIT_MASK ) & ( (1'b1<<rs0)|(1'b1<<rs1)|(1'b1<<rd) ) );		
	end
	endfunction
	
	
    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------	
	wire `N((`FETCH_LEN+1)*`MMCMB_OFF)       chain_order;	
    wire `N(`FETCH_LEN*`MMCMB_OFF)           fetch_order;
	
    wire `N(`SDBUF_LEN)                      go_vld;  
	wire `N(`SDBUF_LEN*`XLEN)                go_instr;
	wire `N(`SDBUF_LEN*`XLEN)                go_pc;   
	wire `N(`SDBUF_LEN*`EXEC_PARA_LEN)       go_para;
	wire `N(`SDBUF_LEN*`MMCMB_OFF)           go_order;
	wire `N(`SDBUF_LEN*`JCBUF_OFF)           go_level;
	wire `N(`SDBUF_LEN)                      go_hit;
	wire `N(`SDBUF_LEN)                      go_preload;

    wire `N(`RGLEN)                          rd_checklist             `N(`SDBUF_LEN+1);
	wire `N(`RGLEN)                          rs_checklist             `N(`SDBUF_LEN+1);
    wire `N(`MMBUF_LEN)                      mem_active               `N(`SDBUF_LEN+1);
    wire `N(`RFBUF_LEN)                      rf_active                `N(`SDBUF_LEN+1);
    wire `N(`EXEC_LEN)                       exec_active              `N(`SDBUF_LEN+1);
	wire `N(`EXEC_OFF)                       exec_num                 `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_OFF)                      sdbuf_num                `N(`SDBUF_LEN+1);

	wire `N(`EXEC_LEN)                       chain_exec_direct        `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN)                       chain_exec_preload       `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_exec_instr         `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)                 chain_exec_pc            `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`EXEC_PARA_LEN)        chain_exec_para          `N(`SDBUF_LEN+1);
	wire `N(`EXEC_LEN*`MMCMB_OFF)            chain_exec_order         `N(`SDBUF_LEN+1);	
	wire `N(`EXEC_LEN*`JCBUF_OFF)            chain_exec_level         `N(`SDBUF_LEN+1);

	wire `N(`SDBUF_LEN)                      chain_sdbuf_direct       `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN)                      chain_sdbuf_preload      `N(`SDBUF_LEN+1);	
	wire `N(`SDBUF_LEN*`XLEN)                chain_sdbuf_instr        `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`XLEN)                chain_sdbuf_pc           `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`EXEC_PARA_LEN)       chain_sdbuf_para         `N(`SDBUF_LEN+1);
	wire `N(`SDBUF_LEN*`MMCMB_OFF)           chain_sdbuf_order        `N(`SDBUF_LEN+1);	
	wire `N(`SDBUF_LEN*`JCBUF_OFF)           chain_sdbuf_level        `N(`SDBUF_LEN+1);
	
	wire `N(`SDBUF_OFF)                      chain_sdexec_mem_num     `N(`SDBUF_LEN+1);
	wire `N(`RGLEN)                          chain_sdbuf_level_rdlist `N(`SDBUF_LEN+1);		
	
	wire `N(`EXEC_OFF)                       chain_exec_mem_num0      `N(`SDBUF_LEN+1);
	wire `N(`EXEC_OFF)                       chain_exec_mem_num1      `N(`SDBUF_LEN+1);	
	wire `N(`EXEC_OFF)                       chain_exec_alu_num0      `N(`SDBUF_LEN+1);
	wire `N(`EXEC_OFF)                       chain_exec_alu_num1      `N(`SDBUF_LEN+1);	
	wire                                     chain_check_flag0        `N(`SDBUF_LEN+1);
	wire                                     chain_check_flag1        `N(`SDBUF_LEN+1);
	wire `N(`RGBIT)                          chain_check_rdnum0       `N(`SDBUF_LEN+1);
	wire `N(`RGBIT)                          chain_check_rdnum1       `N(`SDBUF_LEN+1);
	wire `N(`RGLEN)                          chain_check_rdlist0      `N(`SDBUF_LEN+1);
	wire `N(`RGLEN)                          chain_check_rdlist1      `N(`SDBUF_LEN+1);	
	
	wire                                     chain_find_mem           `N(`SDBUF_LEN+1);
	wire `N(`XLEN)                           chain_find_pc            `N(`SDBUF_LEN+1);		
	
	reg  `N(`EXEC_LEN)                       exec_direct;
	reg  `N(`EXEC_LEN)                       exec_preload;

    reg  `N(`SDBUF_LEN)                      sdbuf_direct;
	reg  `N(`SDBUF_LEN)                      sdbuf_preload;
    wire `N(`SDBUF_LEN)                      sdbuf_vld;
    reg  `N(`SDBUF_LEN*`XLEN)                sdbuf_instr;
	reg  `N(`SDBUF_LEN*`XLEN)                sdbuf_pc;
	reg  `N(`SDBUF_LEN*`EXEC_PARA_LEN)       sdbuf_para;
	reg  `N(`SDBUF_LEN*`MMCMB_OFF)           sdbuf_order;
	reg  `N(`SDBUF_LEN*`JCBUF_OFF)           sdbuf_level;
	reg  `N(`SDBUF_OFF)                      sdbuf_length;

    reg  `N(`SDBUF_OFF)                      sdexec_mem_num;
	reg  `N(`RGLEN)                          sdbuf_level_rdlist;
	
	reg  `N(`EXEC_OFF)                       exec_mem_num0;
	reg  `N(`EXEC_OFF)                       exec_mem_num1;
	wire `N(`EXEC_OFF)                       exec_mem_num;	
	reg  `N(`EXEC_OFF)                       exec_alu_num0;
	reg  `N(`EXEC_OFF)                       exec_alu_num1;	
	wire `N(`EXEC_OFF)                       exec_alu_num;		
	reg  `N(`RGBIT)                          exec_check_rdnum0;
	reg  `N(`RGBIT)                          exec_check_rdnum1;
	wire `N(`RGBIT)                          exec_check_rdnum;
	reg  `N(`RGLEN)                          exec_check_rdlist0;
	reg  `N(`RGLEN)                          exec_check_rdlist1;
	wire `N(`RGLEN)                          exec_check_rdlist;
		
	wire `N(`RGBIT)                          check_num;
	wire `N(`RGLEN)                          check_rdlist;
	
    genvar i,j;
    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------
	
    //-------------------------------------------------------------------------------------------
    //to get order for every instuction: how many MEM instructions exist in membuf and sdbuf.
	//-------------------------------------------------------------------------------------------
	
	assign       chain_order[`IDX(0,`MMCMB_OFF)] = mmbuf_mem_num + sdexec_mem_num;
	
	generate
	for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_fetch_order
	    wire                                 vld = fetch_vld>>i;
	    wire `N(`EXEC_PARA_LEN)             para = fetch_para>>(i*`EXEC_PARA_LEN);
		wire                                 mem = para>>(1+3*`RGBIT);
		assign chain_order[`IDX(i+1,`MMCMB_OFF)] = chain_order[`IDX(i,`MMCMB_OFF)] + (vld&mem);
	end
	endgenerate
	
	assign                           fetch_order = chain_order>>`MMCMB_OFF;
	
	//-------------------------------------------------------------------------------------------
	//to evaluate sdbuf
	//-------------------------------------------------------------------------------------------
    //to combine incoming instructions and sdbuf instructions.
	assign                                go_vld = sdbuf_vld|(fetch_vld<<sdbuf_length);
	assign                              go_instr = sdbuf_instr|(fetch_instr<<(sdbuf_length*`XLEN));
	assign                                 go_pc = sdbuf_pc|(fetch_pc<<(sdbuf_length*`XLEN));
	assign                               go_para = sdbuf_para|(fetch_para<<(sdbuf_length*`EXEC_PARA_LEN));
	assign                              go_order = sdbuf_order|(fetch_order<<(sdbuf_length*`MMCMB_OFF));
	assign                              go_level = sdbuf_level|(fetch_level<<(sdbuf_length*`JCBUF_OFF));

    assign                       rd_checklist[0] = check_rdlist;
	assign                       rs_checklist[0] = check_rdlist;
    assign                         mem_active[0] = {`MMBUF_LEN{1'b1}}>>(mmbuf_mem_num + exec_mem_num);     //membuf left space
    assign                          rf_active[0] = {`RFBUF_LEN{1'b1}}>>(rfbuf_alu_num + exec_alu_num);     //rfbuf left space
    assign                        exec_active[0] = {`EXEC_LEN{1'b1}};	
	assign                           exec_num[0] = 0;
	assign                          sdbuf_num[0] = 0;
	
	assign                  chain_exec_direct[0] = 0;
	assign                 chain_exec_preload[0] = 0;
	assign                   chain_exec_instr[0] = 0;
	assign                      chain_exec_pc[0] = 0;
	assign                    chain_exec_para[0] = 0;
	assign                   chain_exec_order[0] = 0;
	assign                   chain_exec_level[0] = 0;   
	
	assign                 chain_sdbuf_direct[0] = 0;
	assign                chain_sdbuf_preload[0] = 0;
	assign                  chain_sdbuf_instr[0] = 0;
	assign                     chain_sdbuf_pc[0] = 0;
	assign                   chain_sdbuf_para[0] = 0;
	assign                  chain_sdbuf_order[0] = 0;
	assign                  chain_sdbuf_level[0] = 0;		
	
	assign               chain_sdexec_mem_num[0] = 0;
	assign           chain_sdbuf_level_rdlist[0] = 0;
	
    assign                chain_exec_mem_num0[0] = 0;
    assign                chain_exec_mem_num1[0] = 0;	
    assign                chain_exec_alu_num0[0] = 0;
    assign                chain_exec_alu_num1[0] = 0;	
    assign                  chain_check_flag0[0] = 0;
    assign                  chain_check_flag1[0] = 0;	
    assign                 chain_check_rdnum0[0] = 0;
    assign                 chain_check_rdnum1[0] = 0;	
    assign                chain_check_rdlist0[0] = 0;
    assign                chain_check_rdlist1[0] = 0;		
	
	assign                     chain_find_mem[0] = 0;
	assign                      chain_find_pc[0] = 0;	

    generate 
	for (i=0;i<`SDBUF_LEN;i=i+1) begin:gen_sdbuf
	    //basic info
		wire `N(`XLEN)                     instr = go_instr>>(i*`XLEN);
		wire `N(`XLEN)                        pc = go_pc>>(i*`XLEN);
		wire `N(`EXEC_PARA_LEN)             para = go_para>>(i*`EXEC_PARA_LEN);
		wire                                 mem = para>>(1+3*`RGBIT);
		wire                                 alu = para>>(3*`RGBIT);
		wire `N(`RGBIT)                      rs0 = para;
		wire `N(`RGBIT)                      rs1 = para>>`RGBIT;
		wire `N(`RGBIT)                       rd = para>>(2*`RGBIT);
		wire `N(`MMCMB_OFF)                order = go_order>>(i*`MMCMB_OFF);
		wire `N(`MMCMB_OFF)               orderx = sub_order(order,mem_release);	
        wire `N(`JCBUF_OFF)                level = go_level>>(i*`JCBUF_OFF);		
		wire `N(`JCBUF_OFF)               levelx = sub_level(level,level_decrease);
		wire                          level_zero = (level==0)|((level==1)&level_decrease);

        wire                           exec_idle = exec_active[i];
		wire                            mem_idle = mem_active[i];
		wire                             rf_idle = rf_active[i];
		wire                              rg_hit = check_both(para,rd_checklist[i],rs_checklist[i]);
		
		assign                         go_hit[i] = rg_hit|(~exec_idle)|(mem & ~mem_idle)|(alu & ~rf_idle);
		assign                     go_preload[i] = check_gray(para,check_num);
		
		wire                            alu2exec = alu & go_vld[i] & ~go_hit[i];
		wire                           alu2sdbuf = alu & go_vld[i] & (go_hit[i]|go_preload[i]);
		wire                            mem2exec = mem & go_vld[i] & ~go_hit[i];
		wire                           mem2sdbuf = mem & go_vld[i] & (go_hit[i]|go_preload[i]);
		
        //variable update
        assign                 rd_checklist[i+1] = rd_checklist[i]|(alu2sdbuf<<rd)|(alu2sdbuf<<rs0)|(alu2sdbuf<<rs1)|(mem2exec<<rd)|(mem2sdbuf<<rd)|(mem2sdbuf<<rs0)|(mem2sdbuf<<rs1);
        assign                 rs_checklist[i+1] = rs_checklist[i]|(alu2exec<<rd)|(alu2sdbuf<<rd)|(mem2exec<<rd)|(mem2sdbuf<<rd);		
        assign                  exec_active[i+1] = exec_active[i]>>( alu2exec|mem2exec );
		assign                   mem_active[i+1] = mem2sdbuf ? 0 : (mem_active[i]>>mem2exec);
		assign                    rf_active[i+1] = rf_active[i]>>( alu2exec|alu2sdbuf );
		assign                     exec_num[i+1] = exec_num[i] + ( alu2exec|mem2exec );
		assign                    sdbuf_num[i+1] = sdbuf_num[i] + ( alu2sdbuf|mem2sdbuf );

        //clear is a flag to signal this instruction is invalid.		
		wire                               clear = (alu & (rd==0))|( clear_pipeline &  ~((orderx==0)&(level==0)) )|( level_clear & (level!=0) );	
        
		//special instruction should be assigned to the last exec ALU.
        wire `N(`EXEC_OFF)            exec_shift = ( alu2exec|mem2exec ) ?  exec_num[i] : `EXEC_LEN;

		assign            chain_exec_direct[i+1] = chain_exec_direct[i]|( ((clear|go_preload[i]) ? 1'b0 : 1'b1)<<exec_shift );
        assign           chain_exec_preload[i+1] = chain_exec_preload[i]|( ( clear ? 1'b0 : go_preload[i] )<<exec_shift );	
		assign             chain_exec_instr[i+1] = chain_exec_instr[i]|( instr<<(exec_shift*`XLEN) );
		assign                chain_exec_pc[i+1] = chain_exec_pc[i]|( pc<<(exec_shift*`XLEN) );
		assign              chain_exec_para[i+1] = chain_exec_para[i]|( para<<(exec_shift*`EXEC_PARA_LEN) );
		assign             chain_exec_order[i+1] = chain_exec_order[i]|( orderx<<(exec_shift*`MMCMB_OFF) );
		assign             chain_exec_level[i+1] = chain_exec_level[i]|( levelx<<(exec_shift*`JCBUF_OFF) );	
		
		wire `N(`SDBUF_OFF)          sdbuf_shift = ( alu2sdbuf|mem2sdbuf ) ? sdbuf_num[i] : `SDBUF_LEN;
		
		assign           chain_sdbuf_direct[i+1] = chain_sdbuf_direct[i]|( (clear ? 1'b0 : go_hit[i])<<sdbuf_shift );
		assign          chain_sdbuf_preload[i+1] = chain_sdbuf_preload[i]|( ((clear|go_hit[i]) ? 1'b0 : 1'b1)<<sdbuf_shift );
		assign            chain_sdbuf_instr[i+1] = chain_sdbuf_instr[i]|( instr<<(sdbuf_shift*`XLEN) );
		assign               chain_sdbuf_pc[i+1] = chain_sdbuf_pc[i]|( pc<<(sdbuf_shift*`XLEN) );
		assign             chain_sdbuf_para[i+1] = chain_sdbuf_para[i]|(para<<(sdbuf_shift*`EXEC_PARA_LEN));
		assign            chain_sdbuf_order[i+1] = chain_sdbuf_order[i]|(orderx<<(sdbuf_shift*`MMCMB_OFF));
        assign            chain_sdbuf_level[i+1] = chain_sdbuf_level[i]|(levelx<<(sdbuf_shift*`JCBUF_OFF));	

        assign         chain_sdexec_mem_num[i+1] = chain_sdexec_mem_num[i] + ( go_vld[i] & mem & ~clear );
		assign     chain_sdbuf_level_rdlist[i+1] = chain_sdbuf_level_rdlist[i]|( ( go_vld[i] & level_zero & ~clear )<<rd );		
		
		wire                 mem_exclude_preload = mem2exec & ~go_preload[i] & ~clear;		
		wire                 mem_include_preload = mem2exec & ~clear;
		wire                 alu_exclude_preload = alu2exec & ~go_preload[i] & ~clear;			
		wire                 alu_include_preload = alu2exec & ~clear;	
		
        assign          chain_exec_mem_num0[i+1] = chain_exec_mem_num0[i] + mem_exclude_preload;
		assign          chain_exec_mem_num1[i+1] = chain_exec_mem_num1[i] + mem_include_preload;
        assign          chain_exec_alu_num0[i+1] = chain_exec_alu_num0[i] + alu_exclude_preload;
		assign          chain_exec_alu_num1[i+1] = chain_exec_alu_num1[i] + alu_include_preload;
		assign            chain_check_flag0[i+1] = chain_check_flag0[i]|mem_exclude_preload;
		assign            chain_check_flag1[i+1] = chain_check_flag1[i]|mem_include_preload;
		assign           chain_check_rdnum0[i+1] = ( ~chain_check_flag0[i] & mem_exclude_preload ) ? rd : chain_check_rdnum0[i];
		assign           chain_check_rdnum1[i+1] = ( ~chain_check_flag1[i] & mem_include_preload ) ? rd : chain_check_rdnum1[i];	
		assign          chain_check_rdlist0[i+1] = chain_check_rdlist0[i]|( ( chain_check_flag0[i]&mem_exclude_preload )<<rd );
		assign          chain_check_rdlist1[i+1] = chain_check_rdlist1[i]|( ( chain_check_flag1[i]&mem_include_preload )<<rd );
		
		assign               chain_find_mem[i+1] = chain_find_mem[i]|( go_vld[i] & mem & (levelx==0) );
		assign                chain_find_pc[i+1] = chain_find_mem[i] ? chain_find_pc[i] : pc;			
		
    end
	endgenerate		

	
	`FFx(exec_direct,0)
	exec_direct <= chain_exec_direct[`SDBUF_LEN];
	
	`FFx(exec_preload,0)
	exec_preload <= chain_exec_preload[`SDBUF_LEN];
	
	assign exec_vld = exec_direct|( exec_preload & {`EXEC_LEN{mem_release} } );
	
	`FFx(exec_instr,0)
	exec_instr <= chain_exec_instr[`SDBUF_LEN];
	
	`FFx(exec_pc,0)
	exec_pc <= chain_exec_pc[`SDBUF_LEN];
	
	`FFx(exec_para,0)
	exec_para <= chain_exec_para[`SDBUF_LEN];
	
	`FFx(exec_order,0)
	exec_order <= chain_exec_order[`SDBUF_LEN];
	
	`FFx(exec_level,0)
	exec_level <= chain_exec_level[`SDBUF_LEN];

 
 
	`FFx(sdbuf_direct,0)
	sdbuf_direct <= chain_sdbuf_direct[`SDBUF_LEN];

	`FFx(sdbuf_preload,0)
	sdbuf_preload <= chain_sdbuf_preload[`SDBUF_LEN];

    assign sdbuf_vld = sdbuf_direct|( sdbuf_preload & ( mem_release ? 0 : {`SDBUF_LEN{1'b1}} ) );
	
	`FFx(sdbuf_instr,0)
	sdbuf_instr <= chain_sdbuf_instr[`SDBUF_LEN];
	
	`FFx(sdbuf_pc,0)
	sdbuf_pc <= chain_sdbuf_pc[`SDBUF_LEN];
	
	`FFx(sdbuf_para,0)
	sdbuf_para <= chain_sdbuf_para[`SDBUF_LEN];
	
	`FFx(sdbuf_order,0)
	sdbuf_order <= chain_sdbuf_order[`SDBUF_LEN];
	
	`FFx(sdbuf_level,0)
	sdbuf_level <= chain_sdbuf_level[`SDBUF_LEN];
	
	`FFx(sdbuf_length,0)
	sdbuf_length <= sdbuf_num[`SDBUF_LEN];
	
	
    `FFx(sdexec_mem_num,0)
    sdexec_mem_num <= chain_sdexec_mem_num[`SDBUF_LEN];
  
 	`FFx(sdbuf_level_rdlist,0)
	sdbuf_level_rdlist <= chain_sdbuf_level_rdlist[`SDBUF_LEN]; 
	
    `FFx(exec_mem_num0,0)
    exec_mem_num0 <= chain_exec_mem_num0[`SDBUF_LEN];
	
    `FFx(exec_mem_num1,0)
    exec_mem_num1 <= chain_exec_mem_num1[`SDBUF_LEN];	
	
	assign exec_mem_num = mem_release ? exec_mem_num1 : exec_mem_num0;
 
    `FFx(exec_alu_num0,0)
    exec_alu_num0 <= chain_exec_alu_num0[`SDBUF_LEN];	
	
    `FFx(exec_alu_num1,0)
    exec_alu_num1 <= chain_exec_alu_num1[`SDBUF_LEN];		
	
	assign exec_alu_num = mem_release ? exec_alu_num1 : exec_alu_num0;
	
	`FFx(exec_check_rdnum0,0)
	exec_check_rdnum0 <= chain_check_rdnum0[`SDBUF_LEN];	
	
	`FFx(exec_check_rdnum1,0)
	exec_check_rdnum1 <= chain_check_rdnum1[`SDBUF_LEN];		
	
	assign exec_check_rdnum = mem_release ? exec_check_rdnum1 : exec_check_rdnum0;
	
	`FFx(exec_check_rdlist0,0)
	exec_check_rdlist0 <= chain_check_rdlist0[`SDBUF_LEN];	
	
	`FFx(exec_check_rdlist1,0)
	exec_check_rdlist1 <= chain_check_rdlist1[`SDBUF_LEN];		
	
	assign exec_check_rdlist = mem_release ? exec_check_rdlist1 : exec_check_rdlist0;	
	
	assign check_num = mmbuf_check_flag ? mmbuf_check_rdnum : exec_check_rdnum;
	
	assign check_rdlist = mmbuf_check_rdlist|( mmbuf_check_flag ? ( 1'b1<<exec_check_rdnum ) : 0 )|exec_check_rdlist;
	
	assign                           sdbuf_left_num = `SDBUF_LEN - sdbuf_length;
	assign                    pipeline_level_rdlist = mmbuf_level_rdlist|sdbuf_level_rdlist;
	assign                        pipeline_is_empty = (mmbuf_mem_num==0)&(rfbuf_alu_num==0)&(sdbuf_length==0)&(exec_direct==0);
    assign                             schd_intflag = chain_find_mem[`SDBUF_LEN];
    assign                               schd_intpc = chain_find_mem[`SDBUF_LEN] ? chain_find_pc[`SDBUF_LEN] : fetch_pc;

endmodule

