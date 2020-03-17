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
`include "scr1_memif.svh"

`define CORE_FIELD scr1_top_tb_ahb.i_top.i_core_top

module tb_ssrv;


    wire clk;  
    wire rst;
    
    wire            imem_req;
    wire `N(`XLEN)  imem_addr;
	wire            dmem_req;
    wire            dmem_cmd;
    wire `N(2)      dmem_width;
    wire `N(`XLEN)  dmem_addr;
    wire `N(`XLEN)  dmem_wdata;
    
    `COMB begin
`ifdef USE_SSRV
	    force `CORE_FIELD.i_pipe_top.pipe_rst_n = 1'b0;
		force  clk                       = `CORE_FIELD.clk;
		force  rst                       = ~`CORE_FIELD.core_rst_n;
	    force `CORE_FIELD.imem_req       = imem_req;
		force `CORE_FIELD.imem_addr      = imem_addr;
        force `CORE_FIELD.dmem_req       = dmem_req;
		force `CORE_FIELD.dmem_cmd       = dmem_cmd ? SCR1_MEM_CMD_WR : SCR1_MEM_CMD_RD;
		force `CORE_FIELD.dmem_width     = (dmem_width==2'b10) ? SCR1_MEM_WIDTH_WORD : ( (dmem_width==2'b01) ? SCR1_MEM_WIDTH_HWORD : SCR1_MEM_WIDTH_BYTE );
		force `CORE_FIELD.dmem_addr      = dmem_addr;
		force `CORE_FIELD.dmem_wdata     = dmem_wdata;
`else
        force clk                        = 1'b0;
		force rst                        = 1'b1;
`endif
    end	
	
		
`ifdef WIDE_INSTR_BUS
    reg `N(`XLEN)   wide_addr;
	`FFx(wide_addr,0)
	if ( imem_req )
	    wide_addr <= imem_addr;
	else;
	
    reg `N(`BUS_LEN*`XLEN) imem_rdata;
    `COMB begin:comb_imem_rdata
        integer n;
    	integer t;
    	imem_rdata = 0;
    	for(n=0;n<`BUS_LEN*4;n=n+1) begin
    	    t = scr1_top_tb_ahb.i_memory_tb.memory[wide_addr+n]; 
    	    imem_rdata[`IDX(n,8)] = (t===8'hxx) ? 8'h0 : t;
    	end
    end	
`else
    wire `N(`XLEN) imem_rdata = `CORE_FIELD.imem_rdata;
`endif	
	
	wire           imem_resp  = (`CORE_FIELD.imem_resp==SCR1_MEM_RESP_RDY_OK) ? 1'b1 : 1'b0;
	wire `N(`XLEN) dmem_rdata = `CORE_FIELD.dmem_rdata;
	wire           dmem_resp  = (`CORE_FIELD.dmem_resp==SCR1_MEM_RESP_RDY_OK) ? 1'b1 : 1'b0;


    ssrv_top u_ssrv(
        .clk                    (clk                ),
    	.rst                    (rst                ),
        // instruction memory interface	
        .imem_req               (imem_req           ),
        .imem_addr              (imem_addr          ),
        .imem_rdata             (imem_rdata         ),
        .imem_resp              (imem_resp          ),
		.imem_err               (1'b0               ),
        // Data memory interface
        .dmem_req               (dmem_req           ),
        .dmem_cmd               (dmem_cmd           ),
        .dmem_width             (dmem_width         ),
        .dmem_addr              (dmem_addr          ),
        .dmem_wdata             (dmem_wdata         ),
        .dmem_rdata             (dmem_rdata         ),
        .dmem_resp              (dmem_resp          ),
        .dmem_err               (1'b0               )		
    
    );
	
`ifdef BENCHMARK_LOG	
    reg     log_start = 0;
    reg     log_finish = 0;
    integer instr_num = 0;
    integer tick_num = 0;
	integer jtrue_num = 0;
	integer jfalse_num = 0;						
	integer mem_num = 0;
    integer each_num `N(`EXEC_LEN+1);
	
    function `N(`EXEC_OFF) all_of_it(input `N(`EXEC_LEN) vld);
    integer i;
    begin
        all_of_it = 0;
        for (i=0;i<`EXEC_LEN;i=i+1)
    	    all_of_it = all_of_it + vld[i];
    end
    endfunction 
  
    always @ ( posedge clk )
    if ( log_start ) begin
        tick_num <= tick_num + 1'b1;
    	instr_num <= instr_num + all_of_it(u_ssrv.exec_vld);
		jtrue_num <= jtrue_num + u_ssrv.level_decrease;
		jfalse_num <= jfalse_num + u_ssrv.level_clear;												
		mem_num <= mem_num + u_ssrv.dmem_req;
    	each_num[all_of_it(u_ssrv.exec_vld)] <= each_num[all_of_it(u_ssrv.exec_vld)] + 1;
    end	

    always @ ( posedge clk )
	if ( rst ) begin
	    log_start <= 0;
		log_finish <= 0;
	end
    else if ( ~log_finish ) 
        if ( ~log_start & u_ssrv.i_sys.csr_vld & ((u_ssrv.i_sys.csr_addr==12'hc00)|(u_ssrv.i_sys.csr_addr==12'hc01)|(u_ssrv.i_sys.csr_addr==12'hc80)) ) begin:ff_log0
    	    integer i;
            log_start <= 1'b1;
			tick_num <= 0;
			instr_num <= 0;
			jtrue_num <= 0;
			jfalse_num <= 0;
			mem_num <= 0;
    	    for(i=0;i<=`EXEC_LEN;i=i+1)
    		    each_num[i] <= 0;
    	end
    	else if ( log_start & u_ssrv.i_sys.csr_vld& ((u_ssrv.i_sys.csr_addr==12'hc00)|(u_ssrv.i_sys.csr_addr==12'hc01)|(u_ssrv.i_sys.csr_addr==12'hc80)) ) begin:ff_log1
    	    integer n;
    	    log_start <= 1'b0;
    		log_finish <= 1'b1;
    		$display("ticks = %d  instructions = %d  I/T = %f",tick_num,instr_num,$itor(instr_num)/tick_num); 
    		for (n=0;n<=`EXEC_LEN;n=n+1) 
    		    $display(" %d -- %d -- %f ",n, each_num[n], $itor(each_num[n])/tick_num);
			$display("True is %d  False is %d T/(T+F) is %f",jtrue_num,jfalse_num,$itor(jtrue_num)/(jtrue_num+jfalse_num));
			$display("MEM number is %d --ratio: %f",mem_num,$itor(mem_num)/tick_num);
    	end else;
    else;	
	
`endif

/*

`ifdef USE_SSRV
integer fd_jump,fd_time;
initial begin
    fd_jump = $fopen("jump_b.txt","w");
	fd_time = $fopen("time_b.txt","w");
end

always @ (posedge clk)
if ( u_ssrv.jump_vld & ~rst ) begin
    $fdisplay(fd_jump,"%8h",u_ssrv.jump_pc);
    $fdisplay(fd_time,"%d",$time);		
end


`else

integer fd_jump,fd_time;
initial begin
    fd_jump = $fopen("jump_a.txt","w");
	fd_time = $fopen("time_a.txt","w");
end

always @ (posedge `CORE_FIELD.clk)
if ( `CORE_FIELD.i_pipe_top.i_pipe_exu.new_pc_req & `CORE_FIELD.core_rst_n ) begin
    $fdisplay(fd_jump,"%8h",`CORE_FIELD.i_pipe_top.i_pipe_exu.new_pc);
    $fdisplay(fd_time,"%d",$time);		
end

`endif

*/

endmodule