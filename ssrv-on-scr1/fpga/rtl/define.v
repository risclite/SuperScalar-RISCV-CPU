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


`ifndef RTL_DEF
`define RTL_DEF

//`timescale 1 ns/1 ps

//index definition
`define IDX(x,y)    ((x)*(y))+:(y)
`define N(n)        [(n)-1:0]

//port ddefinition
`define IN(n)       input [(n)-1:0]
`define OUT(n)      output [(n)-1:0]
`define OUTW(n)     output wire [(n)-1:0]
`define OUTR(n)     output reg  [(n)-1:0]

//wire & reg definition
`define WIRE(n)    wire [(n)-1:0]
`define REG(n)     reg  [(n)-1:0]

//combanation logic definition
`define COMB        always @*   

//sequential logic definitiaon
`define FF(clk)                         always @ ( posedge (clk) )
`define FFpos(clk, rst,signal,bits)     always @ ( posedge clk or posedge  rst ) if (   rst   )  signal <= bits;  else
`define FFneg(clk,rstn,signal,bits)     always @ ( posedge clk or negedge rstn ) if ( ~(rstn) )  signal <= bits;  else
`define FFx(signal,bits)           always @ ( posedge clk or posedge  rst ) if (   rst   )  signal <= bits;  else

//others
`include "define_para.v"

`endif
