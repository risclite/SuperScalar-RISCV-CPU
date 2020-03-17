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
    input                                 clk,
    input                                 rst,
	
	output                                sys_vld,
	output `N(`XLEN)                      sys_instr,
	output `N(`XLEN)                      sys_pc,
	output `N(4)                          sys_para,
	
	output                                csr_vld,
	output `N(`XLEN)                      csr_instr,
	output `N(`XLEN)                      csr_rs,
	output `N(`RGBIT)                     csr_rd_sel,
	
    input                                 jump_vld,
	input  `N(`XLEN)                      jump_pc,	
    output                                branch_vld,
	output `N(`XLEN)                      branch_pc,	
    output                                buffer_free,	
    input                                 instr_vld,
    input  `N(`BUS_WID)                   instr_data,
	input                                 instr_err,	
	input  `N(2*`BUS_LEN)                 instr_predict,
 
    output `N(`RGBIT)                     rs0_sel,
	output `N(`RGBIT)                     rs1_sel,
	input  `N(`XLEN)                      rs0_word,
	input  `N(`XLEN)                      rs1_word,
	
	input  `N(`RGLEN)                     pipeline_level_rdlist,
	input                                 pipeline_is_empty,
    input  `N(`SDBUF_OFF)                 sdbuf_left_num,
  
	output `N(`FETCH_LEN)                 fetch_vld,
    output `N(`FETCH_LEN*`XLEN)           fetch_instr,
	output `N(`FETCH_LEN*`XLEN)           fetch_pc,
    output `N(`FETCH_LEN*`EXEC_PARA_LEN)  fetch_para,
	output `N(`FETCH_LEN*`JCBUF_OFF)      fetch_level,
	
	output                                jcond_vld,
	output `N(`XLEN)                      jcond_pc,
	output                                jcond_hit,
	output                                jcond_satisfied,
	
	output                                level_decrease,
	output                                level_clear


);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

    `include "include_func.v"
	
    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	reg   `N(`BUS_OFF)                    instr_offset;	
	
	wire  `N(`RGLEN)                      fetch_level_rdlist;
	wire  `N(`FETCH_OFF)                  fetch_length;
	wire                                  fetch_is_empty;
	
	wire                                  jalr_vld;
	wire  `N(`XLEN)                       jalr_instr;
	wire                                  jalr_rs0_valid;
	
	reg                                   dedicated_flag;
	reg   `N(`RGBIT)                      dedicated_rs0;	
	
	wire  `N(`INBUF_OFF)                  eval_start              `N(`FETCH_LEN+1);
    wire                                  following_bypass        `N(`FETCH_LEN+1);

	wire  `N(`FETCH_LEN)                  eval_vld; 
	wire  `N(`FETCH_LEN*`XLEN)            eval_instr;
	wire  `N(`FETCH_LEN*`XLEN)            eval_pc;
	wire  `N(`FETCH_LEN*`EXEC_PARA_LEN)   eval_para;
    wire  `N(`FETCH_LEN*`JCBUF_OFF)       eval_level;	
	wire  `N(`FETCH_OFF)                  eval_length             `N(`FETCH_LEN+1);
	wire  `N(`INBUF_OFF)                  eval_offset             `N(`FETCH_LEN+1);	
	
	wire                                  chain_dedicated_flag    `N(`FETCH_LEN+1);
	wire  `N(`RGBIT)                      chain_dedicated_rs0     `N(`FETCH_LEN+1);
	
	wire                                  jcget_vld               `N(`FETCH_LEN+1);
	wire  `N(`XLEN)                       jcget_instr             `N(`FETCH_LEN+1);
	wire  `N(`XLEN)                       jcget_pc                `N(`FETCH_LEN+1);
	wire  `N(`RGBIT)                      jcget_rs0               `N(`FETCH_LEN+1);
	wire  `N(`RGBIT)                      jcget_rs1               `N(`FETCH_LEN+1);
	wire                                  jcget_predict           `N(`FETCH_LEN+1);
	
	wire                                  chain_bnch_initial      `N(`FETCH_LEN+1);
	wire  `N(`XLEN)                       chain_bnch_instr        `N(`FETCH_LEN+1);
	wire  `N(`XLEN)                       chain_bnch_pc           `N(`FETCH_LEN+1);
	wire                                  chain_bnch_jal          `N(`FETCH_LEN+1);	
	
	reg   `N(`INBUF_LEN*`HLEN)            inbuf_bits;
	reg   `N(`INBUF_LEN)                  inbuf_err;
	reg   `N(`INBUF_LEN)                  inbuf_predict;
    reg   `N(`INBUF_OFF)                  inbuf_length;
	reg   `N(`XLEN)                       inbuf_pc;	
	
    reg   `N(`JCBUF_LEN*`XLEN)            jcbuf_instr;
	reg   `N(`JCBUF_LEN*`XLEN)            jcbuf_pc;
	reg   `N(`JCBUF_LEN*`RGBIT)           jcbuf_rs0;
	reg   `N(`JCBUF_LEN*`RGBIT)           jcbuf_rs1;
	reg   `N(`JCBUF_LEN)                  jcbuf_predict;
	reg   `N(`JCBUF_OFF)                  jcbuf_length;

    genvar i,j;
    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------

    //---------------------------------------------------------------------------
	//prepare incoming data, to either buffer: inbuf( main buffer), bkbuf( alter buffer)
	//---------------------------------------------------------------------------

    //to remove redundant part of line_data
	`FFx(instr_offset,0)
	if ( jump_vld )
	    instr_offset <= jump_pc[`BUS_OFF:1];
	else if ( branch_vld )
	    instr_offset <= branch_pc[`BUS_OFF:1];
	else if ( instr_vld )
	    instr_offset <= 0;
	else;
 	
    wire `N(`BUS_WID)                     imem_data = instr_vld ? ( instr_data>>(instr_offset*`HLEN) ) : 0; 	
	wire `N(2*`BUS_LEN)                    imem_err = instr_vld ? ( { (2*`BUS_LEN){instr_err} }>>instr_offset ) : 0;
	wire `N(2*`BUS_LEN)                imem_predict = instr_vld ? ( instr_predict>>instr_offset ) : 0;
    wire `N(`BUS_OFF+1)                 imem_length = instr_vld ? ( (2*`BUS_LEN) - instr_offset ) : 0;	


    //---------------------------------------------------------------------------
	//inbuf evaluation
	//---------------------------------------------------------------------------

    wire                           leading_is_empty = pipeline_is_empty & fetch_is_empty;
	wire `N(`RGLEN)                  leading_rdlist = (pipeline_level_rdlist | fetch_level_rdlist) & `LASTBIT_MASK;
	wire                           no_cond_assuming = ( jcbuf_length==0 );
	
    wire `N(`INBUF_LEN*`HLEN)            inall_bits = inbuf_bits|(imem_data<<(inbuf_length*`HLEN));
    wire `N(`INBUF_LEN)                   inall_err = inbuf_err|(imem_err<<inbuf_length);
	wire `N(`INBUF_LEN)               inall_predict = inbuf_predict|(imem_predict<<inbuf_length);
    wire `N(`INBUF_OFF)                inall_length = inbuf_length + imem_length;		

	wire `N(`FETCH_OFF)               eval_capacity = ( sdbuf_left_num>=fetch_length ) ? `FETCH_LEN : (`FETCH_LEN - fetch_length + sdbuf_left_num);
	
    assign                            eval_start[0] = 0;
	assign                      following_bypass[0] = 0;
	assign                           eval_length[0] = 0;
	assign                           eval_offset[0] = 0;
	assign                  chain_dedicated_flag[0] = 0;
	assign                   chain_dedicated_rs0[0] = 0;
	assign                             jcget_vld[0] = jcbuf_length==`JCBUF_LEN;
	assign                           jcget_instr[0] = 0;
	assign                              jcget_pc[0] = 0;
	assign                             jcget_rs0[0] = 0;
	assign                             jcget_rs1[0] = 0;
	assign                         jcget_predict[0] = 0;
	assign                    chain_bnch_initial[0] = 0;
	assign                      chain_bnch_instr[0] = 0;
	assign                         chain_bnch_pc[0] = 0;
	assign                        chain_bnch_jal[0] = 0;


	//rv_para = { err,illegal,sys,fencei,fence,csr,jalr,jal,jcond,(mem|mul),alu,rd,rs1,rs0 };
    generate
	for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_inbuf
	    //basic info
		wire `N(`XLEN)                        instr = inall_bits>>(eval_start[i]*`HLEN);
		assign                      eval_start[i+1] = eval_start[i] + ((instr[1:0]==2'b11) ? 2'b10 : 2'b1);
	    wire                                    vld = (i<eval_capacity)&(eval_start[i+1]<=inall_length);
		wire `N(`XLEN)                           pc = inbuf_pc + (eval_start[i]<<1);
		wire `N(2)                             errs = inall_err>>eval_start[i];
		wire                                    err = (instr[1:0]==2'b11) ? ( |errs ) : errs[0];
		wire `N(2)                         predicts = inall_predict>>eval_start[i];
		wire                                predict = (instr[1:0]==2'b11) ? ( |predicts ) : predicts[0];
		
		//parameter
        wire `N(`FETCH_PARA_LEN)               para = rv_para(instr,err);
		wire `N(`RGBIT)                         rs0 = para;
		wire `N(`RGBIT)                         rs1 = para>>`RGBIT;
		wire `N(`RGBIT)                          rd = para>>(2*`RGBIT);
		wire `N(9)                            point = para>>`EXEC_PARA_LEN;
        wire                                  jcond = point;
		wire                                    jal = point>>1;
		wire                                   jalr = point>>2;
		wire                                    csr = point>>3;
		wire                                  fence = point>>4;
		wire                                    sys = |(point>>5);
		
		//eval output			
		wire                               sys_pass = (i==0) ? ( no_cond_assuming & leading_is_empty ) : 0;
        wire                              jalr_pass = (i==0) ? ( no_cond_assuming & jalr_rs0_valid ) : 0; 		
		wire                                 bypass = sys|( (fence|csr) & ~sys_pass )|jalr|jal|( jcond & (jcget_vld[i]|predict) );	
        wire                                   stay = bypass ? ( (jalr & jalr_pass)|jal ) : 1'b1;
		assign                following_bypass[i+1] = following_bypass[i]|(vld & bypass);		
		assign                          eval_vld[i] = vld & stay & ~following_bypass[i];
		assign            eval_instr[`IDX(i,`XLEN)] = instr;
		assign               eval_pc[`IDX(i,`XLEN)] = pc;
		assign    eval_para[`IDX(i,`EXEC_PARA_LEN)] = para;		
		assign       eval_level[`IDX(i,`JCBUF_OFF)] = (jcbuf_length==`JCBUF_LEN) ? `JCBUF_LEN : (jcbuf_length + jcget_vld[i]);
		assign                     eval_length[i+1] = eval_vld[i] ? (i+1) : eval_length[i];
		assign                     eval_offset[i+1] = eval_vld[i] ? ( eval_start[i+1] ) : eval_offset[i];		
	
	    //dedicated rs0
		assign            chain_dedicated_flag[i+1] = chain_dedicated_flag[i]|( vld & ( csr|jalr ) & ~following_bypass[i] );
		assign             chain_dedicated_rs0[i+1] = ( vld & ( csr|jalr ) & ~following_bypass[i] ) ? rs0 : chain_dedicated_rs0[i];
	
        //jcget output
		wire                            jcget_occur = vld & jcond & ~jcget_vld[i] & ~following_bypass[i];
        assign                       jcget_vld[i+1] = jcget_vld[i]|jcget_occur; 		
	    assign                     jcget_instr[i+1] = jcget_occur ? instr : jcget_instr[i];
		assign                        jcget_pc[i+1] = jcget_occur ? pc : jcget_pc[i];
		assign                       jcget_rs0[i+1] = jcget_occur ? rs0 : jcget_rs0[i];
		assign                       jcget_rs1[i+1] = jcget_occur ? rs1 : jcget_rs1[i];
		assign                   jcget_predict[i+1] = jcget_occur ? predict : jcget_predict[i];	
	
        //branch output
		wire                           branch_occur = vld & (jal|(jcond & ~jcget_vld[i] & predict)) & ~following_bypass[i];
	    assign              chain_bnch_initial[i+1] = chain_bnch_initial[i]|branch_occur;
		assign                chain_bnch_instr[i+1] = branch_occur ? instr : chain_bnch_instr[i];
        assign                   chain_bnch_pc[i+1] = branch_occur ? pc : chain_bnch_pc[i];
		assign                  chain_bnch_jal[i+1] = branch_occur ? jal : chain_bnch_jal[i];
	end
	endgenerate
	
	`FFx(dedicated_flag,0)
	dedicated_flag <= ( csr_vld|jalr_vld ) ? 0 : chain_dedicated_flag[`FETCH_LEN];
		
	`FFx(dedicated_rs0,0)
	dedicated_rs0 <= chain_dedicated_rs0[`FETCH_LEN];
	
	wire                       jalr_rs0_invalid_bit = leading_rdlist>>dedicated_rs0;
	assign                           jalr_rs0_valid = dedicated_flag & ~jalr_rs0_invalid_bit;
	
	assign                                  sys_vld = gen_inbuf[0].vld & gen_inbuf[0].sys & gen_inbuf[0].sys_pass;
	assign                                sys_instr = gen_inbuf[0].instr;
	assign                                   sys_pc = gen_inbuf[0].pc;
	assign                                 sys_para = (gen_inbuf[0].point>>5); 
	
	assign                                  csr_vld = gen_inbuf[0].vld & gen_inbuf[0].csr & gen_inbuf[0].sys_pass;
	assign                                csr_instr = gen_inbuf[0].instr;
	assign                               csr_rd_sel = gen_inbuf[0].rd;
	assign                                   csr_rs = rs0_word;	

	assign                                 jalr_vld = gen_inbuf[0].vld & gen_inbuf[0].jalr & gen_inbuf[0].jalr_pass;
	assign                               jalr_instr = gen_inbuf[0].instr;
	
	wire `N(`INBUF_OFF)                inbuf_offset = eval_offset[`FETCH_LEN];
	
	`FFx(inbuf_bits,0)
	inbuf_bits <= ( jump_vld|branch_vld ) ? 0 : ( inall_bits>>(inbuf_offset*`HLEN) );

    `FFx(inbuf_err,0)
    inbuf_err <= ( jump_vld|branch_vld ) ? 0 : ( inall_err>>inbuf_offset );
	
	`FFx(inbuf_predict,0)
	inbuf_predict <= ( jump_vld|branch_vld ) ? 0 : ( inall_predict>>inbuf_offset );	
	
	`FFx(inbuf_length,0)
	inbuf_length <= ( jump_vld|branch_vld ) ? 0 : ( inall_length - inbuf_offset );
	
	`FFx(inbuf_pc,0)
	inbuf_pc <= jump_vld ? jump_pc : ( branch_vld ? branch_pc : ( inbuf_pc + (inbuf_offset<<1) ) );

    //---------------------------------------------------------------------------
	//jcbuf evaluation
	//---------------------------------------------------------------------------	
	
	wire `N(`XLEN)                       jcin_instr = jcget_instr[`FETCH_LEN];
	wire `N(`XLEN)                          jcin_pc = jcget_pc[`FETCH_LEN];
	wire `N(`RGBIT)                        jcin_rs0 = jcget_rs0[`FETCH_LEN];
	wire `N(`RGBIT)                        jcin_rs1 = jcget_rs1[`FETCH_LEN];
	wire                               jcin_predict = jcget_predict[`FETCH_LEN];
	wire                                jcin_length = jcget_vld[`FETCH_LEN];
	
	wire `N(`JCBUF_LEN*`XLEN)           jcall_instr = jcbuf_instr|( jcin_instr<<(jcbuf_length*`XLEN) );
	wire `N(`JCBUF_LEN*`XLEN)              jcall_pc = jcbuf_pc|( jcin_pc<<(jcbuf_length*`XLEN) );
	wire `N(`JCBUF_LEN*`RGBIT)            jcall_rs0 = jcbuf_rs0|( jcin_rs0<<(jcbuf_length*`RGBIT) );
	wire `N(`JCBUF_LEN*`RGBIT)            jcall_rs1 = jcbuf_rs1|( jcin_rs1<<(jcbuf_length*`RGBIT) );
	wire `N(`JCBUF_LEN)               jcall_predict = jcbuf_predict|( jcin_predict<<jcbuf_length );
	wire `N(`JCBUF_OFF)                jcall_length = ( jcbuf_length==`JCBUF_LEN ) ? `JCBUF_LEN : ( jcbuf_length + jcin_length );
	
	wire `N(`XLEN)                      jcout_instr = jcbuf_instr;
	wire `N(`XLEN)                         jcout_pc = jcbuf_pc;
	wire `N(`RGBIT)                       jcout_rs0 = jcbuf_rs0;
	wire `N(`RGBIT)                       jcout_rs1 = jcbuf_rs1;
	wire                              jcout_predict = jcbuf_predict;
	
	assign                                  rs0_sel = no_cond_assuming ? dedicated_rs0 : jcout_rs0;
    assign                                  rs1_sel = jcout_rs1;
    wire                          jcond_rs0_invalid = leading_rdlist>>jcout_rs0;
    wire                          jcond_rs1_invalid = leading_rdlist>>jcout_rs1;
	wire                           jcond_rs_invalid = jcond_rs0_invalid|jcond_rs1_invalid;
	wire                                jcond_valid = (jcbuf_length!=0) & ~jcond_rs_invalid;
	
	wire `N(4)                           jcond_para = { (jcout_instr[1:0]==2'b11),jcout_instr[14:12] };
	wire                               jcond_result = condition_satisfied(jcond_para,rs0_word,rs1_word);

	wire                             jcond_decrease = jcond_valid & ( jcout_predict==jcond_result ); 
	wire                                jcond_clear = jcond_valid & ( jcout_predict!=jcond_result ); 
	wire `N(`XLEN)                 jcond_clear_true = jcout_pc + jcond_offset(jcout_instr);
	wire `N(`XLEN)                jcond_clear_false = jcout_pc + ( (jcout_instr[1:0]==2'b11) ? 3'h4 : 3'h2 );
	wire `N(`XLEN)                   jcond_clear_pc = jcond_result ? jcond_clear_true : jcond_clear_false; 
	
    assign                           level_decrease = jcond_decrease;
    assign                              level_clear = jcond_clear;

	`FFx(jcbuf_instr,0)
	jcbuf_instr <= ( jump_vld|level_clear ) ? 0 : ( jcall_instr>>(jcond_valid*`XLEN) );
	
	`FFx(jcbuf_pc,0)
	jcbuf_pc <= ( jump_vld|level_clear ) ? 0 : ( jcall_pc>>(jcond_valid*`XLEN) );
	
	`FFx(jcbuf_rs0,0)
	jcbuf_rs0 <= ( jump_vld|level_clear ) ? 0 : ( jcall_rs0>>(jcond_valid*`RGBIT) );
	
	`FFx(jcbuf_rs1,0)
	jcbuf_rs1 <= ( jump_vld|level_clear ) ? 0 : ( jcall_rs1>>(jcond_valid*`RGBIT) );	
	
    `FFx(jcbuf_predict,0)
	jcbuf_predict <=  ( jump_vld|level_clear ) ? 0 : ( jcall_predict>>jcond_valid );
	
	`FFx(jcbuf_length,0)
	jcbuf_length <=  ( jump_vld|level_clear ) ? 0 : ( jcall_length - jcond_valid );
	
  
	assign                                jcond_vld = jcond_valid;
	assign                                 jcond_pc = jcout_pc;
	assign                                jcond_hit = ( jcout_predict==jcond_result );
	assign                          jcond_satisfied = jcond_result;	
	
    //---------------------------------------------------------------------------
	//fetch preparation
	//---------------------------------------------------------------------------	

`ifdef FETCH_REGISTERED
	reg  `N(`FETCH_LEN)                 dump_vld;
    reg  `N(`FETCH_LEN*`XLEN)           dump_instr;
	reg  `N(`FETCH_LEN*`XLEN)           dump_pc;
    reg  `N(`FETCH_LEN*`EXEC_PARA_LEN)  dump_para;
	reg  `N(`FETCH_LEN*`JCBUF_OFF)      dump_level;
	reg  `N(`FETCH_LEN*`RGLEN)          dump_level_rdlist;
	reg  `N(`FETCH_OFF)                 dump_length;
	
	wire `N(`FETCH_OFF)                  dump_drop_offset = ( sdbuf_left_num>=dump_length ) ? dump_length : sdbuf_left_num;
	wire `N(`FETCH_OFF)                  dump_left_offset = ( sdbuf_left_num>=dump_length ) ? 0 : ( dump_length - sdbuf_left_num );
	
	wire `N(`FETCH_LEN)                        dumpin_vld = ( dump_vld>>dump_drop_offset )|(eval_vld<<dump_left_offset);     
	wire `N(`FETCH_LEN*`XLEN)                dumpin_instr = ( dump_instr>>(dump_drop_offset*`XLEN) )|( eval_instr<<(dump_left_offset*`XLEN) );
	wire `N(`FETCH_LEN*`XLEN)                   dumpin_pc = ( dump_pc>>(dump_drop_offset*`XLEN) )|( eval_pc<<(dump_left_offset*`XLEN) );
	wire `N(`FETCH_LEN*`EXEC_PARA_LEN)        dumpin_para = ( dump_para>>(dump_drop_offset*`EXEC_PARA_LEN) )|( eval_para<<(dump_left_offset*`EXEC_PARA_LEN) );
	wire `N(`FETCH_LEN*`JCBUF_OFF)           dumpin_level = ( dump_level>>(dump_drop_offset*`JCBUF_OFF) )|( eval_level<<(dump_left_offset*`JCBUF_OFF) );
	wire `N(`FETCH_OFF)                     dumpin_length = dump_left_offset + eval_length[`FETCH_LEN];

	
	wire `N(`FETCH_LEN)                 dumpin_vldx;
	wire `N(`FETCH_LEN*`XLEN)           dumpin_instrx;
	wire `N(`FETCH_LEN*`XLEN)           dumpin_pcx;
	wire `N(`FETCH_LEN*`EXEC_PARA_LEN)  dumpin_parax;
	wire `N(`FETCH_LEN*`JCBUF_OFF)      dumpin_levelx;
	wire `N(`FETCH_OFF)                 chain_real_length       `N(`FETCH_LEN+1);
	wire `N(`RGLEN)                     chain_dump_level_rdlist `N(`FETCH_LEN+1);
	
	assign                           chain_real_length[0] = 0;
	assign                     chain_dump_level_rdlist[0] = 0;
	
    generate
    for (i=0;i<`FETCH_LEN;i=i+1) begin:gen_dumpin
	    wire                                          vld = dumpin_vld>>i;
		wire `N(`XLEN)                              instr = dumpin_instr>>(i*`XLEN);
		wire `N(`XLEN)                                 pc = dumpin_pc>>(i*`XLEN);
		wire `N(`EXEC_PARA_LEN)                      para = dumpin_para>>(i*`EXEC_PARA_LEN);
		wire `N(`JCBUF_OFF)                         level = dumpin_level>>(i*`JCBUF_OFF);
		wire `N(`JCBUF_OFF)                        levelx = sub_level(level,level_decrease);
		wire `N(`RGBIT)                                rd = para>>(2*`RGBIT);
        wire                                        clear = level_clear & (level!=0);		
		wire                                         vldx = vld & ~clear;
		wire                                   level_zero = (level==0)|((level==1)&level_decrease);
        assign                             dumpin_vldx[i] = vldx; 		
		assign               dumpin_instrx[`IDX(i,`XLEN)] = vldx ? instr : 0;
		assign                  dumpin_pcx[`IDX(i,`XLEN)] = vldx ? pc : 0;
		assign       dumpin_parax[`IDX(i,`EXEC_PARA_LEN)] = vldx ? para : 0;
        assign          dumpin_levelx[`IDX(i,`JCBUF_OFF)] = vldx ? levelx : 0;
		assign                     chain_real_length[i+1] = vldx ? (i+1) : chain_real_length[i];
		assign               chain_dump_level_rdlist[i+1] = chain_dump_level_rdlist[i]|( (vld&level_zero)<<rd );
    end
    endgenerate		
	
	`FFx(dump_vld,0)
	dump_vld <= jump_vld ? 0 : dumpin_vldx;
	
	`FFx(dump_instr,0)
	dump_instr <= jump_vld ? 0 : dumpin_instrx;
	
	`FFx(dump_pc,0)
	dump_pc <= jump_vld ? 0 : dumpin_pcx;
	
	`FFx(dump_para,0)
	dump_para <= jump_vld ? 0 : dumpin_parax;
	
	`FFx(dump_level,0)
	dump_level <= jump_vld ? 0 : dumpin_levelx;	
	
	`FFx(dump_length,0)
	dump_length <= jump_vld ? 0 : chain_real_length[`FETCH_LEN];	
	
	`FFx(dump_level_rdlist,0)
	dump_level_rdlist <= jump_vld ? 0 : chain_dump_level_rdlist[`FETCH_LEN];
	
	
	assign            fetch_vld = dump_vld;
	assign          fetch_instr = dump_instr;
    assign             fetch_pc = dump_pc;
	assign           fetch_para = dump_para;	
	assign          fetch_level = dump_level;
	assign   fetch_level_rdlist = dump_level_rdlist;
	assign         fetch_length = dump_length;
	assign       fetch_is_empty = ( dump_length==0 );
`else
	assign            fetch_vld = eval_vld;
	assign          fetch_instr = eval_instr;
    assign             fetch_pc = eval_pc;
	assign           fetch_para = eval_para;	
	assign          fetch_level = eval_level;
	assign   fetch_level_rdlist = 0;
	assign         fetch_length = `FETCH_LEN;
	assign       fetch_is_empty = 1;
`endif	
	

    //---------------------------------------------------------------------------
	//branch operation
	//---------------------------------------------------------------------------
	
	wire                  jal_vld = chain_bnch_initial[`FETCH_LEN] &  chain_bnch_jal[`FETCH_LEN];
	wire            jcond_pdt_vld = chain_bnch_initial[`FETCH_LEN] & ~chain_bnch_jal[`FETCH_LEN];
	wire `N(`XLEN)       form0_pc = chain_bnch_pc[`FETCH_LEN] + ( chain_bnch_jal[`FETCH_LEN] ? jal_offset(chain_bnch_instr[`FETCH_LEN]) : jcond_offset(chain_bnch_instr[`FETCH_LEN]) );
    wire `N(`XLEN)       form1_pc = rs0_word + jalr_offset(jalr_instr);	
    
    assign             branch_vld = jcond_clear|jalr_vld|jal_vld|jcond_pdt_vld;
	assign              branch_pc = jcond_clear ? jcond_clear_pc : ( jalr_vld ? form1_pc : form0_pc );
	
	assign            buffer_free = (inall_length - inbuf_offset)<=(`INBUF_LEN-(2*`BUS_LEN));
	
endmodule
