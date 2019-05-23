# SuperScalar-RISCV-CPU
fully super-scalar rv32i cpu core, 3.8 DMIPS/MHz(best performance)


## Overview ##

SSRV (SuperScalar RISC-V)  is an open-source RV32I core, which is superscalar (able to execute multiple instructions per cycle) and out-of-order (able to execute instructions as their dependencies are resolved and not restricted to their program order).   It is synthesizable fully( written in native verilog-2001) and parameterizable fully ( You can define how many instructions executed in the same cycle, how depth out-of-order could reach). It has outstanding integer processing ability: DMIPS/MHz : 3.8/3.6 (2/3-stage, without -fno-inline compiler options); 2.14/1.95 (2/3-stage,-O3 -fno-inline).


## Principle ##

Thanks to its clear structure, SSRV is a super-efficient machine to dispatch mutiple instructions, which only has 2 or 3 stages. In the next diagram, we could see the clear pipeline how SSRV does "super-scalar" and "out-of-order" work. 

The 1st stage: "Fetch": All CPU core will send "PC" address to "instructions memory" .In the next cycle or more, instructions of this address are available on "rdata" bus signals.

The 2nd stage: SSRV will fetch "BUS_LEN" number of 32-bit instructions in one cycle. These instructions and ones stored in "BUFFER" before will make up "FETCH_LEN" number of instructions. 

We always  know there is data dependency of instructions, which will make some instruction will not be issued to "execute" stage. For a pessimist, it is a bad luck to have an instruction that could not be executed; but for an optimist, it is a good luck because in the very next cycle, the same instruction will have more possibility to be executed than others. So, one of "FETCH_LEN" number of instructions will have two destinies, go to "EXEC_LEN" number of "EXEC" area to be executed; or go to "QUEUE_LEN" number of "QUEUE" area to be the top list of ones evaluated in the next cycle.

If it is a configuration of 3-stage, all "EXEC_LEN" instructions are registered, or they are delivered directly.

The 3rd stage: Every instruction in "EXEC" area has its own ALU, which fetch operands  or store "Rd" between "register file", and send memory operation to "memory buffer". The last ALU will share its channel to "register file" with "SYS_CSR", which is dedicated to system or CSR-related instructions.  

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/diagram.png)

## Benchmark ##

This project is inspired and based on Syntacore's core: SCR1 [https://github.com/syntacore/scr1]. Syntacore supplies "riscv_isa", "riscv_compliance", "coremark" and "dhrystone21" simulation tests. So, the basic benchmark scores could be listed here:


|               |SCR1           | SSRV(3-stage) FETCH_LEN=1 QUEUE_LEN=1 EXEC_LEN=1 |SSRV(3-stage) FETCH_LEN=2 QUEUE_LEN=2 EXEC_LEN=2 | SSRV(3-stage) FETCH_LEN=3 QUEUE_LEN=2 EXEC_LEN=3  | SSRV(2-stage) FETCH_LEN=2 QUEUE_LEN=2 EXEC_LEN=2 | SSRV(2-stage) FETCH_LEN=3 QUEUE_LEN=2 EXEC_LEN=3 |
| ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
| DMIPS/MHz:(-O3 -fno-inline) | 1.10 |1.34 <br> (parallel ratio: 0----11%<br> 1----89%) |1.79 <br> (parallel ratio: <br> 0----17% <br> 1----47% <br> 2----36%) | 1.90 <br> (parallel ratio: 0----20% <br> 1----45% <br> 2----23% <br> 3----12%) |  2.00 <br> (parallel ratio: <br> 0----10% <br> 1----48% <br> 2----42%) | 2.14 <br> (parallel ratio: <br> 0----15% <br> 1----43% <br> 2----27% <br> 3----15%) |
| DMIPS/MHz:(default of SCR1) | 1.96 |2.59 <br> (parallel ratio: 0----7%<br> 1----93%) | 3.31 <br> (parallel ratio: <br> 0----14% <br> 1----52% <br> 2----34%) | 3.53 <br> (parallel ratio: <br> 0----16% <br> 1----50% <br> 2----25% <br> 3----9%) |  3.58 <br> (parallel ratio: <br> 0----7% <br> 1----56% <br> 2----37%) | 3.80 <br> (parallel ratio: <br> 0----10% <br> 1----53% <br> 2----26% <br> 3----11%) |
| ticks per iteration of CoreMark(default of SCR1) | 7896 | 8834 <br> (parallel ratio: 0----19%<br> 1----81%) |6811 <br> (parallel ratio: <br> 0----24% <br> 1----46% <br> 2----30%) | 6663 <br> (parallel ratio: <br> 0----26% <br> 1----50% <br> 2----13% <br> 3----11%) | 5385 <br> (parallel ratio: <br> 0----5% <br> 1----57% <br> 2----38%) | 5232 <br> (parallel ratio: <br> 0----8% <br> 1----62% <br> 2----16% <br> 3----14%) |

--RISCV gcc version: 8.3.0 and Only RV32I is supported


## Critical path ##
The evaluation of "FETCH_LEN+QUEUE_LEN" number of instructions is the critical path, which will determine how fast CPU core could run. In my evaluation, this core of 3-stage on Altera DE2 level FPGA could reach 50MHz on the worst condition, if "FETCH_LEN+QUEUE_LEN" equals to 4.  

First, you should determine the sum of "FETCH_LEN" and "QUEUE_LEN" according to how many MHz you want to reach. Then, test the effort of different allocation to "FETCH_LEN" and "QUEUE_LEN".

## Status ##
This project is just starting. The "SYS_CSR" module is incomplete because system and CSR-related instructions are not detailed as clearly as other instructions in one pdf. I only supply basic function to cope with simulation tests of SCR1. This part should be developed in the future.

Lack of hardware multiply and divide functions makes its CoreMark score bad. So RV32M should be added to this new super-scalar CPU core.

## How to start ##
Strongly recommend download simulation environment of SCR1. It supply a whole suite  of development. Its link is here: [https://github.com/syntacore/scr1]

In the directory "scr1", I have included its whole source code. You can enter its sub-directory "sim", run "core.do" to build its code, run "ssrv.do" to build my core and testbench file, and run "sim.do" to make two testbench file running simultaneously. 

If you open the definition of "USE_SSRV", SSRV CPU core will take over the authority of imem and dmem bus. SSRV CPU core will replace SCR1 to fulfil simulation tests. You can disable SSRV CPU core through removing the definition of "USE_SSRV".

In "rtl" directory, open the file "define_para.v", you can open it and give you own parameters to make different performance CPU core.

Welcome to my high performance CPU world!!! I need your help to make it more powerful. Feel free to write me: [risclite@gmail.com] 




