
`include "scr1_arch_description.svh"
`include "scr1_memif.svh"
`include "scr1_riscv_isa_decoding.svh"
`include "scr1_csr.svh"

`ifdef SCR1_IPIC_EN
`include "scr1_ipic.svh"
`endif // SCR1_IPIC_EN

`ifdef SCR1_DBGC_EN
`include "scr1_hdu.svh"
`endif // SCR1_DBGC_EN

`ifdef SCR1_BRKM_EN
`include "scr1_tdu.svh"
`endif // SCR1_BRKM_EN

`include "define.v"

module ssrv_pipe_top (
    // Common
    input   logic                                       pipe_rst_n,
    input   logic                                       clk,    

    // Instruction Memory Interface
    output  logic                                       imem_req,
    output  type_scr1_mem_cmd_e                         imem_cmd,
    output  logic [`SCR1_IMEM_AWIDTH-1:0]               imem_addr,
    input   logic                                       imem_req_ack,
    input   logic [`SCR1_IMEM_DWIDTH-1:0]               imem_rdata,
    input   type_scr1_mem_resp_e                        imem_resp,

    // Data Memory Interface
    output  logic                                       dmem_req,
    output  type_scr1_mem_cmd_e                         dmem_cmd,
    output  type_scr1_mem_width_e                       dmem_width,
    output  logic [`SCR1_DMEM_AWIDTH-1:0]               dmem_addr,
    output  logic [`SCR1_DMEM_DWIDTH-1:0]               dmem_wdata,
    input   logic                                       dmem_req_ack,
    input   logic [`SCR1_DMEM_DWIDTH-1:0]               dmem_rdata,
    input   type_scr1_mem_resp_e                        dmem_resp,


    // IRQ
`ifdef SCR1_IPIC_EN
    input   logic [SCR1_IRQ_LINES_NUM-1:0]              irq_lines,
`else // SCR1_IPIC_EN
    input   logic                                       ext_irq,
`endif // SCR1_IPIC_EN
    input   logic                                       soft_irq,

    // Memory-mapped external timer
    input   logic                                       timer_irq,
    input   logic [63:0]                                mtime_ext,


    // Fuse
    input   logic [`SCR1_XLEN-1:0]                      fuse_mhartid


);

    //memory
    wire rst = ~pipe_rst_n;
	
	assign imem_cmd = SCR1_MEM_CMD_RD;
	
	wire imem_resp_line = (imem_resp==SCR1_MEM_RESP_RDY_OK)|(imem_resp==SCR1_MEM_RESP_RDY_ER);

    wire imem_err = (imem_resp==SCR1_MEM_RESP_RDY_ER);
	
	wire dmem_cmd_line;
	
	assign dmem_cmd = dmem_cmd_line ? SCR1_MEM_CMD_WR : SCR1_MEM_CMD_RD; 
	
	wire `N(2) dmem_width_line;
	
	assign dmem_width = ( dmem_width_line==2'b10 ) ? SCR1_MEM_WIDTH_WORD  : (
	                    ( dmem_width_line==2'b01 ) ? SCR1_MEM_WIDTH_HWORD :
						                             SCR1_MEM_WIDTH_BYTE
	);

	wire dmem_resp_line = (dmem_resp==SCR1_MEM_RESP_RDY_OK)|(dmem_resp==SCR1_MEM_RESP_RDY_ER);

    wire dmem_err = (dmem_resp==SCR1_MEM_RESP_RDY_ER);

    //csr
	wire           exu2csr_r_req;
	wire `N(12)    exu2csr_rw_addr;
    wire `N(`XLEN) csr2exu_r_data;
	wire           exu2csr_w_req;
	wire `N(2)     exu2csr_w_cmd;
	wire `N(`XLEN) exu2csr_w_data;
	wire           csr2exu_rw_exc;
	
	wire           csr2exu_irq;
	wire           exu2csr_take_irq;
	
	wire           exu2csr_mret_instr;
	wire           exu2csr_mret_update;

	wire           exu2csr_take_exc;
	wire `N(4)     exu2csr_exc_code;
	wire `N(`XLEN) exu2csr_trap_val;
    
	wire `N(`XLEN) csr2exu_new_pc;
	wire `N(`XLEN) curr_pc; //exc PC
	wire `N(`XLEN) next_pc; //IRQ PC		

    ssrv_top i_ssrv(
	    .clk                               (    clk                        ),
        .rst                               (    rst                        ),

        .imem_req                          (    imem_req                   ),	
        .imem_addr                         (    imem_addr                  ),
        .imem_rdata                        (    imem_rdata                 ),		
	    .imem_resp                         (    imem_resp_line             ),
		.imem_err                          (    imem_err                   ),
		
		.dmem_req                          (    dmem_req                   ),
		.dmem_cmd                          (    dmem_cmd_line              ),
		.dmem_width                        (    dmem_width_line            ),
		.dmem_addr                         (    dmem_addr                  ),
		.dmem_wdata                        (    dmem_wdata                 ),
		.dmem_rdata                        (    dmem_rdata                 ),
		.dmem_resp                         (    dmem_resp_line             ),
		.dmem_err                          (    dmem_err                   ),
		
        .exu2csr_r_req                     (    exu2csr_r_req              ),
        .exu2csr_rw_addr                   (    exu2csr_rw_addr            ),
        .csr2exu_r_data                    (    csr2exu_r_data             ),
        .exu2csr_w_req                     (    exu2csr_w_req              ),
        .exu2csr_w_cmd                     (    exu2csr_w_cmd              ),
        .exu2csr_w_data                    (    exu2csr_w_data             ),
        .csr2exu_rw_exc                    (    csr2exu_rw_exc             ),

	    .csr2exu_irq                       (    csr2exu_irq                ),
        .exu2csr_take_irq                  (    exu2csr_take_irq           ),
  
        .exu2csr_mret_instr                (    exu2csr_mret_instr         ),
        .exu2csr_mret_update               (    exu2csr_mret_update        ),
  
        .exu2csr_take_exc                  (    exu2csr_take_exc           ),
        .exu2csr_exc_code                  (    exu2csr_exc_code           ),
        .exu2csr_trap_val                  (    exu2csr_trap_val           ),
   
        .csr2exu_new_pc                    (    csr2exu_new_pc             ),
        .curr_pc                           (    curr_pc                    ),	
	    .next_pc                           (    next_pc                    )		
	
	);

    type_scr1_csr_cmd_sel_e                     exu2csr_w_cmd_scr1;  
    
	assign exu2csr_w_cmd_scr1 = ( exu2csr_w_cmd==2'h3 ) ? SCR1_CSR_CMD_CLEAR : (
	                            ( exu2csr_w_cmd==2'h2 ) ? SCR1_CSR_CMD_SET   : (
								( exu2csr_w_cmd==2'h1 ) ? SCR1_CSR_CMD_WRITE :
								                          SCR1_CSR_CMD_NONE )
								);

    type_scr1_exc_code_e                        exu2csr_exc_code_scr1; 

    assign exu2csr_exc_code_scr1 = ( exu2csr_exc_code==4'h7 ) ? SCR1_EXC_CODE_ST_ACCESS_FAULT : (
	                               ( exu2csr_exc_code==4'h5 ) ? SCR1_EXC_CODE_LD_ACCESS_FAULT : (
								   ( exu2csr_exc_code==4'h2 ) ? SCR1_EXC_CODE_ILLEGAL_INSTR   : (
								   ( exu2csr_exc_code==4'h1 ) ? SCR1_EXC_CODE_INSTR_ACCESS_FAULT : 
								                                SCR1_EXC_CODE_ECALL_M
									)
									)
									);
	
	wire    csr2exu_ip_ie;
	wire    csr2exu_mstatus_mie_up;
	wire    instret_nexc = 1;

    scr1_pipe_csr i_pipe_csr (
        .rst_n                  (pipe_rst_n         ),
        .clk                    (clk                ),
    `ifdef SCR1_CLKCTRL_EN
        .clk_alw_on             (clk_alw_on         ),
    `endif // SCR1_CLKCTRL_EN
    
        .exu2csr_r_req          (exu2csr_r_req      ),
        .exu2csr_rw_addr        (exu2csr_rw_addr    ),
        .csr2exu_r_data         (csr2exu_r_data     ),
        .exu2csr_w_req          (exu2csr_w_req      ),
        .exu2csr_w_cmd          (exu2csr_w_cmd_scr1 ),
        .exu2csr_w_data         (exu2csr_w_data     ),
        .csr2exu_rw_exc         (csr2exu_rw_exc     ),
    
        .exu2csr_take_irq       (exu2csr_take_irq   ),
        .exu2csr_take_exc       (exu2csr_take_exc   ),
        .exu2csr_mret_update    (exu2csr_mret_update),
        .exu2csr_mret_instr     (exu2csr_mret_instr ),
    `ifdef SCR1_DBGC_EN
        .exu_no_commit          (exu_no_commit      ),
    `endif // SCR1_DBGC_EN
        .exu2csr_exc_code       (exu2csr_exc_code_scr1 ),
        .exu2csr_trap_val       (exu2csr_trap_val   ),
        .csr2exu_new_pc         (csr2exu_new_pc     ),
        .csr2exu_irq            (csr2exu_irq        ),
        .csr2exu_ip_ie          (csr2exu_ip_ie      ),
        .csr2exu_mstatus_mie_up (csr2exu_mstatus_mie_up),
    `ifdef SCR1_IPIC_EN
        .csr2ipic_r_req         (csr2ipic_r_req     ),
        .csr2ipic_w_req         (csr2ipic_w_req     ),
        .csr2ipic_addr          (csr2ipic_addr      ),
        .csr2ipic_wdata         (csr2ipic_wdata     ),
        .ipic2csr_rdata         (ipic2csr_rdata     ),
    `endif // SCR1_IPIC_EN
        .curr_pc                (curr_pc            ),
        .next_pc                (next_pc            ),
    `ifndef SCR1_CSR_REDUCED_CNT
        .instret_nexc           (instret_nexc       ),
    `endif // SCR1_CSR_REDUCED_CNT
        .ext_irq                (ext_irq            ),
        .soft_irq               (soft_irq           ),
        .timer_irq              (timer_irq          ),
        .mtime_ext              (mtime_ext          ),
    `ifdef SCR1_DBGC_EN
        // CSR <-> HDU interface
        .csr2hdu_req            (csr2hdu_req        ),
        .csr2hdu_cmd            (csr2hdu_cmd        ),
        .csr2hdu_addr           (csr2hdu_addr       ),
        .csr2hdu_wdata          (csr2hdu_wdata      ),
        .hdu2csr_rdata          (hdu2csr_rdata      ),
        .hdu2csr_resp           (hdu2csr_resp       ),
    `endif // SCR1_DBGC_EN
    `ifdef SCR1_BRKM_EN
        .csr2tdu_req            (csr2tdu_req       ),
        .csr2tdu_cmd            (csr2tdu_cmd       ),
        .csr2tdu_addr           (csr2tdu_addr      ),
        .csr2tdu_wdata          (csr2tdu_wdata     ),
        .tdu2csr_rdata          (tdu2csr_rdata     ),
        .tdu2csr_resp           (tdu2csr_resp      ),
    `endif // SCR1_BRKM_EN
        .fuse_mhartid           (fuse_mhartid       )
    );





endmodule
