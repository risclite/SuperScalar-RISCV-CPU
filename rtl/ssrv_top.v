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
	
	output                      dmem_req,
	output                      dmem_cmd,
	output `N(2)                dmem_width,
	output `N(`XLEN)            dmem_addr,
	output `N(`XLEN)            dmem_wdata,
	input  `N(`XLEN)            dmem_rdata,
	input                       dmem_resp	


);

    //signals of instrman
    wire                               sysjmp_vld;
    wire `N(`XLEN)                     sysjmp_pc;
    wire                               alujmp_vld;
    wire `N(`XLEN)                     alujmp_pc;
    wire                               buffer_free;    
    wire                               jump_vld;
    wire `N(`XLEN)                     jump_pc;
    wire                               line_vld;
    wire `N(`BUS_WID)                  line_data;

	//connection for instrbits
    wire `N(`FETCH_OFF)                core_offset;
    wire `N(`FETCH_LEN*`XLEN)          fetch_instr;
	wire `N(`FETCH_LEN*`XLEN)          fetch_pc;
	wire `N(`FETCH_LEN)                fetch_vld;
	
	//connection for schedule
	wire                               direct_mode;
	wire `N(`EXEC_OFF)                 rf_release;
    wire                               mem_release;
	wire `N(`EXEC_LEN*`XLEN)           exec_instr;
	wire `N(`EXEC_LEN*`XLEN)           exec_pc;
	wire `N(`EXEC_LEN)                 exec_vld;
	wire `N(`EXEC_LEN*`MEMB_OFF)       exec_cnt;
	
	//connection for alu
	wire `N(`EXEC_LEN*`RGBIT)          rs0_sel, rs1_sel;
	wire `N(`EXEC_LEN*`XLEN)           rs0_word, rs1_word;
	wire `N(`EXEC_LEN*`RGBIT)          rg_sel;
	wire `N(`EXEC_LEN*`XLEN)           rg_data;
	wire `N(`EXEC_LEN)                 mem_vld;
	wire `N(`EXEC_LEN*`MEMB_PARA)      mem_para;
	wire `N(`EXEC_LEN*`XLEN)           mem_addr;
	wire `N(`EXEC_LEN*`XLEN)           mem_wdata;
	wire `N(`XLEN)                     csr_data;
	
	//connection for mprf
	wire `N(`RGBIT)                    mem_sel;
	wire `N(`XLEN)                     mem_data;
`ifdef RV32M_SUPPORTED
    wire `N(`RGBIT)                    m2_sel;
	wire `N(`XLEN)                     m2_data;
	wire                               mul_is_busy;
`endif
    wire                               direct_reset;


    instrman u_man(
    .clk                (    clk                 ),
    .rst                (    rst                 ),
   
    .imem_req           (    imem_req            ),
    .imem_addr          (    imem_addr           ),
    .imem_rdata         (    imem_rdata          ),
    .imem_resp          (    imem_resp           ),

    .sysjmp_vld         (    sysjmp_vld          ),
    .sysjmp_pc          (    sysjmp_pc           ),
    .alujmp_vld         (    alujmp_vld          ),
    .alujmp_pc          (    alujmp_pc           ),
    
	.buffer_free        (    buffer_free         ),	
	
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           )                    

    );

    instrbits u_bits(
    .clk                (    clk                 ),
    .rst                (    rst                 ),   
    
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),	
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           ),
    
    .core_offset        (    core_offset         ),

    .buffer_free        (    buffer_free         ),						
    
    .fetch_instr        (    fetch_instr         ),
    .fetch_pc           (    fetch_pc            ),
    .fetch_vld          (    fetch_vld           )	

    );                  


	schedule u_sch(
	//system signals
	.clk                (    clk                 ),
	.rst                (    rst                 ),
	
	//from sys_csr
	.direct_mode        (    direct_mode         ),
	
	//from mprf
	.rf_release         (    rf_release          ),
  
    //from membuf	
	.mem_release        (    mem_release         ),
`ifdef RV32M_SUPPORTED
    .mem_sel            (    m2_sel              ),
	.mul_is_busy        (    mul_is_busy         ),
`else
	.mem_sel            (    mem_sel             ),
`endif	
	
`ifdef REGISTER_EXEC
    .jump_vld           (    jump_vld            ),
`endif

    //from instrbits  
    .fetch_instr        (    fetch_instr         ),
    .fetch_pc           (    fetch_pc            ),
	.fetch_vld          (    fetch_vld           ),

	//to alu
    .exec_instr         (    exec_instr          ),
    .exec_pc            (    exec_pc             ),
	.exec_vld           (    exec_vld            ),
	.exec_cnt           (    exec_cnt            ),

	//to instrbits
    .core_offset        (    core_offset         )	
	
	);
	
	
	
	generate
	genvar i;
	for (i=0;i<`EXEC_LEN;i=i+1) begin:gen_alu
	    if (i==(`EXEC_LEN-1)) begin:gen_last
		    alu_with_jump u_alu_j (
		    //system signals
		    .clk                     (     clk                               ),
		    .rst                     (     rst                               ),
		    
            //from schedule			
		    .instr                   (     exec_instr[`IDX(i,`XLEN)]         ),
		    .pc                      (     exec_pc[`IDX(i,`XLEN)]            ),
			.vld                     (     exec_vld[i]                       ),
		     
		    //between mprf  
		    .rs0_sel                 (     rs0_sel[`IDX(i,`RGBIT)]           ),
		    .rs1_sel                 (     rs1_sel[`IDX(i,`RGBIT)]           ),
		    .rs0_word                (     rs0_word[`IDX(i,`XLEN)]           ),
		    .rs1_word                (     rs1_word[`IDX(i,`XLEN)]           ),
		    
      	    //to instrman	
		    .jump_vld                (     alujmp_vld                        ),
		    .jump_pc                 (     alujmp_pc                         ),
		    
     	    //to mprf	
		    .rg_sel                  (     rg_sel[`IDX(i,`RGBIT)]            ),
		    .rg_data                 (     rg_data[`IDX(i,`XLEN)]            ),
		    
            //to membuf
		    .mem_vld                 (     mem_vld[i]                        ),
		    .mem_para                (     mem_para[`IDX(i,`MEMB_PARA)]      ),
		    .mem_addr                (     mem_addr[`IDX(i,`XLEN)]           ),
		    .mem_wdata               (     mem_wdata[`IDX(i,`XLEN)]          ),
		    
		    //from csrmul 
		    .csr_data                (    csr_data                           )
            );
        end else begin:gen_other
		    alu u_alu (
		    //system signals
		    .clk                     (     clk                               ),
		    .rst                     (     rst                               ),
		    
            //from schedule			
		    .instr                   (     exec_instr[`IDX(i,`XLEN)]         ),
		    .pc                      (     exec_pc[`IDX(i,`XLEN)]            ),
			.vld                     (     exec_vld[i]                       ),
		     
		    //between mprf  
		    .rs0_sel                 (     rs0_sel[`IDX(i,`RGBIT)]           ),
		    .rs1_sel                 (     rs1_sel[`IDX(i,`RGBIT)]           ),
		    .rs0_word                (     rs0_word[`IDX(i,`XLEN)]           ),
		    .rs1_word                (     rs1_word[`IDX(i,`XLEN)]           ),
		    
     	    //to mprf	
		    .rg_sel                  (     rg_sel[`IDX(i,`RGBIT)]            ),
		    .rg_data                 (     rg_data[`IDX(i,`XLEN)]            ),
		    
            //to membuf
		    .mem_vld                 (     mem_vld[i]                        ),
		    .mem_para                (     mem_para[`IDX(i,`MEMB_PARA)]      ),
		    .mem_addr                (     mem_addr[`IDX(i,`XLEN)]           ),
		    .mem_wdata               (     mem_wdata[`IDX(i,`XLEN)]          )
            );
        end		
	end	
	endgenerate

	sys_csr u_sys_csr(
	//system signals	
	.clk                (    clk                                  ),
    .rst                (    rst                                  ),		
	
    //from schedule			
	.instr              (    exec_instr[`IDX(`EXEC_LEN-1,`XLEN)]  ),
	.pc                 (    exec_pc[`IDX(`EXEC_LEN-1,`XLEN)]     ),
	.vld                (    exec_vld[`EXEC_LEN-1]                ),  
	
	//from mprf
    .rs0_word           (    rs0_word[`IDX(`EXEC_LEN-1,`XLEN)]    ),
    .rs1_word           (    rs1_word[`IDX(`EXEC_LEN-1,`XLEN)]    ),   
	
	.jump_vld           (    sysjmp_vld                           ),
	.jump_pc            (    sysjmp_pc                            ),
	
	.direct_mode        (    direct_mode                          ),
	.direct_reset       (    direct_reset                         ),
	
	.csr_data           (    csr_data                             )
	
	
	);
	

	mprf u_rf(
	//system signals
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),

	//from sys_csr
	.direct_mode       (    direct_mode                         ),
	
    //from membuf
    .mem_release       (    mem_release                         ),	
`ifdef RV32M_SUPPORTED	                     
	.mem_sel           (    m2_sel                              ),
	.mem_data          (    m2_data                             ),
`else	                   
	.mem_sel           (    mem_sel                             ),
	.mem_data          (    mem_data                            ),
`endif	
	
    //from alu	
	.rg_sel            (    rg_sel                              ),
	.rg_cnt            (    exec_cnt                            ),
	.rg_data           (    rg_data                             ),

    //between alu	                     
	.rs0_sel           (    rs0_sel                             ),
	.rs1_sel           (    rs1_sel                             ),
	.rs0_data          (    rs0_word                            ),
	.rs1_data          (    rs1_word                            ),
	
	.rf_release        (    rf_release                          )
	
	);

    membuf u_membuf(
	//system signals
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),
	
	//from sys_csr
	.direct_mode       (    direct_mode                         ),
	.direct_reset      (    direct_reset                        ),
 
    //from alu                     
	.mem_vld           (    mem_vld                             ),
	.mem_para          (    mem_para                            ),
	.mem_addr          (    mem_addr                            ),
	.mem_wdata         (    mem_wdata                           ),
	.mem_pc            (    exec_pc                             ),

	//to schedule                     
	.mem_release       (    mem_release                         ),

	//to mprf                     
    .mem_sel           (    mem_sel                             ),
    .mem_data          (    mem_data                            ),

	//to top level                     
    .dmem_req          (    dmem_req                            ),
    .dmem_cmd          (    dmem_cmd                            ),
    .dmem_width        (    dmem_width                          ),
    .dmem_addr         (    dmem_addr                           ),
    .dmem_wdata        (    dmem_wdata                          ),
    .dmem_rdata        (    dmem_rdata                          ),
    .dmem_resp         (    dmem_resp                           )	
	
	);

`ifdef RV32M_SUPPORTED
    mul  u_mul(
	.clk                (   clk                                   ),
    .rst                (   rst                                   ),		
	
    //from schedule			
	.instr              (   exec_instr[`IDX(`EXEC_LEN-1,`XLEN)]   ),
	.pc                 (   exec_pc[`IDX(`EXEC_LEN-1,`XLEN)]      ),
	.vld                (   exec_vld[`EXEC_LEN-1]                 ), 
    .cnt                (   exec_cnt[`IDX(`EXEC_LEN-1,`MEMB_OFF)] ),	
	
	//from mprf
    .rs0_word           (   rs0_word[`IDX(`EXEC_LEN-1,`XLEN)]     ),
    .rs1_word           (   rs1_word[`IDX(`EXEC_LEN-1,`XLEN)]     ),   

	//to mprf  
    .mem_release       (    mem_release                           ),	
    .mem_sel           (    mem_sel                               ),
    .mem_data          (    mem_data                              ),

    //to schedule
    .mul_is_busy       (    mul_is_busy                           ),

	//to mprf
	.m2_sel            (    m2_sel                                ),
	.m2_data           (    m2_data                               )
	
    );	
`endif	
endmodule