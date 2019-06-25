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

//Below are for configuration of CPU core; you can modify as you wish; all could not be 0.

`define BUS_LEN            4                              //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0], it should be 1,2,4,8,16... etc
`define FETCH_LEN          3                              //how many words CPU could use.
`define QUEUE_LEN          1                              //how many instrs to wait 
`define EXEC_LEN           3                              //how many ALUs


`define BUF_LEN            3                               //buffer size: BUF_LEN*BUS_LEN*XLEN(bits)
`define MEMB_LEN           8                              //depth of MEM buffer

`define REGISTER_EXEC                                      //comment for 2-stage; uncomment for 3-stage.
`define RV32C_SUPPORTED
`define RV32M_SUPPORTED

`define RFBUF_LEN          8


//Below are simulation with the help of Syntacore SCR1, you can comment or uncomment  

`define USE_SSRV                                         //comment for SCR1 core working; others SSRV do
`define WIDE_INSTR_BUS                                   //SCR1 core simulation couldn't supply more than 32-bit BUS, if BUS_LEN is not 1, this defination should work. 
`define BENCHMARK_LOG                                    //In benchmark test,there is a log for instructions execuated.



//Below are needed by internal, you should not modify unless you are sure.

//`define DIRECT_MODE   

`define XLEN               32
`define HLEN               16
`define RGLEN              32
`define RGBIT              5

//for instrman.v         
`define BUS_WID            (`BUS_LEN*`XLEN)                                            //1->HRDATA[31:0]  2->HRDATA[63:0] 4->HRDATA[127:0]  
`define PC_ALIGN           ( ((1'b1<<`XLEN)-1)^( (1'b1<<($clog2(`BUS_LEN)+2))-1'b1 ) ) //1->FFFFFFFC 2->FFFFFFF8 4->FFFFFFF0

//for instrbits.v
`define BUF_OFF            $clog2(2*`BUF_LEN*`BUS_LEN+1)   
`define FETCH_OFF          $clog2(2*`FETCH_LEN+1)          
`define BUS_OFF            $clog2(2*`BUS_LEN)              

//for schedule.v
`define CODE_LEN           (`QUEUE_LEN+`FETCH_LEN)
`define QUEUE_OFF          $clog2(`QUEUE_LEN+1)
`define EXEC_OFF           $clog2(`EXEC_LEN+1)
`define QUEUE_PARA_OFF     17

//for alu.v
`define MEMB_PARA          9

//for membuf.v
`define MEMB_OFF           $clog2(`MEMB_LEN+1)                                        //[MEMB_OFF-1:0] covers 0 ~ MEMB_LEN

//for mprf.v
`define RFBUF_OFF          $clog2(`RFBUF_LEN+1)

