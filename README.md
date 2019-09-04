# SuperScalar-RISCV-CPU
super-scalar out-of-order rv32imc cpu core, 4+ DMIPS/MHz(best performance) 2+ DMIPS/MHz(with noinline option)


## Overview ##

SSRV (SuperScalar RISC-V) is an open-source RV32IMC core, which is superscalar and out-of-order. It is synthesizable  and parameterizable. It is very flexible to customize different performance.


## Principle ##

Thanks to its clear structure, SSRV is a super-efficient machine to dispatch mutiple instructions, which only has 3 stages. In the next diagram, we could see the clear pipeline how SSRV does "super-scalar" and "out-of-order" work. 

The 1st stage: "Fetch": All CPU core will send "PC" address to "instructions memory" .In the next cycle or more, instructions of this address are available on "rdata" bus signals.

The 2nd stage: SSRV will fetch "BUS_LEN" number of 32-bit instructions in one cycle. These instructions and ones stored in "instrbits" before will make up "FETCH_LEN" number of instructions. These "FETCH_LEN" instructions and "SDBUF_LEN" ones stored in "schedule" will be dispatched to "EXEC_LEN" instructions in one cycle.

The 3rd stage: Every instruction in "EXEC" area has its own ALU, which fetch operands  or store "Rd" between "register file", and send memory operation or CSR/mul opertations to "memory buffer". 

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/diagram.png)

## Benchmark ##

This project is inspired and based on Syntacore's core: SCR1 [https://github.com/syntacore/scr1]. Syntacore supplies "riscv_isa", "riscv_compliance", "coremark" and "dhrystone21" simulation tests. So, the basic benchmark scores could be listed here:

|EXEC_LEN       | Best performance(DMIPS/MHz) | -O3 -noinline Option(DMIPS/MHz) |
| ------------- | --------------------------- | ------------------------------- |
|1              |2.96                         | 1.51                            |
|2              |3.65                         | 2.00                            |
|3              |3.87                         | 2.10                            |
|4              |3.95                         | 2.18                            |


--RISCV gcc version: 8.3.0 
--RV32IMC

## Status ##
Based on mult-in mult-out buffers. There are 4 buffers in SSRV, each of which could be customized and have different performance.

Add Chinese help wiki [中文维基](https://github.com/risclite/SuperScalar-RISCV-CPU/wiki/ChineseWiki)

## How to start ##
Strongly recommend download simulation environment of SCR1. It supply a whole suite  of development. Its link is here: [https://github.com/syntacore/scr1]

In the directory "scr1", I have included its whole source code. You can enter its sub-directory "sim", run "compile.do" to compile source files of SCR1 and this core, and run "sim.do" to make two testbench file running simultaneously. 

In "rtl" directory, open the file "define_para.v", you can give you own parameters to make different performance CPU core. 

If you open the definition of "USE_SSRV", SSRV CPU core will take over the authority of imem and dmem bus. SSRV CPU core will replace SCR1 to fulfil simulation tests. You can disable SSRV CPU core through removing the definition of "USE_SSRV".

In "build" directory, "test_info" will list hex files and you can use "#" to exclude some you do not want to run.

Welcome to my high performance CPU world!!! 

[lixinbingg@163.com] 




