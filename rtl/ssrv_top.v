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
    input                       clk,
	input                       rst,
	
	output                      imem_req,
	output `N(`XLEN)            imem_addr,
	input  `N(`BUS_WID)         imem_rdata,
	input                       imem_resp,
	input                       imem_err,
	
	output                      dmem_req,
	output                      dmem_cmd,
	output `N(2)                dmem_width,
	output `N(`XLEN)            dmem_addr,
	output `N(`XLEN)            dmem_wdata,
	input  `N(`XLEN)            dmem_rdata,
	input                       dmem_resp,
    input                       dmem_err	


);

    //signals of instrman
    wire                                 jump_vld;
    wire `N(`XLEN)                       jump_pc;
    wire                                 line_vld;
    wire `N(`BUS_WID)                    line_data;
    wire                                 line_err;

	//connection for instrbits
	wire                                 buffer_free;
	wire `N(`FETCH_LEN)                  fetch_vld;		
    wire `N(`FETCH_LEN*`XLEN)            fetch_instr;
	wire `N(`FETCH_LEN*`XLEN)            fetch_pc;
	wire `N(`FETCH_LEN)                  fetch_err;
	wire `N(`FETCH_OFF)                  fetch_offset;

    //connection for schedule
	wire `N(`EXEC_LEN)                   exec_vld;
    wire `N(`EXEC_LEN*`XLEN)             exec_instr;
    wire `N((`EXEC_LEN-1)*`EXEC_PARA_LEN+`FETCH_PARA_LEN)   exec_para;
    wire `N(`EXEC_LEN*`XLEN)             exec_pc;
    wire `N(`EXEC_LEN*`MMCMB_OFF)        exec_order;
	wire `N(`XLEN)                       schedule_int_pc;

    //connection for alu
	wire `N(`EXEC_LEN*`RGBIT)            rs0_sel,rs1_sel;
	wire `N(`EXEC_LEN*`XLEN)             rs0_word,rs1_word;
	wire `N(`EXEC_LEN*`RGBIT)            rd_sel;
	wire `N(`EXEC_LEN*`XLEN)             rd_data;
	wire `N(`EXEC_LEN)                   mem_vld;
	wire `N(`EXEC_LEN*`MMBUF_PARA_LEN)   mem_para;
	wire `N(`EXEC_LEN*`XLEN)             mem_addr;
	wire `N(`EXEC_LEN*`XLEN)             mem_wdata;
	wire `N(`FETCH_PARA_LEN-`EXEC_PARA_LEN-3) mem_extra_para;
	wire                                 alujmp_vld;
	wire `N(`XLEN)                       alujmp_pc;	
	
	//connection for mprf
	wire `N(`RFBUF_OFF)                  mprf_rf_num;
	
    //connection for membuf
	wire                                 mem_release;
	wire `N(`RGLEN)                      membuf_rd_list;
	wire `N(`MMBUF_OFF)                  membuf_mem_num;
	wire `N(`RGBIT)                      mem_sel; 
	wire `N(`XLEN)                       mem_data;
	wire                                 sys_vld;
	wire `N(`XLEN)                       sys_instr;
	wire `N(`XLEN)                       sys_pc;
	wire `N(`XLEN)                       csr_rs;
	wire `N(`XLEN)                       csr_data;
	wire `N(`MULBUF_OFF)                 mul_this_order;
	wire                                 mul_vld;
	wire `N(3)                           mul_para;
	wire `N(`XLEN)                       mul_rs0,mul_rs1;
    wire                                 mul_accept;
    wire                                 mul_in_vld;
    wire `N(`XLEN)                       mul_in_data;
    wire `N(`XLEN)                       membuf_int_pc;
    wire                                 dmem_exception;	
  
	//connection for sys_csr
	wire                                 clear_pipeline;
    wire                                 sysjmp_vld;
    wire `N(`XLEN)                       sysjmp_pc;




    instrman i_man(
    .clk                (    clk                 ),
    .rst                (    rst                 ),
   
    .imem_req           (    imem_req            ),
    .imem_addr          (    imem_addr           ),
    .imem_rdata         (    imem_rdata          ),
    .imem_resp          (    imem_resp           ),
	.imem_err           (    imem_err            ),

    .sysjmp_vld         (    sysjmp_vld          ),
    .sysjmp_pc          (    sysjmp_pc           ),
    .alujmp_vld         (    alujmp_vld          ),
    .alujmp_pc          (    alujmp_pc           ),
    
	.buffer_free        (    buffer_free         ),	
	
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           ),
    .line_err           (    line_err            )	

    );

    instrbits i_bits(
    .clk                (    clk                 ),
    .rst                (    rst                 ),   
    
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),	
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           ),
	.line_err           (    line_err            ),

    .buffer_free        (    buffer_free         ),						
    
    .fetch_vld          (    fetch_vld           ),	
    .fetch_instr        (    fetch_instr         ),
    .fetch_pc           (    fetch_pc            ),
    .fetch_err          (    fetch_err           ),
    .fetch_offset       (    fetch_offset        )	

    );                  


    schedule i_sch (
	.clk                (    clk                 ),
	.rst                (    rst                 ),

    .fetch_vld          (    fetch_vld           ),
    .fetch_instr        (    fetch_instr         ),
    .fetch_pc           (    fetch_pc            ),
    .fetch_err          (    fetch_err           ),
    .fetch_offset       (    fetch_offset        ),

    .exec_vld           (    exec_vld            ),
    .exec_instr         (    exec_instr          ),
    .exec_para          (    exec_para           ),
    .exec_pc            (    exec_pc             ),
    .exec_order         (    exec_order          ),	
	
	.membuf_rd_list     (    membuf_rd_list      ),
	.membuf_mem_num     (    membuf_mem_num      ),	
	.mprf_rf_num        (    mprf_rf_num         ),
	
	.mem_release        (    mem_release         ),
	.jump_vld           (    jump_vld            ),
	.jump_pc            (    jump_pc             ),
	.clear_pipeline     (    clear_pipeline      ),
	.schedule_int_pc    (    schedule_int_pc     )
		
	);

	generate
	genvar i;
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_alu
	    if ( i==(`EXEC_LEN-1) ) begin:i_alu_with_jump
	        alu_with_jump i_alu (
	        .clk                (    clk                                  ),
            .rst                (    rst                                  ),
		    
            .vld                (    exec_vld[i]                          ),
            .instr              (    exec_instr[`IDX(i,`XLEN)]            ),
            .para               (    exec_para[(i*`EXEC_PARA_LEN)+:`FETCH_PARA_LEN]   ),
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
            .mem_wdata          (    mem_wdata[`IDX(i,`XLEN)]             ),
			.mem_extra_para     (    mem_extra_para                       ),

            .branch_vld         (    alujmp_vld                           ),
            .branch_pc          (    alujmp_pc                            )		
		    
		    );		
		end else begin:i_alu
	        alu i_alu (
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
	end	
	endgenerate



	mprf i_mprf (
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),

    .mem_release       (    mem_release                         ),	               
	.mem_sel           (    mem_sel                             ),
	.mem_data          (    mem_data                            ),

	.rd_sel            (    rd_sel                              ),
	.rd_order          (    exec_order                          ),
	.rd_data           (    rd_data                             ),
	                     
	.rs0_sel           (    rs0_sel                             ),
	.rs1_sel           (    rs1_sel                             ),
	.rs0_data          (    rs0_word                            ),
	.rs1_data          (    rs1_word                            ),
	
	.clear_pipeline    (    clear_pipeline                      ),
	.mprf_rf_num       (    mprf_rf_num                         )
	
	);

    membuf i_membuf(
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),
                    
	.mem_vld           (    mem_vld                             ),
	.mem_para          (    mem_para                            ),
	.mem_addr          (    mem_addr                            ),
	.mem_wdata         (    mem_wdata                           ),
	.mem_pc            (    exec_pc                             ),
                    
	.mem_release       (    mem_release                         ),
	.membuf_rd_list    (    membuf_rd_list                      ),
	.membuf_mem_num    (    membuf_mem_num                      ),
                     
    .mem_sel           (    mem_sel                             ),
    .mem_data          (    mem_data                            ),
	
	.sys_vld           (    sys_vld                             ),
	.sys_instr         (    sys_instr                           ),
	.sys_pc            (    sys_pc                              ),
	.csr_rs            (    csr_rs                              ),
	.csr_data          (    csr_data                            ),
	
	.mul_this_order    (    mul_this_order                      ),
	.mul_vld           (    mul_vld                             ),
	.mul_para          (    mul_para                            ),
	.mul_rs0           (    mul_rs0                             ),
	.mul_rs1           (    mul_rs1                             ),
	.mul_accept        (    mul_accept                          ),
	.mul_in_vld        (    mul_in_vld                          ),
	.mul_in_data       (    mul_in_data                         ),
	
	.clear_pipeline    (    clear_pipeline                      ),
	.schedule_int_pc   (    schedule_int_pc                     ),
	.membuf_int_pc     (    membuf_int_pc                       ),
	.dmem_exception    (    dmem_exception                      ),
                    
    .dmem_req          (    dmem_req                            ),
    .dmem_cmd          (    dmem_cmd                            ),
    .dmem_width        (    dmem_width                          ),
    .dmem_addr         (    dmem_addr                           ),
    .dmem_wdata        (    dmem_wdata                          ),
    .dmem_rdata        (    dmem_rdata                          ),
    .dmem_resp         (    dmem_resp                           ),
    .dmem_err          (    dmem_err                            )	
	
	);


    mul  i_mul(
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),
	
	.mul_vld           (    mul_vld                             ),
	.mul_para          (    mul_para                            ),
	.mul_rs0           (    mul_rs0                             ),
	.mul_rs1           (    mul_rs1                             ),
	.mul_accept        (    mul_accept                          ),
	
	.clear_pipeline    (    clear_pipeline                      ),
	
	.mul_this_order    (    mul_this_order                      ),
	.mul_in_vld        (    mul_in_vld                          ),
	.mul_in_data       (    mul_in_data                         )
	
    );	

	sys_csr i_sys (	
	.clk               (    clk                                 ),
    .rst               (    rst                                 ),		
	
	.sys_vld           (    sys_vld                             ),
	.sys_instr         (    sys_instr                           ),	
	.sys_pc            (    sys_pc                              ),
	.sys_extra_para    (    mem_extra_para                      ),
	.csr_rs            (    csr_rs                              ),
	.csr_data          (    csr_data                            ),
	

    .dmem_exception    (    dmem_exception                      ),
	.int_pc            (    membuf_int_pc                       ),
	
	.clear_pipeline    (    clear_pipeline                      ),
	
	.jump_vld          (    sysjmp_vld                          ),
	.jump_pc           (    sysjmp_pc                           )
	
	);
	
endmodule