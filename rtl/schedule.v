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

`ifdef RV32M_SUPPORTED
    input                           mul_is_busy,
`endif	
	
`ifdef REGISTER_EXEC
    input                           jump_vld,
`endif
    
    //from instrbits	
    input `N(`FETCH_LEN*`XLEN)      fetch_instr,
    input `N(`FETCH_LEN*`XLEN)      fetch_pc,
    input `N(`FETCH_LEN)            fetch_vld,	
    
	//to alu	
    output reg `N(`EXEC_LEN*`XLEN)  exec_instr,
    output reg `N(`EXEC_LEN*`XLEN)  exec_pc,
	output reg `N(`EXEC_LEN)        exec_vld,

	//to instrbits	
    output reg `N(`FETCH_OFF)       core_offset

);

    function [23:0] rv_para(input vld,input [31:0] i);
    begin
	    if ( ~vld )
		    rv_para = 0;
	    else if ( i[1:0]==2'b11 ) 
            case(i[6:2])
            //                         mul    fencei    fence    sys    csr  jdirct   jcond    mem    alu        rd[4:0]       rs1[4:0]     rs0[4:0]
            5'b01101 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//LUI
            5'b00101 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//AUIPC
            5'b11011 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,         5'h0    };//JAL
            5'b11001 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b1,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,     i[19:15]    };//JALR
            5'b11000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b1,  1'b0,  1'b0,          5'h0,     i[24:20],     i[19:15]    };//BRANCH
            5'b00000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,       i[11:7],         5'h0,     i[19:15]    };//LOAD
            5'b01000 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b1,  1'b0,          5'h0,     i[24:20],     i[19:15]    };//STORE    
            5'b00100 :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,     i[19:15]    };//OP_IMM
            5'b01100 :   rv_para = { i[25],     1'b0,    1'b0,  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,~i[25],       i[11:7],     i[24:20],     i[19:15]    };//OP
            5'b00011 :   rv_para = {  1'b0,    i[12],(~i[12]),  1'b0,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//MISC_MEM
            5'b11100 :   if (i[14:12]==3'b0)                                                                   
                         rv_para = {  1'b0,     1'b0,    1'b0,  1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//ECALL/EBREAK
                         else                                                                                  
                         rv_para = {  1'b0,     1'b0,    1'b0,  1'b0,  1'b1,   1'b0,   1'b0,  1'b0,  1'b0,       i[11:7],         5'h0,(i[14]?5'h0:i[19:15])};//CSRR
            default  :   rv_para = {  1'b0,     1'b0,    1'b0,  1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
            endcase 
        else
`ifdef RV32C_SUPPORTED
     		case({i[15:13],i[1:0]})                                            
            5'b000_00:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[4:2]},         5'h0,         5'h2    };//C.ADDI4SPN
            5'b010_00:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0, {2'b1,i[4:2]},         5'h0,{2'b1,i[9:7]}    };//C.LW
            5'b110_00:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,{2'b1,i[4:2]},{2'b1,i[9:7]}    };//C.SW
            5'b000_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,      i[11:7]    };//C.ADDI			
            5'b001_01:   rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h1,         5'h0,         5'h0    };//C.JAL			
            5'b010_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,         5'h0    };//C.LI			
            5'b011_01:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,((i[11:7]==5'h2)?5'h2:5'h0)};//C.ADDI16SP/C.LUI
            5'b100_01:   if (i[11:10]!=2'b11)                                       
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[9:7]},         5'h0,{2'b1,i[9:7]}    };//C.SRLI/C.SRAI/C.ANDI
                         else                                                       
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1, {2'b1,i[9:7]},{2'b1,i[4:2]},{2'b1,i[9:7]}    };//C.SUB/C.XOR/C.OR/C.AND
            5'b101_01:   rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//C.J
            5'b110_01,                                                                                                           
            5'b111_01:   rv_para = {                                           1'b0,   1'b1,  1'b0,  1'b0,          5'h0,         5'h0,{2'b1,i[9:7]}    };//C.BEQZ/C.BNEZ
            5'b000_10:   rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],         5'h0,      i[11:7]    };//C.SLLI
            5'b010_10:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,       i[11:7],         5'h0,         5'h2    };//C.LWSP
            5'b100_10:   if ( ~i[12] & (i[6:2]==5'h0) )                          
                         rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,      i[11:7]    };//C.JR
                         else if ( ~i[12] & (i[6:2]!=5'h0)  )                    
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],       i[6:2],         5'h0    };//C.MV
                         else if((i[11:7]==5'h0)&(i[6:2]==5'h0))           
                         rv_para = {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };//C.EBREAK
                         else if (i[6:2]==5'h0)                                  
                         rv_para = {                                           1'b1,   1'b0,  1'b0,  1'b0,          5'h1,         5'h0,      i[11:7]    };//C.JALR
                         else                                                    
                         rv_para = {                                           1'b0,   1'b0,  1'b0,  1'b1,       i[11:7],       i[6:2],      i[11:7]    };//C.ADD 
            5'b110_10:   rv_para = {                                           1'b0,   1'b0,  1'b1,  1'b0,          5'h0,       i[6:2],         5'h2    };//C.SWSP
            default  :   rv_para = {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
            endcase
`else 
            rv_para =              {                            1'b1,  1'b0,   1'b0,   1'b0,  1'b0,  1'b0,          5'h0,         5'h0,         5'h0    };
`endif			
    end
    endfunction   

	
	reg `N(`QUEUE_LEN*`XLEN) queue_instr;
    reg `N(`QUEUE_LEN*`XLEN) queue_pc;	
	reg `N(`QUEUE_LEN)       queue_vld;
	reg `N(`QUEUE_LEN*17)    queue_para;
	
    reg `N(`RGLEN)           rglist_rs   `N(`CODE_LEN+1);
	reg `N(`RGLEN)           rglist_rd   `N(`CODE_LEN+1);
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
	    rglist_rs[0]     = init_rglist & mem_sel_reduce;
		rglist_rd[0]     = init_rglist & mem_sel_reduce;
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
	    rglist_rs[0]     = init_rglist;
		rglist_rd[0]     = init_rglist;
		empty_num[0]     = init_empty;
		exec_num[0]      = 0;
		queue_num[0]     = 0;
		next_empty[0]    = init_empty;
		next_rglist[0]   = init_rglist;
	end   
`endif	
	
    wire `N(`XLEN)        instr            `N(`CODE_LEN);
	wire `N(`XLEN)        pc               `N(`CODE_LEN);
	wire `N(`CODE_LEN)    vld              ;
	wire `N(`CODE_LEN)    instr_is_mul     ;
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
	wire `N(`EXEC_LEN)         chain_exec_vld `N(`CODE_LEN+1);
	wire `N(`QUEUE_LEN*`XLEN)  chain_queue_instr `N(`CODE_LEN+1);
	wire `N(`QUEUE_LEN*`XLEN)  chain_queue_pc `N(`CODE_LEN+1);
    wire `N(`QUEUE_LEN)        chain_queue_vld `N(`CODE_LEN+1);	
	wire `N(`QUEUE_LEN*17)     chain_queue_para `N(`CODE_LEN+1);
    wire `N(`FETCH_OFF)        chain_core_offset `N(`CODE_LEN+1);	
	
	assign chain_exec_instr[0]  = 0;
	assign chain_exec_pc[0]     = 0;
	assign chain_exec_vld[0]    = 0;
	assign chain_queue_instr[0] = 0;
	assign chain_queue_pc[0]    = 0;
    assign chain_queue_vld[0]   = 0;
    assign chain_queue_para[0]  = 0;	
	assign chain_core_offset[0] = 0;
	
    generate
	genvar i;	
	for (i=0;i<`CODE_LEN;i=i+1) begin:gen_fetch

	    assign instr[i] = (i<`QUEUE_LEN) ? queue_instr[`IDX(i,`XLEN)] : fetch_instr[`IDX(i-`QUEUE_LEN,`XLEN)];
		
		assign pc[i] = (i<`QUEUE_LEN) ? queue_pc[`IDX(i,`XLEN)] : fetch_pc[`IDX(i-`QUEUE_LEN,`XLEN)];
		
		assign vld[i] = (i<`QUEUE_LEN) ? queue_vld[i] : fetch_vld[i-`QUEUE_LEN];
		
		assign { instr_is_mul[i],instr_is_fencei[i],instr_is_fence[i],instr_is_sys[i],instr_is_csr[i],instr_is_jdirct[i],instr_is_jcond[i],instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i] } = (i<`QUEUE_LEN) ? queue_para[`IDX(i,17)] : rv_para(vld[i],instr[i]);
		
		assign instr_rg_hit[i] = ( |(rglist_rs[i]&(((1'b1<<instr_rs0[i])|(1'b1<<instr_rs1[i]))>>1)) )|( |(rglist_rd[i]&((1'b1<<instr_rd[i])>>1)) ); 		

`ifdef RV32M_SUPPORTED
		always @(instr[i],instr_is_fencei[i],instr_is_fence[i],instr_is_sys[i],instr_is_csr[i],instr_is_jdirct[i],instr_is_jcond[i],instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i],instr_rg_hit[i],rglist_rs[i],rglist_rd[i],empty_num[i],exec_num[i],queue_num[i],next_empty[i],next_rglist[i],instr_is_mul[i],mul_is_busy)
`else		
		always @(instr[i],instr_is_fencei[i],instr_is_fence[i],instr_is_sys[i],instr_is_csr[i],instr_is_jdirct[i],instr_is_jcond[i],instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i],instr_rg_hit[i],rglist_rs[i],rglist_rd[i],empty_num[i],exec_num[i],queue_num[i],next_empty[i],next_rglist[i])
`endif
		begin
		    rglist_rs[i+1]            = rglist_rs[i]; 
			rglist_rd[i+1]            = rglist_rd[i];
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

`ifdef RV32M_SUPPORTED			
			if ( (i>=`QUEUE_LEN) & instr_is_mul[i] ) begin
			    if ( instr_rg_hit[i]|mul_is_busy|(exec_num[i]==`EXEC_LEN) ) begin
				    exec_num[i+1]     = `EXEC_LEN;
				    queue_num[i+1]    = `QUEUE_LEN;					    
				end else begin
				    go_exec[i]        = `EXEC_LEN - 1;
				    exec_num[i+1]     = `EXEC_LEN;
				    queue_num[i+1]    = `QUEUE_LEN;		
					next_rglist[i+1]  = next_rglist[i]|( (1'b1<<instr_rd[i])>>1 );
				end
			end
`endif			

            if ( instr_is_mem[i] ) begin
			    if ( instr_rg_hit[i]|(empty_num[i]==0)|(exec_num[i]==`EXEC_LEN) ) begin
				    go_queue[i]       = queue_num[i];
					queue_num[i+1]    = (queue_num[i]==`QUEUE_LEN) ?  `QUEUE_LEN : (queue_num[i] + 1);
					exec_num[i+1]     = (queue_num[i]==`QUEUE_LEN) ?  `EXEC_LEN : exec_num[i];
					empty_num[i+1]    = 0;
					rglist_rs[i+1]    = rglist_rs[i]|( (1'b1<<instr_rd[i])>>1 );
					rglist_rd[i+1]    = rglist_rd[i]|( ((1'b1<<instr_rd[i])|(1'b1<<instr_rs1[i])|(1'b1<<instr_rs0[i]))>>1  );
				end else begin        
				    go_exec[i]        = exec_num[i];
					exec_num[i+1]     = exec_num[i] + 1;
					empty_num[i+1]    = empty_num[i] - 1;
                    rglist_rs[i+1]    = rglist_rs[i]|( (1'b1<<instr_rd[i])>>1 );
					rglist_rd[i+1]    = rglist_rd[i]|( (1'b1<<instr_rd[i])>>1 );
					next_empty[i+1]   = next_empty[i] - 1;
					next_rglist[i+1]  = next_rglist[i]|( (1'b1<<instr_rd[i])>>1 );
				end
			end	    
						
			if ( instr_is_alu[i] ) begin	
			    if ( instr_rg_hit[i]|(exec_num[i]==`EXEC_LEN) ) begin
    				go_queue[i]       = queue_num[i];
					queue_num[i+1]    = (queue_num[i]==`QUEUE_LEN) ?  `QUEUE_LEN : (queue_num[i] + 1);
					exec_num[i+1]     = (queue_num[i]==`QUEUE_LEN) ?  `EXEC_LEN  : exec_num[i];
					rglist_rs[i+1]    = rglist_rs[i]|( (1'b1<<instr_rd[i])>>1 );
                    rglist_rd[i+1]    = rglist_rd[i]|( ((1'b1<<instr_rd[i])|(1'b1<<instr_rs1[i])|(1'b1<<instr_rs0[i]))>>1  );					
				end else begin			
				    go_exec[i]        = exec_num[i];
					exec_num[i+1]     = exec_num[i] + 1;
                    rglist_rs[i+1]    = rglist_rs[i]|( (1'b1<<instr_rd[i])>>1 );				
					//rglist_rd[i+1]    = rglist_rd[i]|( (1'b1<<instr_rd[i])>>1 );                    					
				end
			end
        end

`ifdef REGISTER_EXEC
		assign chain_exec_instr[i+1]  = chain_exec_instr[i]| ( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (instr[i]<<(go_exec[i]*`XLEN)) );
		assign chain_exec_pc[i+1]     = chain_exec_pc[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (pc[i]<<(go_exec[i]*`XLEN)) );	
        assign chain_exec_vld[i+1]    = chain_exec_vld[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (1'b1<<go_exec[i]) );		
		assign chain_queue_instr[i+1] = chain_queue_instr[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (instr[i]<<(go_queue[i]*`XLEN)) );
		assign chain_queue_pc[i+1]    = chain_queue_pc[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (pc[i]<<(go_queue[i]*`XLEN)) );
		assign chain_queue_vld[i+1]   = chain_queue_vld[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : (1'b1<<go_queue[i]) );
		assign chain_queue_para[i+1] = chain_queue_para[i]|( ((i>=`QUEUE_LEN) & jump_vld) ? 0 : ({instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i]}<<(go_queue[i]*17)) );
`else		
		assign chain_exec_instr[i+1]  = chain_exec_instr[i]|(instr[i]<<(go_exec[i]*`XLEN));
		assign chain_exec_pc[i+1]     = chain_exec_pc[i]|(pc[i]<<(go_exec[i]*`XLEN));
        assign chain_exec_vld[i+1]    = chain_exec_vld[i]|(1'b1<<go_exec[i]);		
		assign chain_queue_instr[i+1] = chain_queue_instr[i]|(instr[i]<<(go_queue[i]*`XLEN));
		assign chain_queue_pc[i+1]    = chain_queue_pc[i]|(pc[i]<<(go_queue[i]*`XLEN));
        assign chain_queue_vld[i+1]   = chain_queue_vld[i]|(1'b1<<go_queue[i]);		
		assign chain_queue_para[i+1]  = chain_queue_para[i]|({instr_is_mem[i],instr_is_alu[i],instr_rd[i],instr_rs1[i],instr_rs0[i]}<<(go_queue[i]*17));
`endif

        assign chain_core_offset[i+1] = chain_core_offset[i] + ( (i>=`QUEUE_LEN) ? ( ( (go_exec[i]!=`EXEC_LEN)|(go_queue[i]!=`QUEUE_LEN) ) ? ( (instr[i][1:0]==2'b11) ? 2'd2 : 2'd1 ) : 0 ) : 0 );
		
	end
	
	endgenerate
	
	
`ifdef REGISTER_EXEC

    `FFx(exec_instr,0)
    exec_instr <= chain_exec_instr[`CODE_LEN];
	
	`FFx(exec_pc,0) 
	exec_pc <= chain_exec_pc[`CODE_LEN];
	
	`FFx(exec_vld,0)
	exec_vld <= chain_exec_vld[`CODE_LEN];
	
`else
    `COMB
    exec_instr = chain_exec_instr[`CODE_LEN];
	
	`COMB 
	exec_pc = chain_exec_pc[`CODE_LEN];
	
	`COMB
	exec_vld = chain_exec_vld[`CODE_LEN];
	
`endif
	
	`COMB 
	core_offset = chain_core_offset[`CODE_LEN];
	
    `FFx(queue_instr,0)
    queue_instr <= chain_queue_instr[`CODE_LEN];
	
	`FFx(queue_pc,0) 
	queue_pc <= chain_queue_pc[`CODE_LEN];
	
	`FFx(queue_vld,0)
	queue_vld <= chain_queue_vld[`CODE_LEN];
	
	`FFx(queue_para,0)
	queue_para <= chain_queue_para[`CODE_LEN];
	
endmodule