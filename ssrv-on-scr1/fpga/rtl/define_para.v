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

//Below are simulation with the help of Syntacore SCR1, you can comment or uncomment  

`define USE_SSRV                                         //comment for SCR1 core working; others SSRV do
//`define WIDE_INSTR_BUS                                   //SCR1 core simulation couldn't supply more than 32-bit BUS, if BUS_LEN is not 1, this defination should work. 
//`define BENCHMARK_LOG                                    //In benchmark test,there is a log for instructions execuated.


//-------------------------------------------------------------------------------
// Recommended core architecture configurations (modifiable)
//-------------------------------------------------------------------------------
//4 or 5 stages
`define FETCH_REGISTERED 

//How many hardware multiplier/divider.
`define MULT_NUM               1

//-------------------------------------------------------------------------------
//"instrbits" buffer
//-------------------------------------------------------------------------------
//The bus width of AHB-lite or AXI: 1 --- 32 bits  2 --- 64 bits, 4 ---- 128 bits. Only 2^x is allowed. If it is bigger than 1, WIDE_INSTR_BUS should be defined.
`define BUFFER0_IN_LEN         1
//How many words it holds:  1 --- 32 bits, 2 --- 64 bits. Any integer
`define BUFFER0_BUF_LEN        (4*`BUFFER0_IN_LEN) 
//How many instructions are generated to the next stage. 1 --- 1 instr, 2 -- 2 instr, Any integer
`define BUFFER0_OUT_LEN        2

//-------------------------------------------------------------------------------
//"schedule" buffer
//-------------------------------------------------------------------------------
//no IN_LEN, because it equals to BUFFER0_OUT_LEN
//How many instructions are kept. 1 -- 1 instr, 2-- 2 instr, Any integer
`define BUFFER1_BUF_LEN        4
//How many instructions are generated for multiple exec units. 1-- 1 instr, 2 -- 2 instr, Any integer
`define BUFFER1_OUT_LEN        2

//-------------------------------------------------------------------------------
//"membuf" buffer
//-------------------------------------------------------------------------------
//no IN_LEN, because it equals to BUFFER1_OUT_LEN
//How many MEM instructions are kept. 1 -- 1 instr, 2-- 2 instr, Any integer
`define BUFFER2_BUF_LEN        6//(2*`BUFFER1_OUT_LEN) 
//no OUT_LEN, it equals to 1

//-------------------------------------------------------------------------------
//"mprf" buffer
//-------------------------------------------------------------------------------
//no IN_LEN, because it equals to BUFFER1_OUT_LEN
//How many ALU instructions are kept. 1 -- 1 instr, 2-- 2 instr, Any integer. (2*`BUFFER1_OUT_LEN) is recommanded
`define BUFFER3_BUF_LEN        6//(2*`BUFFER1_OUT_LEN) 
//How many ALU instructions are allowed to write to the register file in the same cycle, 1 -- 1 instr, 2-- 2 instr, Any integer, BUFFER1_OUT_LEN is recommanded
`define BUFFER3_OUT_LEN        2//`BUFFER1_OUT_LEN







//-------------------------------------------------------------------------------
// Setting recommended configurations(Please make sure you know these defination)
//-------------------------------------------------------------------------------

//instrman.v
`define XLEN                   32
`define BUS_LEN                `BUFFER0_IN_LEN                                                //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0], it should be 1,2,4,8,16... etc
`define BUS_WID                (`BUS_LEN*`XLEN)                                               //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0]  
`define PC_ALIGN               ( ((1'b1<<`XLEN)-1)^( (1'b1<<($clog2(`BUS_LEN)+2))-1'b1 ) )    //1->FFFFFFFC 2->FFFFFFF8 4->FFFFFFF0

//predictor.v
`define PDT_LEN                16
`define PDT_OFF                $clog2(`PDT_LEN+1)
`define PDT_ADDR               12
`define PDT_BLEN               5

//instrbits.v
`define HLEN                   16
`define BUS_OFF                $clog2(2*`BUS_LEN)
`define INBUF_LEN              (2*`BUFFER0_BUF_LEN)
`define INBUF_OFF              $clog2(`INBUF_LEN+1)
`define JCBUF_LEN              5
`define JCBUF_OFF              $clog2(`JCBUF_LEN+1)
`define FETCH_LEN              `BUFFER0_OUT_LEN                                               
`define FETCH_OFF              $clog2(`FETCH_LEN+1)      
  
//schedule.v
`define RGBIT                  5
`define RGLEN                  32
`define SDBUF_LEN              `BUFFER1_BUF_LEN
`define SDBUF_OFF              $clog2(`SDBUF_LEN+1)
`define MMCMB_OFF              $clog2(`MMBUF_LEN+`SDBUF_LEN+1)
`define EXEC_LEN               `BUFFER1_OUT_LEN
`define EXEC_OFF               $clog2(`EXEC_LEN+1)
`define FETCH_PARA_LEN         (11+3*`RGBIT)
`define EXEC_PARA_LEN          (2+3*`RGBIT)
`define LASTBIT_MASK           ( {`RGLEN{1'b1}}<<1 )

//membuf.v
`define MMBUF_LEN              `BUFFER2_BUF_LEN
`define MMBUF_OFF              $clog2(`MMBUF_LEN+1)
`define MMBUF_PARA_LEN         10
`define MMAREA_LEN             ( (`MMBUF_LEN>=6) ? 6 : `MMBUF_LEN )

//mprf.v
`define RFBUF_LEN              `BUFFER3_BUF_LEN
`define RFBUF_OFF              $clog2(`RFBUF_LEN+1)
`define RFINTO_LEN             `BUFFER3_OUT_LEN
`define RFINTO_OFF             $clog2(`RFINTO_LEN+1)

//mul.v
`define MUL_LEN                `MULT_NUM
`define MUL_OFF                ( (`MUL_LEN==1)+$clog2(`MUL_LEN) )//$clog2(`MUL_LEN+1)
`define MULBUF_LEN             1
`define MULBUF_OFF             $clog2(`MULBUF_LEN+1)



