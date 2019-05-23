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
	//system signals
    input                           clk,
    input                           rst,
    
    //from membuf	
	input                           mem_release,
	input `N(5)                     mem_sel,
	
`ifdef REGISTER_EXEC
    input                           jump_vld,
`endif
    
    //from instrbits	
    input `N(`FETCH_LEN*`XLEN)      fetch_bits,
    input `N(`XLEN)                 fetch_pc,   
    
	//to alu	
    output reg `N(`EXEC_LEN*`XLEN)  exec_instr,
    output reg `N(`EXEC_LEN*`XLEN)  exec_pc,

	//to instrbits	
    output reg `N(`FETCH_OFF)       core_offset

);

    function [22:0] rv_para(input [31:0] i);
    begin
	    if ( i[1:0]==2'b11 )
            case(i[6:2])
            //                          SYS(fencei/fence/sys)    csr  jdirct   jcond    mem    alu     rd[4:0]       rs1[4:0]     rs0[4:0]
            5'b01101 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,         5'h0    };//LUI
            5'b00101 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,         5'h0    };//AUIPC
            5'b11011 :   rv_para = {                     3'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,         5'h0    };//JAL
            5'b11001 :   rv_para = {                     3'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,     i[19:15]    };//JALR
            5'b11000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b1,  1'b0,  1'b0,       5'h0,     i[24:20],     i[19:15]    };//BRANCH
            5'b00000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,    i[11:7],         5'h0,     i[19:15]    };//LOAD
            5'b01000 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,       5'h0,     i[24:20],     i[19:15]    };//STORE    
            5'b00100 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],         5'h0,     i[19:15]    };//OP_IMM
            5'b01100 :   rv_para = {                     3'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,    i[11:7],     i[24:20],     i[19:15]    };//OP
            5'b00011 :   rv_para = {(i[12] ? 3'b100 : 3'b010),  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };//MISC_MEM
            5'b11100 :   if (i[14:12]==3'b0)                                              
                         rv_para = {                     3'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };//ECALL/EBREAK
                         else                                                          
                         rv_para = {                     3'b0,  1'b1,   1'b0,   1'b0,  1'b0,  1'b0,    i[11:7],         5'h0,(i[14]?5'h0:i[19:15])};//CSRR
            default  :   rv_para = {                     3'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,       5'h0,         5'h0,         5'h0    };
            endcase 
        else
            rv_para = 0;		
    end
    endfunction   

	
	reg `N(`QUEUE_LEN*`XLEN) queue_instr;
    reg `N(`QUEUE_LEN*`XLEN) queue_pc;	
	
    reg `N(`RGLEN)           rglist_in   `N(`CODE_LEN+1);
	reg `N(`RGLEN)           rglist_out  `N(`CODE_LEN+1);
	reg `N(`MEMB_OFF)        empty_num   `N(`CODE_LEN+1);
	reg `N(`EXEC_OFF)        exec_num    `N(`CODE_LEN+1);
	reg `N(`QUEUE_OFF)       queue_num   `N(`CODE_LEN+1);
	
	reg `N(`EXEC_OFF)        go_exec     `N(`CODE_LEN);
	reg `N(`QUEUE_OFF)       go_queue    `N(`CODE_LEN);
	
	reg `N(`MEMB_OFF)        next_empty  `N(`CODE_LEN+1);
	reg `N(`RGLEN)           next_rglist `N(`CODE_LEN+1);
	
	reg `N(`MEMB_OFF)        init_empty;
	reg `N(`RGLEN)           init_rglist;
	
	wire `N(`RGLEN)          mem_sel_reduce = ( (1'b1<<mem_sel)>>1 ) ^ {`RGLEN{1'b1} };
	
`ifdef REGISTER_EXEC
	`FFx(init_empty,`MEMB_LEN)
	init_empty <= jump_vld ? next_empty[`QUEUE_LEN]: next_empty[`CODE_LEN];
	
	`FFx(init_rglist,0)
	init_rglist <= jump_vld ? next_rglist[`QUEUE_LEN] : next_rglist[`CODE_LEN];
	
	`COMB begin
	    rglist_in[0]     = init_rglist & mem_sel_reduce;
		rglist_out[0]    = init_rglist & mem_sel_reduce;
		empty_num[0]     = init_empty + mem_release;
		exec_num[0]      = 0;
		queue_num[0]     = 0;
		next_empty[0]    = init_empty + mem_release;
		next_rglist[0]   = init_rglist & mem_sel_reduce;
	end
`else
	`FFx(init_empty,`MEMB_LEN)
	init_empty <= next_empty[`CODE_LEN] + mem_release;
	
	`FFx(init_rglist,0)
	init_rglist <= next_rglist[`CODE_LEN] & mem_sel_reduce;
	
	`COMB begin
	    rglist_in[0]     = init_rglist;
		rglist_out[0]    = init_rglist;
		empty_num[0]     = init_empty;
		exec_num[0]      = 0;
		queue_num[0]     = 0;
		next_empty[0]    = init_empty;
		next_rglist[0]   = init_rglist;
	end   
`endif	
	
    wire `N(`XLEN)        instr            `N(`CODE_LEN);
	wire `N(`XLEN)        pc               `N(`CODE_LEN);
	wire `N(`CODE_LEN)    instr_is_fencei  ;
	wire `N(`CODE_LEN)    instr_is_fence   ;
    wire `N(`CODE_LEN)    instr_is_sys     ;
	wire `N(`CODE_LEN)    instr_is_csr     ;
    wire `N(`CODE_LEN)    instr_is_jdirct  ;
    wire `N(`CODE_LEN)    instr_is_jcond   ;
    wire `N(`CODE_LEN)    instr_is_mem     ;
    wire `N(`CODE_LEN)    instr_is_alu     ;	
    wire `N(5)            instr_rd         `N(`CODE_LEN);
    wire `N(5)            instr_rs1        `N(`CODE_LEN);
    wire `N(5)            instr_rs0        `N(`CODE_LEN);
	wire `N(`CODE_LEN)    instr_rg_hit     ;
	
	wire `N(`EXEC_LEN*`XLEN)   chain_exec_instr `N(`CODE_LEN+1);
	wire `N(`EXEC_LEN*`XLEN)   chain_exec_pc `N(`CODE_LEN+1);
	wire `N(`QUEUE_LEN*`XLEN)  chain_queue_instr `N(`CODE_LEN+1);
	wire `N(`QUEUE_LEN*`XLEN)  chain_queue_pc `N(`CODE_LEN+1);	
    wire `N(`FETCH_OFF)        chain_core_offset `N(`CODE_LEN+1);	
	
	assign chain_exec_instr[0]  = 0;
	assign chain_exec_pc[0]     = 0;
	assign chain_queue_instr[0] = 0;
	assign chain_queue_pc[0]    = 0;	
	assign chain_core_offset[0] = 0;
	
    generate
	genvar i;	
	for (i=0;i<`CODE_LEN;i=i+1) begin:gen_fetch

	    assign instr[i] = (i<`QUEUE_LEN) ? queue_instr[`IDX(i,`XLEN)] : fetch_bits[`IDX(i-`QUEUE_LEN,`XLEN)];
		
		assign pc[i] = (i<`QUEUE_LEN) ? queue_pc[`IDX(i,`XLEN)] : ( (i==`QUEUE_LEN) ? fetch_pc : ( pc[i-1] + 4) );
		
		assign { instr_is_fencei[i],instr_is_fence[i],instr_is_sys[i],instr_is_csr[i],instr_is_jdirct[i],instr_is_jcond[i],instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i] } = rv_para(instr[i]);
		
		assign instr_rg_hit[i] = ( |(rglist_in[i]&(((1'b1<<instr_rs0[i])|(1'b1<<instr_rs1[i]))>>1)) )|( |(rglist_out[i]&((1'b1<<instr_rd[i])>>1)) ); 		
		
		always @(instr[i],instr_is_fencei[i],instr_is_fence[i],instr_is_sys[i],instr_is_csr[i],instr_is_jdirct[i],instr_is_jcond[i],instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i],instr_rg_hit[i],rglist_in[i],rglist_out[i],empty_num[i],exec_num[i],queue_num[i],next_empty[i],next_rglist[i])
		begin
		    rglist_in[i+1]            = rglist_in[i]; 
			rglist_out[i+1]           = rglist_out[i];
			empty_num[i+1]            = empty_num[i];
			exec_num[i+1]             = exec_num[i];
			queue_num[i+1]            = queue_num[i];                
            next_empty[i+1]           = next_empty[i];
			next_rglist[i+1]          = next_rglist[i];
                              
            go_exec[i]                = `EXEC_LEN;
			go_queue[i]               = `QUEUE_LEN;	
			
			if ( (i>=`QUEUE_LEN) & ( instr_is_fencei[i]|instr_is_fence[i]|instr_is_sys[i]|instr_is_csr[i]|instr_is_jdirct[i]|instr_is_jcond[i] ) ) begin
				go_exec[i]            = ( (instr_is_fencei[i]&(queue_num[i]!=0))|((instr_is_fencei[i]|instr_is_fence[i])&(empty_num[i]!=`MEMB_LEN))|instr_rg_hit[i]|(exec_num[i]==`EXEC_LEN) ) ? `EXEC_LEN : (`EXEC_LEN-1);			
				exec_num[i+1]         = `EXEC_LEN;
				queue_num[i+1]        = `QUEUE_LEN;			
			end

            if ( instr_is_mem[i] ) begin
			    if ( instr_rg_hit[i]|(empty_num[i]==0)|(exec_num[i]==`EXEC_LEN) ) begin
				    go_queue[i]       = queue_num[i];
					queue_num[i+1]    = (queue_num[i]==`QUEUE_LEN) ?  `QUEUE_LEN : (queue_num[i] + 1);
					exec_num[i+1]     = (queue_num[i]==`QUEUE_LEN) ?  `EXEC_LEN : exec_num[i];
					empty_num[i+1]    = 0;
					rglist_in[i+1]    = rglist_in[i]|( (1'b1<<instr_rd[i])>>1 );
					rglist_out[i+1]   = rglist_out[i]|( ((1'b1<<instr_rd[i])|(1'b1<<instr_rs1[i])|(1'b1<<instr_rs0[i]))>>1  );
				end else begin        
				    go_exec[i]        = exec_num[i];
					exec_num[i+1]     = exec_num[i] + 1;
					empty_num[i+1]    = empty_num[i] - 1;
                    rglist_in[i+1]    = rglist_in[i]|( (1'b1<<instr_rd[i])>>1 );
					rglist_out[i+1]   = rglist_out[i]|( (1'b1<<instr_rd[i])>>1 );
					next_empty[i+1]   = next_empty[i] - 1;
					next_rglist[i+1]  = next_rglist[i]|( (1'b1<<instr_rd[i])>>1 );
				end
			end	    
						
			if ( instr_is_alu[i] ) begin
			    if ( instr_rg_hit[i]|(exec_num[i]==`EXEC_LEN) ) begin
				    go_queue[i]       = queue_num[i];
					queue_num[i+1]    = (queue_num[i]==`QUEUE_LEN) ?  `QUEUE_LEN : (queue_num[i] + 1);
					exec_num[i+1]     = (queue_num[i]==`QUEUE_LEN) ?  `EXEC_LEN  : exec_num[i];
					rglist_in[i+1]    = rglist_in[i]|( (1'b1<<instr_rd[i])>>1 );
                    rglist_out[i+1]   = rglist_out[i]|( ((1'b1<<instr_rd[i])|(1'b1<<instr_rs1[i])|(1'b1<<instr_rs0[i]))>>1  );					
				end else begin
				    go_exec[i]        = exec_num[i];
					exec_num[i+1]     = exec_num[i] + 1;
                    rglist_in[i+1]    = rglist_in[i]|( (1'b1<<instr_rd[i])>>1 );
					rglist_out[i+1]   = rglist_out[i]|( (1'b1<<instr_rd[i])>>1 );                    					
				end
			end
        end

`ifdef REGISTER_EXEC
		assign chain_exec_instr[i+1]  = chain_exec_instr[i]| ( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (instr[i]<<(go_exec[i]*`XLEN)) );
		assign chain_exec_pc[i+1]     = chain_exec_pc[i]|(((i>=`QUEUE_LEN) & jump_vld) ? 0 : (pc[i]<<(go_exec[i]*`XLEN)) );		
		assign chain_queue_instr[i+1] = chain_queue_instr[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (instr[i]<<(go_queue[i]*`XLEN)) );
		assign chain_queue_pc[i+1]    = chain_queue_pc[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (pc[i]<<(go_queue[i]*`XLEN)) );
`else		
		assign chain_exec_instr[i+1]  = chain_exec_instr[i]|(instr[i]<<(go_exec[i]*`XLEN));
		assign chain_exec_pc[i+1]     = chain_exec_pc[i]|(pc[i]<<(go_exec[i]*`XLEN));		
		assign chain_queue_instr[i+1] = chain_queue_instr[i]|(instr[i]<<(go_queue[i]*`XLEN));
		assign chain_queue_pc[i+1]    = chain_queue_pc[i]|(pc[i]<<(go_queue[i]*`XLEN));	
`endif

        assign chain_core_offset[i+1] = chain_core_offset[i] + ( (i>=`QUEUE_LEN) ? ( (go_exec[i]!=`EXEC_LEN)|(go_queue[i]!=`QUEUE_LEN) ) : 0 );
		
	end
	
	endgenerate
	
	
`ifdef REGISTER_EXEC

    `FFx(exec_instr,0)
    exec_instr <= chain_exec_instr[`CODE_LEN];
	
	`FFx(exec_pc,0) 
	exec_pc <= chain_exec_pc[`CODE_LEN];
	
`else
    `COMB
    exec_instr = chain_exec_instr[`CODE_LEN];
	
	`COMB 
	exec_pc = chain_exec_pc[`CODE_LEN];
	
`endif
	
	`COMB 
	core_offset = chain_core_offset[`CODE_LEN];
	
    `FFx(queue_instr,0)
    queue_instr <= chain_queue_instr[`CODE_LEN];
	
	`FFx(queue_pc,0) 
	queue_pc <= chain_queue_pc[`CODE_LEN];
	
endmodule