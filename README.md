# SuperScalar-RISCV-CPU
super-scalar out-of-order rv32imc cpu core, 4+ DMIPS/MHz(best performance) 2+ DMIPS/MHz(with noinline option)


## Overview ##

SSRV (SuperScalar RISC-V) is an open-source RV32IMC core, which is superscalar and out-of-order. It is synthesizable  and parameterizable. It has outstanding integer processing ability: DMIPS/MHz : 4.2/4.0 (2/3-stage, without -fno-inline compiler options); 2.3/2.1 (2/3-stage,-O3 -fno-inline). It is very flexible to customize different performance.


## Principle ##

Thanks to its clear structure, SSRV is a super-efficient machine to dispatch mutiple instructions, which only has 2 or 3 stages. In the next diagram, we could see the clear pipeline how SSRV does "super-scalar" and "out-of-order" work. 

The 1st stage: "Fetch": All CPU core will send "PC" address to "instructions memory" .In the next cycle or more, instructions of this address are available on "rdata" bus signals.

The 2nd stage: SSRV will fetch "BUS_LEN" number of 32-bit instructions in one cycle. These instructions and ones stored in "BUFFER" before will make up "FETCH_LEN" number of instructions. 

We always  know there is data dependency of instructions, which will make some instruction will not be issued to "execute" stage. For a pessimist, it is a bad luck to have an instruction that could not be executed; but for an optimist, it is a good luck because in the very next cycle, the same instruction will have more possibility to be executed than others. So, one of "FETCH_LEN" number of instructions will have two destinies, go to "EXEC_LEN" number of "EXEC" area to be executed; or go to "QUEUE_LEN" number of "QUEUE" area to be the top list of ones evaluated in the next cycle.

Note that: instructions in "QUEUE" area are not execuated but treated as being execuated. Instructions behind these could be issued when they are not writing to source or destination registers of all "QUEUE" instructions.

If it is a configuration of 3-stage, all "EXEC_LEN" instructions are registered, or they are delivered directly.

The 3rd stage: Every instruction in "EXEC" area has its own ALU, which fetch operands  or store "Rd" between "register file", and send memory operation to "memory buffer". The last ALU will share its channel to "register file" with "SYS_CSR", which is dedicated to system or CSR-related instructions.  

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/diagram.png)

## Benchmark ##

This project is inspired and based on Syntacore's core: SCR1 [https://github.com/syntacore/scr1]. Syntacore supplies "riscv_isa", "riscv_compliance", "coremark" and "dhrystone21" simulation tests. So, the basic benchmark scores could be listed here:


|               |SCR1           | SSRV(3-stage) FETCH_LEN=1 QUEUE_LEN=1 EXEC_LEN=1 |SSRV(3-stage) FETCH_LEN=2 QUEUE_LEN=2 EXEC_LEN=2 | SSRV(3-stage) FETCH_LEN=3 QUEUE_LEN=2 EXEC_LEN=3  | SSRV(2-stage) FETCH_LEN=2 QUEUE_LEN=2 EXEC_LEN=2 | SSRV(2-stage) FETCH_LEN=3 QUEUE_LEN=2 EXEC_LEN=3 |
| ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
| DMIPS/MHz:(-O3 -fno-inline) | 1.14 |1.51 <br> (parallel ratio: 0----12%<br> 1----88%) |2.01 <br> (parallel ratio: <br> 0----17% <br> 1----48% <br> 2----35%) | 2.13 <br> (parallel ratio: 0----20% <br> 1----46% <br> 2----22% <br> 3----12%) |  2.21 <br> (parallel ratio: <br> 0----11% <br> 1----49% <br> 2----40%) | 2.35 <br> (parallel ratio: <br> 0----14% <br> 1----49% <br> 2----23% <br> 3----14%) |
| DMIPS/MHz:(default of SCR1) | 1.93 |2.95 <br> (parallel ratio: 0----8%<br> 1----92%) | 3.74 <br> (parallel ratio: <br> 0----14% <br> 1----54% <br> 2----32%) | 4.01 <br> (parallel ratio: <br> 0----16% <br> 1----51% <br> 2----24% <br> 3----9%) |  3.98 <br> (parallel ratio: <br> 0----9% <br> 1----57% <br> 2----34%) | 4.25 <br> (parallel ratio: <br> 0----13% <br> 1----52% <br> 2----25% <br> 3----10%) |
| ticks per iteration of CoreMark(default of SCR1) | 3621 | 3585 <br> (parallel ratio: 0----21%<br> 1----79%) |2862 <br> (parallel ratio: <br> 0----28% <br> 1----46% <br> 2----26%) | 2793 <br> (parallel ratio: <br> 0----32% <br> 1----42% <br> 2----18% <br> 3----8%) | 2550 <br> (parallel ratio: <br> 0----19% <br> 1----51% <br> 2----30%) | 2482 <br> (parallel ratio: <br> 0----24% <br> 1----47% <br> 2----20% <br> 3----9%) |

--RISCV gcc version: 8.3.0 


## Critical path ##
The evaluation of "FETCH_LEN+QUEUE_LEN" number of instructions is the critical path, which will determine how fast CPU core could run. In my evaluation, this core of 3-stage on Altera DE2 level FPGA could reach 50MHz on the worst condition, if "FETCH_LEN+QUEUE_LEN" equals to 4.  

First, you should determine the sum of "FETCH_LEN" and "QUEUE_LEN" according to how many MHz you want to reach. Then, test the effort of different allocation to "FETCH_LEN" and "QUEUE_LEN".

## Status ##
This project is just starting. The "SYS_CSR" module is incomplete because system and CSR-related instructions are not detailed as clearly as other instructions in one pdf. I only supply basic function to cope with simulation tests of SCR1. This part should be developed in the future.

RV32M and RV32C are added and could be customized.


## How to start ##
Strongly recommend download simulation environment of SCR1. It supply a whole suite  of development. Its link is here: [https://github.com/syntacore/scr1]

In the directory "scr1", I have included its whole source code. You can enter its sub-directory "sim", run "compile.do" to compile source files of SCR1 and this core, and run "sim.do" to make two testbench file running simultaneously. 

In "rtl" directory, open the file "define_para.v", you can give you own parameters to make different performance CPU core. 

If you open the definition of "USE_SSRV", SSRV CPU core will take over the authority of imem and dmem bus. SSRV CPU core will replace SCR1 to fulfil simulation tests. You can disable SSRV CPU core through removing the definition of "USE_SSRV".

In "build" directory, "test_info" will list hex files and you can use "#" to exclude some you do not want to run.

Welcome to my high performance CPU world!!! 

[risclite@gmail.com] 




