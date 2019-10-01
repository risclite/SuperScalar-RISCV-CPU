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
`define WIDE_INSTR_BUS                                   //SCR1 core simulation couldn't supply more than 32-bit BUS, if BUS_LEN is not 1, this defination should work. 
`define BENCHMARK_LOG                                    //In benchmark test,there is a log for instructions execuated.



//instrman.v
`define XLEN                   32
`define BUS_LEN                4                                                              //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0], it should be 1,2,4,8,16... etc
`define BUS_WID                (`BUS_LEN*`XLEN)                                               //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0]  
`define PC_ALIGN               ( ((1'b1<<`XLEN)-1)^( (1'b1<<($clog2(`BUS_LEN)+2))-1'b1 ) )    //1->FFFFFFFC 2->FFFFFFF8 4->FFFFFFF0


//instrbits.v
`define HLEN                   16
`define BUS_OFF                $clog2(2*`BUS_LEN) 
`define INBUF_LEN              3                                                              //buffer size: INBUF_LEN*BUS_LEN*XLEN(bits)
`define INBUF_HLEN_OFF         $clog2(2*`INBUF_LEN*`BUS_LEN+1) 
`define FETCH_LEN              4                                                              //how many words CPU could use.
`define FETCH_OFF              $clog2(`FETCH_LEN+1)      
`define FETCH_HLEN_OFF         $clog2(2*`FETCH_LEN+1+1)    
  

//schedule.v
`define RGBIT                  5
`define RGLEN                  32
`define MMCMB_OFF              $clog2(`MMBUF_LEN+`SDBUF_LEN+1)
`define SDBUF_LEN              8
`define SDBUF_OFF              $clog2(`SDBUF_LEN+1)
`define EXEC_LEN               4
`define EXEC_OFF               $clog2(`EXEC_LEN+1)
`define FETCH_PARA_LEN         (9+3*`RGBIT)
`define EXEC_PARA_LEN          (2+3*`RGBIT)

//membuf.v
`define MMBUF_LEN              8
`define MMBUF_OFF              $clog2(`MMBUF_LEN+1)
`define MMBUF_PARA_LEN         11

//mprf.v
`define RFBUF_LEN              8
`define RFBUF_OFF              $clog2(`RFBUF_LEN+1)
`define WRRG_LEN               `EXEC_LEN
`define WRRG_OFF               $clog2(`WRRG_LEN+1)


//mul.v
`define MULBUF_LEN             2
`define MULBUF_OFF             $clog2(`MULBUF_LEN+1)



