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
	
    `define RV_PARA_LEN            (11+`RGBIT*3)	
	
	function `N(`RV_PARA_LEN) rv_para(input `N(`XLEN) i,input err);
	    reg             illegal,mul,fencei,fence,sys,csr,jalr,jal,jcond,mem,alu;
		reg `N(`RGBIT)  rd,rs1,rs0;
	    begin
	        illegal = 0;
			mul     = 0;
			fencei  = 0;
			fence   = 0;
			sys     = 0;
			csr     = 0;
			jalr    = 0;
			jal     = 0;
			jcond   = 0;
			mem     = 0;
			alu     = 0;
			rd      = 0;
			rs1     = 0;
			rs0     = 0;
			if ( 1'b1 ) begin
			    if ( i[1:0]==2'b11 ) 
				    case(i[6:2])
					5'b01101 :                        //LUI
					            begin
						            alu     = 1;
						        	rd      = i[11:7];
						        end
					5'b00101 :                        //AUIPC
					            begin
						            alu     = 1;
						        	rd      = i[11:7];						    
						        end
                    5'b11011 :                        //JAL
                                begin
						            jal     = 1;
						        	rd      = i[11:7];                            
                                end
                    5'b11001 :                       //JALR
                                begin
						            jalr    = 1;
						        	rd      = i[11:7];
                                    rs0     = i[19:15];                            
                                end	
                    5'b11000 :                       //BRANCH
                                begin
                                    jcond   = 1;
									rs0     = i[19:15];
									rs1     = i[24:20];
                                end								
					5'b00000 :                       //LOAD
					            begin
					                mem     = 1;
									rd      = i[11:7];
									rs0     = i[19:15];
					                illegal = (i[14:12]==3'b011)|(i[14:12]==3'b110)|(i[14:12]==3'b111);
					            end
					5'b01000 :                       //STORE			
					            begin
					                mem     = 1;
									rs0     = i[19:15];
									rs1     = i[24:20];
					                illegal = (i[14:12]>=3'b011);
					            end								
					5'b00100 :                       //OP_IMM
                                begin
					                alu     = 1;
									rd      = i[11:7];
									rs0     = i[19:15];                                    
                                    illegal = (i[14:12]==3'b001) ? (i[31:25]!=7'b0) : ( (i[14:12]==3'b101) ?  ( ~( (i[31:25]==7'b0000000)|(i[31:25]==7'b0100000) ) ) : 0 );
                                end	
                    5'b01100 :                       //OP
                                begin
								    mul     = i[25];
					                alu     = ~i[25];
									rd      = i[11:7];
									rs0     = i[19:15];       
                                    rs1     = i[24:20];									
                                    if ( i[31:25]==7'b0000000 )
									    illegal = 0;
									else if ( i[31:25]==7'b0100000 )
									    illegal = ~( (i[14:12]==3'b000)|(i[14:12]==3'b101) );
									else if ( i[31:25]==7'b0000001 )
									    illegal = 0;
									else 
									    illegal = 1;
                                end	
					5'b00011 :                      //MISC_MEM
					            begin
								    fencei = i[12];
									fence  = ~i[12];
									if ( i[14:12]==3'b000 )
									    illegal = |{i[31:28], i[19:15], i[11:7]};
								    else if ( i[14:12]==3'b001 )
									    illegal = |{i[31:15], i[11:7]};
									else
									    illegal = 1;
								end
					5'b11100 :                    //ECALL/EBREAK/CSRR
					            begin
								    if ( i[14:12]==3'b000 ) begin
									    sys     = 1;
										if ( {i[19:15], i[11:7]}==10'b0 )
										    illegal = ~( (i[31:20]==12'h000)|(i[31:20]==12'h001)|(i[31:20]==12'h302)|(i[31:20]==12'h105) );
										else 
										    illegal = 1;
									end else begin
									    csr     = 1;
										rd      = i[11:7];
										rs0     = i[14] ? 5'h0 : i[19:15];
									    illegal = (i[14:12]==3'b100);
								    end
								end
					default  :  illegal = 1;			
					endcase
				else  case({i[15:13],i[1:0]})                                            
                    5'b000_00:   //C.ADDI4SPN
					            begin
								    alu     = 1;
									rd      = {2'b1,i[4:2]};
									rs0     = 5'h2;
									illegal = ~(|i[12:5]);
								end
                    5'b010_00:   //C.LW
					            begin
								    mem     = 1;
									rd      = {2'b1,i[4:2]};
									rs0     = {2'b1,i[9:7]};
								end
                    5'b110_00:   //C.SW
					            begin
								    mem     = 1;
									rs0     = {2'b1,i[9:7]};
									rs1     = {2'b1,i[4:2]};
								end
                    5'b000_01:   //C.ADDI
                                begin
                                    alu     = 1;
									rd      = i[11:7];
									rs0     = i[11:7];
                                end								
                    5'b001_01:   //C.JAL	
                                begin
                                    jal     = 1;
									rd      = 5'h1;
                                end								
                    5'b010_01:   //C.LI
					            begin
								    alu     = 1;
									rd      = i[11:7];
								end
                    5'b011_01:   //C.ADDI16SP/C.LUI
                                begin
								    alu     = 1;
									rd      = i[11:7];
									rs0     = (i[11:7]==5'h2) ? 5'h2 : 5'h0;
									illegal = ~(|{i[12], i[6:2]});
								end
					5'b100_01:  
             					if (i[11:10]!=2'b11)      //C.SRLI/C.SRAI/C.ANDI
                                    begin
								        alu     = 1;
										rd      = {2'b1,i[9:7]};
										rs0     = {2'b1,i[9:7]};
										illegal = ~i[11] & i[12];
								    end
								else //C.SUB/C.XOR/C.OR/C.AND
								    begin
									    alu     = 1;
										rd      = {2'b1,i[9:7]};
										rs0     = {2'b1,i[9:7]};
										rs1     = {2'b1,i[4:2]};
										illegal = i[12];
									end
                    5'b101_01:   //C.J
					            begin
								    jal     = 1;
								end
                    5'b110_01,                                                                                                           
                    5'b111_01:   //C.BEQZ/C.BNEZ
					            begin
								    jcond   = 1;
									rs0     = {2'b1,i[9:7]};
								end
                    5'b000_10:   //C.SLLI
					            begin
								    alu     = 1;
									rd      = i[11:7];
									rs0     = i[11:7];
									illegal = i[12];
								end
                    5'b010_10:   //C.LWSP
					            begin
								    mem     = 1;
									rd      = i[11:7];
									rs0     = 5'h2;
									illegal = ~(|i[11:7]);
								end
                    5'b100_10:   
					            if ( ~i[12] & (i[6:2]==5'h0) ) //C.JR
								    begin
                                        jalr    = 1;
										rs0     = i[11:7];
                                        illegal = ~(|i[11:7]);
                                    end									
                                else if ( ~i[12] & (i[6:2]!=5'h0)  )  //C.MV
                                    begin
									    alu     = 1;
										rd      = i[11:7];
										rs1     = i[6:2];
									end
								else if((i[11:7]==5'h0)&(i[6:2]==5'h0)) //C.EBREAK
								    begin
									    sys      = 1;
									end
                                else if (i[6:2]==5'h0)        //C.JALR
                                    begin
									    jalr     = 1;
										rd       = 5'h1;
										rs0      = i[11:7];
									end
								else                 //C.ADD 
								    begin
                                        alu      = 1;
										rd       = i[11:7];
										rs0      = i[11:7];
										rs1      = i[6:2];
                                    end									
                    5'b110_10:   //C.SWSP
					            begin
								    mem       = 1;
									rs0       = 5'h2;
									rs1       = i[6:2];
								end
                    default  :  illegal = 1;
                    endcase
	        end 
			rv_para = { err,illegal,sys,fencei,fence,csr,jalr,jal,jcond,(mem|mul),(alu|jal|jalr),rd,rs1,rs0 };
	    end
	endfunction
	
	
    function `N(`XLEN) jal_offset(input `N(`XLEN) instr);
        begin
            if ( instr[1:0]==2'b11 )
	    	    jal_offset = { {12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0 };
	    	else
	    	    jal_offset = { {21{instr[12]}},instr[8],instr[10:9],instr[6],instr[7],instr[2],instr[11],instr[5:3],1'b0 }; 
        end
    endfunction	  

    function `N(`XLEN) jalr_offset(input `N(`XLEN) instr);
        begin
            if ( instr[1:0]==2'b11 )
	    	    jalr_offset = { {21{instr[31]}},instr[30:20] };
	    	else
	    	    jalr_offset = 32'h0; 
        end
    endfunction	
	
    function `N(`XLEN) jcond_offset(input `N(`XLEN) instr);
        begin
            if ( instr[1:0]==2'b11 )
	    	    jcond_offset = { {20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0 };
	    	else
	    	    jcond_offset = { {24{instr[12]}},instr[6:5],instr[2],instr[11:10],instr[4:3],1'b0};	 
        end
    endfunction		
	
	function `N(`MMCMB_OFF) sub_order(input `N(`MMCMB_OFF) n, input x);
	    begin
		    sub_order = (n==0) ? 0 : (n-x);
		end
	endfunction
	
	function `N(`JCBUF_OFF) sub_level(input `N(`JCBUF_OFF) n, input x);
	    begin
		    sub_level = (n==0) ? 0 : (n-x);
		end
	endfunction
	
    function condition_satisfied( input `N(4) para, input `N(`XLEN) rs0_word, rs1_word );
	begin
        if ( para[3] )
            case(para[2:0])
            3'b000 : condition_satisfied =    rs0_word==rs1_word;
            3'b001 : condition_satisfied = ~( rs0_word==rs1_word );
            3'b100 : condition_satisfied =    (rs0_word[31]^rs1_word[31]) ? rs0_word[31] : (rs0_word<rs1_word);
            3'b101 : condition_satisfied = ~( (rs0_word[31]^rs1_word[31]) ? rs0_word[31] : (rs0_word<rs1_word) );
            3'b110 : condition_satisfied =    rs0_word<rs1_word;
            3'b111 : condition_satisfied = ~( rs0_word<rs1_word );
            default: condition_satisfied = 1'b0;
            endcase
        else if ( para[1] )
            condition_satisfied = rs0_word != rs1_word;
        else
            condition_satisfied = rs0_word == rs1_word;  	
	end
	endfunction	
	
	
	
	
	
	
	