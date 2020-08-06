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
module ssrv_top(
    input                                          clk,
	input                                          rst,
   
	output                                         imem_req,
	output `N(`XLEN)                               imem_addr,
	input  `N(`BUS_WID)                            imem_rdata,
	input                                          imem_resp,
	input                                          imem_err,
  
	output                                         dmem_req,
	output                                         dmem_cmd,
	output `N(2)                                   dmem_width,
	output `N(`XLEN)                               dmem_addr,
	output `N(`XLEN)                               dmem_wdata,
	input  `N(`XLEN)                               dmem_rdata,
	input                                          dmem_resp,
    input                                          dmem_err,

	//interface between SCR1
	output                                         exu2csr_r_req,
	output `N(12)                                  exu2csr_rw_addr,
	input  `N(`XLEN)                               csr2exu_r_data,
	output                                         exu2csr_w_req,
	output `N(2)                                   exu2csr_w_cmd,
	output `N(`XLEN)                               exu2csr_w_data,
	input                                          csr2exu_rw_exc,
	
	input                                          csr2exu_irq,
	output                                         exu2csr_take_irq,
	
	output                                         exu2csr_mret_instr,
	output                                         exu2csr_mret_update,
	
	output                                         exu2csr_take_exc,
	output `N(4)                                   exu2csr_exc_code,
	output `N(`XLEN)                               exu2csr_trap_val,
	
	input  `N(`XLEN)                               csr2exu_new_pc,
	output `N(`XLEN)                               curr_pc, //exc PC
	output `N(`XLEN)                               next_pc  //IRQ PC	


);


    //instrman
    wire                                 jump_vld;
    wire `N(`XLEN)                       jump_pc;
    wire                                 branch_vld;
    wire `N(`XLEN)                       branch_pc;	
	wire                                 buffer_free;	
	
	wire                                 imem_vld;
	wire `N(`BUS_WID)                    imem_instr;
	wire                                 imem_status;

    //predictor
	wire `N(2*`BUS_LEN)                  imem_predict;
	wire                                 jcond_vld;
	wire `N(`XLEN)                       jcond_pc;
	wire                                 jcond_hit;
	wire                                 jcond_taken;

	//connection for instrbits
	wire                                 sys_vld;
	wire `N(`XLEN)                       sys_instr;
	wire `N(`XLEN)                       sys_pc;
	wire `N(4)                           sys_para;
	
	wire                                 csr_vld;
	wire `N(`XLEN)                       csr_instr;
	wire `N(`XLEN)                       csr_rs;
    wire `N(`RGBIT)                      csr_rd_sel;	

    wire `N(`RGBIT)                      extra_rs0_sel;
	wire `N(`RGBIT)                      extra_rs1_sel;
    wire `N(`XLEN)                       extra_rs0_word;
	wire `N(`XLEN)                       extra_rs1_word;	

    wire `N(`SDBUF_OFF)                  sdbuf_left_num;	
	wire `N(`FETCH_LEN)                  fetch_vld;		
    wire `N(`FETCH_LEN*`XLEN)            fetch_instr;
	wire `N(`FETCH_LEN*`XLEN)            fetch_pc;
    wire `N(`FETCH_LEN*`EXEC_PARA_LEN)   fetch_para;
	wire `N(`FETCH_LEN*`JCBUF_OFF)       fetch_level;

	wire `N(`RGLEN)                      pipeline_instr_rdlist;
    wire                                 pipeline_is_empty;
	
	wire                                 level_decrease;
	wire                                 level_clear;	

    //schedule
	wire `N(`EXEC_LEN)                   exec_vld;
    wire `N(`EXEC_LEN*`XLEN)             exec_instr;
    wire `N(`EXEC_LEN*`EXEC_PARA_LEN)    exec_para;
    wire `N(`EXEC_LEN*`XLEN)             exec_pc;
    wire `N(`EXEC_LEN*`MMCMB_OFF)        exec_order;
    wire `N(`EXEC_LEN*`JCBUF_OFF)        exec_level;	

	wire `N(`RGBIT)                      mmbuf_check_rdnum;
	wire `N(`RGLEN)                      mmbuf_check_rdlist;
    wire `N(`RGLEN)                      mmbuf_instr_rdlist;	
	wire `N(`MMBUF_OFF)                  mmbuf_mem_num;	
	wire `N(`RFBUF_OFF)                  rfbuf_alu_num;	
	wire `N(`MEM_OFF)                    mem_release;	
	wire                                 clear_pipeline;	

    //alu
	wire `N(`EXEC_LEN*`RGBIT)            rs0_sel,rs1_sel;
	wire `N(`EXEC_LEN*`XLEN)             rs0_word,rs1_word;
	wire `N(`EXEC_LEN*`RGBIT)            rd_sel;
	wire `N(`EXEC_LEN*`XLEN)             rd_data;	
	wire `N(`EXEC_LEN)                   mem_vld;
	wire `N(`EXEC_LEN*`MMBUF_PARA_LEN)   mem_para;
	wire `N(`EXEC_LEN*`XLEN)             mem_addr;
	wire `N(`EXEC_LEN*`XLEN)             mem_wdata;	
	
	//connection for mprf
	wire `N(`MEM_LEN*`RGBIT)             mem_sel; 
	wire `N(`MEM_LEN*`XLEN)              mem_data;
	wire `N(`XLEN)                       csr_data;
	wire `N(`RGLEN)                      rfbuf_order_list;
	
    //connection for membuf
	wire `N(`MUL_LEN)                    mul_initial;
	wire `N(`MUL_LEN*3)                  mul_para;
	wire `N(`MUL_LEN*`XLEN)              mul_rs0,mul_rs1;
    wire `N(`MUL_LEN)                    mul_ready;
	wire `N(`MUL_LEN)                    mul_finished;    
	wire `N(`MUL_LEN*`XLEN)              mul_data;
    wire `N(`MUL_LEN)                    mul_ack;
	
    wire                                 lsu_initial;
	wire `N(`MMBUF_PARA_LEN)             lsu_para;
	wire `N(`XLEN)                       lsu_addr;
	wire `N(`XLEN)                       lsu_wdata;
	wire                                 lsu_ready;
	wire                                 lsu_finished;
	wire                                 lsu_status;
	wire `N(`XLEN)                       lsu_rdata;
    wire                                 lsu_ack;	

  
	//connection for sys_csr
    wire `N(`XLEN)                       mmbuf_int_pc;
    wire `N(2)                           dmem_exception;		
    wire                                 mem_busy;


	genvar i;


    instrman i_man(
    .clk                        (    clk                      ),
    .rst                        (    rst                      ),
   
    .imem_req                   (    imem_req                 ),
    .imem_addr                  (    imem_addr                ),
    .imem_resp                  (    imem_resp                ),
	.imem_rdata                 (    imem_rdata               ),
	.imem_err                   (    imem_err                 ),

    .jump_vld                   (    jump_vld                 ),
    .jump_pc                    (    jump_pc                  ),
	.branch_vld                 (    branch_vld               ),
	.branch_pc                  (    branch_pc                ),
	.buffer_free                (    buffer_free              ),
	
	.imem_vld                   (    imem_vld                 ),
	.imem_instr                 (    imem_instr               ),
	.imem_status                (    imem_status              )

    );
	
    predictor i_pdt(
    .clk                        (    clk                      ),
    .rst                        (    rst                      ), 
	
    .imem_req                   (    imem_req                 ),
    .imem_addr                  (    imem_addr                ),
    .imem_predict               (    imem_predict             ),

    .jcond_vld                  (    jcond_vld                ),
    .jcond_pc                   (    jcond_pc                 ),
    .jcond_hit                  (    jcond_hit                ),
    .jcond_taken                (    jcond_taken              )	

    );	
	
	
    instrbits i_bits(
    .clk                        (    clk                      ),
    .rst                        (    rst                      ), 

    .jump_vld                   (    jump_vld                 ),
    .jump_pc                    (    jump_pc                  ),
    .branch_vld                 (    branch_vld               ),
    .branch_pc                  (    branch_pc                ),
    .buffer_free                (    buffer_free              ),	

    .instr_vld                  (    imem_vld                 ),
    .instr_data                 (    imem_instr               ),
	.instr_err                  (    imem_status              ),
	.instr_predict              (    imem_predict             ),	

    .jcond_vld                  (    jcond_vld                ),
    .jcond_pc                   (    jcond_pc                 ),
    .jcond_hit                  (    jcond_hit                ),
    .jcond_taken                (    jcond_taken              ),	

    .sys_vld                    (    sys_vld                  ),
    .sys_instr                  (    sys_instr                ),
    .sys_pc                     (    sys_pc                   ),
    .sys_para                   (    sys_para                 ),	
	
	.csr_vld                    (    csr_vld                  ),
	.csr_instr                  (    csr_instr                ),
	.csr_rs                     (    csr_rs                   ),
	.csr_rd_sel                 (    csr_rd_sel               ),

    .rs0_sel                    (    extra_rs0_sel            ),
    .rs1_sel                    (    extra_rs1_sel            ),
    .rs0_word                   (    extra_rs0_word           ),
    .rs1_word                   (    extra_rs1_word           ),	

	.sdbuf_left_num             (    sdbuf_left_num           ),
    .fetch_vld                  (    fetch_vld                ),	
    .fetch_instr                (    fetch_instr              ),
    .fetch_pc                   (    fetch_pc                 ),
    .fetch_para                 (    fetch_para               ),
    .fetch_level                (    fetch_level              ),

	.pipeline_instr_rdlist      (    pipeline_instr_rdlist    ),
	.pipeline_is_empty          (    pipeline_is_empty        ),
	
    .level_decrease             (    level_decrease           ),
    .level_clear                (    level_clear              )	

    );                  

    schedule i_sch (
	.clk                        (    clk                      ),
	.rst                        (    rst                      ),

	.sdbuf_left_num             (    sdbuf_left_num           ),
    .fetch_vld                  (    fetch_vld                ),
    .fetch_instr                (    fetch_instr              ),
    .fetch_pc                   (    fetch_pc                 ),
    .fetch_para                 (    fetch_para               ),
	.fetch_level                (    fetch_level              ),

    .exec_vld                   (    exec_vld                 ),
    .exec_instr                 (    exec_instr               ),
    .exec_para                  (    exec_para                ),
    .exec_pc                    (    exec_pc                  ),
    .exec_level                 (    exec_level               ),
    .exec_order                 (    exec_order               ),
	
    .mmbuf_check_rdnum          (    mmbuf_check_rdnum        ),	
    .mmbuf_check_rdlist         (    mmbuf_check_rdlist       ),
	.mmbuf_instr_rdlist         (    mmbuf_instr_rdlist       ),
	.mmbuf_mem_num              (    mmbuf_mem_num            ),	
	.rfbuf_alu_num              (    rfbuf_alu_num            ),
	.mem_release                (    mem_release              ),
	.clear_pipeline             (    clear_pipeline           ),
	.level_decrease             (    level_decrease           ),
	.level_clear                (    level_clear              ),	
    .pipeline_instr_rdlist      (    pipeline_instr_rdlist    ),
	.pipeline_is_empty          (    pipeline_is_empty        ),
	.schd_intflag               (                             ),
    .schd_intpc                 (                             )	

	);

	generate
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_alu
	        alu  i_alu (
	        .clk                (    clk                                  ),
            .rst                (    rst                                  ),
		    
            .vld                (    exec_vld[i]                          ),
            .instr              (    exec_instr[`IDX(i,`XLEN)]            ),
            .para               (    exec_para[`IDX(i,`EXEC_PARA_LEN)]    ),
            .pc                 (    exec_pc[`IDX(i,`XLEN)]               ),
		    
            .rs0_sel            (    rs0_sel[`IDX(i,`RGBIT)]              ),
            .rs1_sel            (    rs1_sel[`IDX(i,`RGBIT)]              ),
            .rs0_word           (    rs0_word[`IDX(i,`XLEN)]              ),
            .rs1_word           (    rs1_word[`IDX(i,`XLEN)]              ),
		    
            .rd_sel             (    rd_sel[`IDX(i,`RGBIT)]               ),
            .rd_data            (    rd_data[`IDX(i,`XLEN)]               ),

            .mem_vld            (    mem_vld[i]                           ),
            .mem_para           (    mem_para[`IDX(i,`MMBUF_PARA_LEN)]    ),
            .mem_addr           (    mem_addr[`IDX(i,`XLEN)]              ),
            .mem_wdata          (    mem_wdata[`IDX(i,`XLEN)]             )		
		    
		    );
	end	
	endgenerate


	mprf i_mprf (
	.clk                        (    clk                      ),
	.rst                        (    rst                      ),

	.rd_sel                     (    rd_sel                   ),
	.rd_order                   (    exec_order               ),
	.rd_level                   (    exec_level               ),
	.rd_data                    (    rd_data                  ),

	.csr_vld                    (    csr_vld                  ),
	.csr_rd_sel                 (    csr_rd_sel               ),
	.csr_data                   (    csr_data                 ),

	.mem_sel                    (    mem_sel                  ),
	.mem_data                   (    mem_data                 ),	
    .mem_release                (    mem_release              ),	
	
	.clear_pipeline             (    clear_pipeline           ),
	.level_decrease             (    level_decrease           ),
	.level_clear                (    level_clear              ),
 
	.rs0_sel                    (    rs0_sel                  ),
	.rs1_sel                    (    rs1_sel                  ),
	.rs0_word                   (    rs0_word                 ),
	.rs1_word                   (    rs1_word                 ),
	
    .extra_rs0_sel              (    extra_rs0_sel            ),
	.extra_rs1_sel              (    extra_rs1_sel            ),
	.extra_rs0_word             (    extra_rs0_word           ),
	.extra_rs1_word             (    extra_rs1_word           ),
	
	.rfbuf_alu_num              (    rfbuf_alu_num            ),
	.rfbuf_order_list           (    rfbuf_order_list         )
	
	);

    membuf i_membuf(
	.clk                        (    clk                      ),
	.rst                        (    rst                      ),
   
   	.mul_initial                (    mul_initial              ),
	.mul_para                   (    mul_para                 ),
	.mul_rs0                    (    mul_rs0                  ),
	.mul_rs1                    (    mul_rs1                  ),
	.mul_ready                  (    mul_ready                ),
	.mul_finished               (    mul_finished             ),
	.mul_data                   (    mul_data                 ),
	.mul_ack                    (    mul_ack                  ),
	
	.lsu_initial                (    lsu_initial              ),
	.lsu_para                   (    lsu_para                 ),
	.lsu_addr                   (    lsu_addr                 ),
	.lsu_wdata                  (    lsu_wdata                ),
	.lsu_ready                  (    lsu_ready                ),
	.lsu_finished               (    lsu_finished             ),
	.lsu_status                 (    lsu_status               ),
	.lsu_rdata                  (    lsu_rdata                ),
	.lsu_ack                    (    lsu_ack                  ),
   
	.mem_vld                    (    mem_vld                  ),
	.mem_para                   (    mem_para                 ),
	.mem_addr                   (    mem_addr                 ),
	.mem_wdata                  (    mem_wdata                ),
	.mem_pc                     (    exec_pc                  ),
    .mem_level                  (    exec_level               ),
    .mem_sel                    (    mem_sel                  ),
    .mem_data                   (    mem_data                 ),
	.mem_release                (    mem_release              ),
	
	.clear_pipeline             (    clear_pipeline           ),
    .level_decrease             (    level_decrease           ),
    .level_clear                (    level_clear              ),
	.rfbuf_order_list           (    rfbuf_order_list         ),	
    .mmbuf_check_rdnum          (    mmbuf_check_rdnum        ),	
    .mmbuf_check_rdlist         (    mmbuf_check_rdlist       ),
	.mmbuf_instr_rdlist         (    mmbuf_instr_rdlist       ),
	.mmbuf_mem_num              (    mmbuf_mem_num            ),
	.mmbuf_intflag              (                             ),
	.mmbuf_intpc                (                             ),
	.dmem_exception             (    dmem_exception           ),
	.mem_busy                   (    mem_busy                 )
	
	);

    generate
	for (i=0;i<`MUL_LEN;i=i+1) begin:gen_mul
        mul  i_mul(
	    .clk                        (    clk                      ),
	    .rst                        (    rst                      ),
	    
	    .mul_initial                (    mul_initial[i]           ),
	    .mul_para                   (    mul_para[`IDX(i,3)]      ),
	    .mul_rs0                    (    mul_rs0[`IDX(i,`XLEN)]   ),
	    .mul_rs1                    (    mul_rs1[`IDX(i,`XLEN)]   ),
	    .mul_ready                  (    mul_ready[i]             ),
	    
	    .clear_pipeline             (    clear_pipeline           ),
	    
	    .mul_finished               (    mul_finished[i]          ),
	    .mul_data                   (    mul_data[`IDX(i,`XLEN)]  ),
	    .mul_ack                    (    mul_ack[i]               )
	    
        );	
	end
	endgenerate
	

    lsu i_lsu(
	.clk                        (    clk                      ),
	.rst                        (    rst                      ),
    
	.dmem_req                   (    dmem_req                 ),
	.dmem_cmd                   (    dmem_cmd                 ),
	.dmem_width                 (    dmem_width               ),
	.dmem_addr                  (    dmem_addr                ),
	.dmem_wdata                 (    dmem_wdata               ),
	.dmem_rdata                 (    dmem_rdata               ),
	.dmem_resp                  (    dmem_resp                ),
	.dmem_err                   (    dmem_err                 ),
	
	.lsu_initial                (    lsu_initial              ),
	.lsu_para                   (    lsu_para                 ),
	.lsu_addr                   (    lsu_addr                 ),
	.lsu_wdata                  (    lsu_wdata                ),
	.lsu_ready                  (    lsu_ready                ),
	.lsu_finished               (    lsu_finished             ),
	.lsu_status                 (    lsu_status               ),
	.lsu_rdata                  (    lsu_rdata                ),
	.lsu_ack                    (    lsu_ack                  ),
	
	.clear_pipeline             (    clear_pipeline           )		
    );


	sys_csr i_sys (	
	.clk               (    clk                                 ),
    .rst               (    rst                                 ),	
	
	.sys_vld           (    sys_vld                             ),
	.sys_instr         (    sys_instr                           ),	
	.sys_pc            (    sys_pc                              ),
	.sys_para          (    sys_para                            ),
	
	.csr_vld           (    csr_vld                             ),
	.csr_instr         (    csr_instr                           ),
	.csr_rs            (    csr_rs                              ),
	.csr_data          (    csr_data                            ),
	
    .dmem_exception    (    dmem_exception                      ),
	.int_pc            (    32'h0                               ),
	.mem_busy          (    mem_busy                            ),
	
	.clear_pipeline    (    clear_pipeline                      ),
	.jump_vld          (    jump_vld                            ),
	.jump_pc           (    jump_pc                             ),
	
	.exu2csr_r_req     (    exu2csr_r_req                       ),
	.exu2csr_rw_addr   (    exu2csr_rw_addr                     ),
	.csr2exu_r_data    (    csr2exu_r_data                      ),
	.exu2csr_w_req     (    exu2csr_w_req                       ),
	.exu2csr_w_cmd     (    exu2csr_w_cmd                       ),
	.exu2csr_w_data    (    exu2csr_w_data                      ),
	.csr2exu_rw_exc    (    csr2exu_rw_exc                      ),
	
	.csr2exu_irq       (    csr2exu_irq                         ),
    .exu2csr_take_irq  (    exu2csr_take_irq                    ),

    .exu2csr_mret_instr(    exu2csr_mret_instr                  ),
    .exu2csr_mret_update(   exu2csr_mret_update                 ),

    .exu2csr_take_exc  (    exu2csr_take_exc                    ),
    .exu2csr_exc_code  (    exu2csr_exc_code                    ),
    .exu2csr_trap_val  (    exu2csr_trap_val                    ),

    .csr2exu_new_pc    (    csr2exu_new_pc                      ),
    .curr_pc           (    curr_pc                             ),	
	.next_pc           (    next_pc                             )
	
	
	);
	
endmodule