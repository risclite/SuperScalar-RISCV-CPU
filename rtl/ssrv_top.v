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

    //connection for instrman
    wire                               sysjmp_vld;
    wire `N(`XLEN)                     sysjmp_pc;
    wire                               alujmp_vld;
    wire `N(`XLEN)                     alujmp_pc;
    wire                               instr_buf_free;    
    wire                               jump_vld;
    wire `N(`XLEN)                     jump_pc;
    wire                               line_vld;
    wire `N(`BUS_WID)                  line_data;

	//connection for instrbits
    wire `N(`FETCH_OFF)                core_offset;
    wire `N(`FETCH_LEN*`XLEN)          fetch_bits;
	wire `N(`XLEN)                     fetch_pc;
	
	//connection for schedule
    wire                               mem_release;
	wire `N(`EXEC_LEN*`XLEN)           exec_instr;
	wire `N(`EXEC_LEN*`XLEN)           exec_pc;
	
	//connection for alu
	wire `N(`EXEC_LEN*5)               rs0_sel, rs1_sel;
	wire `N(`EXEC_LEN*`XLEN)           rs0_word, rs1_word;
	wire `N(`EXEC_LEN*5)               rg_sel;
	wire `N(`EXEC_LEN*`XLEN)           rg_data;
	wire `N(`EXEC_LEN)                 mem_vld;
	wire `N(`EXEC_LEN*`MEMB_PARA)      mem_para;
	wire `N(`EXEC_LEN*`XLEN)           mem_addr;
	wire `N(`EXEC_LEN*`XLEN)           mem_wdata;
	wire `N(`XLEN)                     csr_data;
	
	//connection for mprf
	wire `N(5)                         mem_sel;
	wire `N(`XLEN)                     mem_data;


    instrman u_man(
	//system signals
    .clk                (    clk                 ),
    .rst                (    rst                 ),
                   
    //from top level				   
    .imem_req           (    imem_req            ),
    .imem_addr          (    imem_addr           ),
    .imem_rdata         (    imem_rdata          ),
    .imem_resp          (    imem_resp           ),
     
	//from sys_csr
    .sysjmp_vld         (    sysjmp_vld          ),
    .sysjmp_pc          (    sysjmp_pc           ),
	
	//from alu
    .alujmp_vld         (    alujmp_vld          ),
    .alujmp_pc          (    alujmp_pc           ),
    
	//from instrbits
	.buffer_free        (    instr_buf_free      ),	
					
    //to instrbits					
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           )                    

    );

    instrbits u_bits(
	//system signals
    .clk                (    clk                 ),
    .rst                (    rst                 ),   
    
    //from instrman
    .jump_vld           (    jump_vld            ),
    .jump_pc            (    jump_pc             ),	
    .line_vld           (    line_vld            ),
    .line_data          (    line_data           ),
    
	//from schedule
    .core_offset        (    core_offset         ),
                        
    //to instrman
    .buffer_free        (    instr_buf_free      ),						
    
    //to schedule	
    .fetch_bits         (    fetch_bits          ),
    .fetch_pc           (    fetch_pc            )         

    );                  


	schedule u_sch(
	//system signals
	.clk                (    clk                 ),
	.rst                (    rst                 ),
	   
    //from membuf	
	.mem_release        (    mem_release         ),
	.mem_sel            (    mem_sel             ),
	
`ifdef REGISTER_EXEC
    .jump_vld           (    jump_vld            ),
`endif
	            
    .fetch_bits         (    fetch_bits          ),
    .fetch_pc           (    fetch_pc            ),

	//to alu
    .exec_instr         (    exec_instr          ),
    .exec_pc            (    exec_pc             ),

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
		     
		    //between mprf  
		    .rs0_sel                 (     rs0_sel[`IDX(i,5)]                ),
		    .rs1_sel                 (     rs1_sel[`IDX(i,5)]                ),
		    .rs0_word                (     rs0_word[`IDX(i,`XLEN)]           ),
		    .rs1_word                (     rs1_word[`IDX(i,`XLEN)]           ),
		    
      	    //to instrman	
		    .jump_vld                (     alujmp_vld                        ),
		    .jump_pc                 (     alujmp_pc                         ),
		    
     	    //to mprf	
		    .rg_sel                  (     rg_sel[`IDX(i,5)]                 ),
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
		     
		    //between mprf  
		    .rs0_sel                 (     rs0_sel[`IDX(i,5)]                ),
		    .rs1_sel                 (     rs1_sel[`IDX(i,5)]                ),
		    .rs0_word                (     rs0_word[`IDX(i,`XLEN)]           ),
		    .rs1_word                (     rs1_word[`IDX(i,`XLEN)]           ),
		    
     	    //to mprf	
		    .rg_sel                  (     rg_sel[`IDX(i,5)]                 ),
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
	
	//from mprf
    .rs0_word           (    rs0_word[`IDX(`EXEC_LEN-1,`XLEN)]    ),
    .rs1_word           (    rs1_word[`IDX(`EXEC_LEN-1,`XLEN)]    ),   
	
	.jump_vld           (    sysjmp_vld                           ),
	.jump_pc            (    sysjmp_pc                            ),
	
	.csr_data           (    csr_data                             )
	
	
	);
	

	mprf u_rf(
	//system signals
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),
	                     
    //from membuf	                     
	.mem_sel           (    mem_sel                             ),
	.mem_data          (    mem_data                            ),
	
    //from alu	
	.rg_sel            (    rg_sel                              ),
	.rg_data           (    rg_data                             ),
	                     
    //between alu	                     
	.rs0_sel           (    rs0_sel                             ),
	.rs1_sel           (    rs1_sel                             ),
	.rs0_data          (    rs0_word                            ),
	.rs1_data          (    rs1_word                            )
	
	);

    membuf u_membuf(
	//system signals
	.clk               (    clk                                 ),
	.rst               (    rst                                 ),
	                     
    //from alu                     
	.mem_vld           (    mem_vld                             ),
	.mem_para          (    mem_para                            ),
	.mem_addr          (    mem_addr                            ),
	.mem_wdata         (    mem_wdata                           ),
	                     
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

	
	
endmodule