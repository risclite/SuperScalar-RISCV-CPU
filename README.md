# SuperScalar-RISCV-CPU
super-scalar out-of-order rv32imc cpu core, 4+ DMIPS/MHz(best performance) 2+ DMIPS/MHz(with noinline option)

A tutorial on SSRV is here: [tutorial](https://risclite.github.io/)------------Chinese version : [中文教程](https://github.com/risclite/SuperScalar-RISCV-CPU/wiki/中文帮助维基).

## Overview ##

SSRV (SuperScalar RISC-V) is an open-source RV32IMC core, which is superscalar and out-of-order. It is synthesizable  and parameterizable. It is very flexible to customize different performance.


## Principle ##

SSRV is a 3-stage RV32IMC CPU core. Different from rivals, SSRV is configurable to adjust levels of out-of-order and super-scalar via 3 parameters. Besides these 3 ones, there are more parameters to effect performance.

SSRV is based on 4 different multiple-in, multiple-out buffers connected with each other. The central of them is built in “schedule” module, which has “FETCH_LEN” inputs, “EXEC_LEN” outputs and a capacity of “SDBUF_LEN” instructions.

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/diagram.png)

If these 3 parameters are given different values, this core will show different Dhrystone Benchmark scores. The next table will list how these key parameters produce different performance cores.

|FETCH_LEN--SDBUF_LEN--EXEC_LEN |	DHRY(best) |	DMIPS/MHz(best) |	DHRY(legal) |	DMIPS/MHz(legal)   |
|-------------------------------|------------|------------------|-------------|--------------------|
|1—1—1                          |5205	       |2.96              |2645	        |1.51                |
|1—2—1 	                        |5205	       |2.96	            |2659	        |1.51                |
|2—2—2 	                        |6366	       |3.62	            |3344	        |1.90                |
|2—3—2	                        |6407	       |3.65	            |3471	        |1.98                |
|2—4—2	                        |6407	       |3.65	            |3520	        |2.00                |
|2—6—2	                        |6407	       |3.65	            |3533	        |2.01                |
|3—3—3	                        |6708	       |3.82	            |3689	        |2.10                |
|3—4—3	                        |6753	       |3.84	            |3758	        |2.14                |
|3—6—3	                        |6799	       |3.87	            |3787	        |2.16                |
|4—4—4	                        |6893	       |3.92	            |3758	        |2.14                |
|4—5—4	                        |6941	       |3.95	            |3801	        |2.16                |
|4—6—4	                        |6941	       |3.95	            |3816	        |2.17                |
|8—16—8	                        |7038	       |4.01	            |3906	        |2.22                |
|16—32—16	                      |7038	       |4.01	            |3921	        |2.23                |

“EXEC_LEN” is a parameter of super-scalar, which determines how many ALUs are instantiated to execute instructions in the same cycle. “SDBUF_LEN” is a parameter of out-of-order, which means how many instructions are evaluated to present “EXEC_LEN” instructions, the bigger it is, the more possibility to stuff ALUs. 

More than that, these 3 parameters can be random integer. There is a status report when all are assigned to 16. It is obvious that SSRV is a robust solution of out-of-order and super scalar.

    ticks =      261273  instructions =      282644  I/T = 1.081796
          NUM          TICKS       RATIO
            0 --       87638 -- 0.335427 
            1 --      108594 -- 0.415634 
            2 --       37830 -- 0.144791 
            3 --       19693 -- 0.075373 
            4 --        3562 -- 0.013633 
            5 --        1793 -- 0.006863 
            6 --         949 -- 0.003632 
            7 --         566 -- 0.002166 
            8 --         110 -- 0.000421 
            9 --          58 -- 0.000222 
           10 --         360 -- 0.001378 
           11 --          88 -- 0.000337 
           12 --           0 -- 0.000000 
           13 --          12 -- 0.000046 
           14 --           0 -- 0.000000 
           15 --           4 -- 0.000015 
           16 --          16 -- 0.000061 

All files of SSRV are synthesizable and aimed to provide a high-performance core for ASIC and FPGA. Except for a file “sys_csr.v”, which is related to interrupt/exception and system control, others could be unmodified to be instantiated as sub-modules.

If you want to utilize SSRV to build a high-performance CPU core of your own, just modify “sys_csr.v” to have your own system control solution and combine that with other files to be your high-performance core. You are free to choose appropriate parameters, which will give your balance between performance and logic cell cost.



## Benchmark ##

This project is inspired and based on Syntacore's core: [SCR1](https://github.com/syntacore/scr1). Syntacore supplies "riscv_isa", "riscv_compliance", "coremark" and "dhrystone21" simulation tests. So, the basic benchmark scores could be listed here:

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

Add Chinese help wiki [中文维基](https://github.com/risclite/SuperScalar-RISCV-CPU/wiki/中文帮助维基)

## How to start ##
Strongly recommend download simulation environment of [SCR1](https://github.com/syntacore/scr1). It supply a whole suite  of development.

In the directory "scr1", I have included its whole source code. You can enter its sub-directory "sim", run "compile.do" to compile source files of SCR1 and this core, and run "sim.do" to make two testbench file running simultaneously. 

In "rtl" directory, open the file "define_para.v", you can give you own parameters to make different performance CPU core. 

If you open the definition of "USE_SSRV", SSRV CPU core will take over the authority of imem and dmem bus. SSRV CPU core will replace SCR1 to fulfil simulation tests. You can disable SSRV CPU core through removing the definition of "USE_SSRV".

In "build" directory, "test_info" will list hex files and you can use "#" to exclude some you do not want to run.

[lixinbingg@163.com] 




