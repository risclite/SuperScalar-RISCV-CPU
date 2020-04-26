# SuperScalar-RISCV-CPU

SSRV(Super-Scalar RISC-V) --- Super-scalar out-of-order RV32IMC CPU core,  performance: 6.0 CoreMark/MHz.

## Overview ##

SSRV is an open-source RV32IMC CPU core. It is synthesizable and parameterizable. You can define different configuration scheme to get different performance,  which ranges within 2.9-6.4 CoreMark/MHz, 2.6-4.9 DMIPS/MHz(best) and 1.5-2.8 DMIPS/MHz(legal). The recommended configuration scheme of 6.0 CoreMark/MHz could have Fmax: 30MHz on an Intel DE2-115 FPGA board. 

## Feature ##

* Configurable 4 to 5 stage pipeline implementation

* 4 chained parameterized buffers, configurable sizes and ports

* Its instruction set is RV32IMC.

* Synthesizable verilog description.

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/diagram.png)

To define 4 chained buffers is an easy way to get a configuration scheme, which accommodates instructions in flight. Let's set N as a number of instruction parallelism. The below lists give each buffer these parameters as "input size, capacity size, output size".

* The instrbits buffer: N\*32 bits,  3\*N\*32 bits, N instr(Only output is indentified as instr)

* The schedule buffer: N instr, 2\*N instr, N instr(means N ALUs)

* The membuf buffer: N instr, 2\*N instr, 1 instr(fixed, only one data memory interface)
	
* The mprf buffer: N instr, 2\*N instr, N instr
	
|N            |	CoreMark ticks |CoreMark/MHz(estimated) |	DMIPS/MHz(best) |	DMIPS/MHz(legal)   |
|-------------|----------------|------------------------|-------------------|----------------------|
|    16       | 1567           |  6.38                  |    4.94           | 2.82                 |
|     8       | 1583           |  6.32                  |    4.94           | 2.79                 |
|     4       | 1646           |  6.08                  |    4.82           | 2.75                 |
|     2       | 2072           |  4.83                  |    4.24           | 2.39                 |
|     1       | 3452           |  2.90                  |    2.67           | 1.48                 |

--RISCV gcc version: 8.3.0


## Structure ##

SSRV is inspired by and based on [SCR1](https://github.com/syntacore/scr1) of Syntacore. If you need a total solution to simulation and development, you should download the package of SCR1.

    rtl/ ------------------------ the core verilog RTL code    
        ssrv_top.v     ------------------------Top level
          |---- instrman.v
          |---- instrbits.v
          |---- predictor.v
          |---- schedule.v
          |---- alu.v
          |---- mprf.v
          |---- membuf.v
          |---- mul.v
          |---- sys_csr.v
        
        define.v       ------------------------ the defination verilog file
        define_para.v  ------------------------ project parameter verilog file
        include_func.v ------------------------ common function verilog file

    scr1/  ------------------------ the scr1 code and simulation starting directory.  
      |---build/    ------------------------ compiled test hex/elf/dump files. 
      |---src/      ------------------------ The RTL and testbench files of SCR1. 
      |---sim/      ------------------------ Simulation starting directory. 

    ssrv-on-scr1/   ------------------------  A FPGA implementation of SSRV based on SCR1
       |--- fpga/   ------------------------  The Quartus project files on the DE2-115 development kit.
       |--- sim/    ------------------------  A simulation package on this FPGA implementation.

    testbench
       |--- tb_ssrv.v ------------------------ A testbench file to instantiate SSRV.

## Simulation ##

Go to the directory: "scr1/sim/". Two .do files: "compile.do" and "sim.do" could be evoked by Modelsim/QuestaSim directly. If you use the other simulator, please open compile.do and get the file list of the whole files. Compile them and have a run.

Please open "rtl/define_para.v" and give your parameters of 4 chained buffers.

Please open "scr1/build/test_info". Add your test cases and you can use "#" to exclude some you do not want to run.

## FPGA evaluation ##

Go to the directory: ssrv-on-scr1. If you need a simulation close to this FPGA implementation, the sub-directory sim/ could do that. If you need a review of the FPGA project, the sub-directory fpga/ could give you an example. 

![hierarchy](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/hierarchy.png)

![fpga](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/fpga.PNG)


## Help and Suggestion ##

[English](https://risclite.github.io/)        

[中文](https://github.com/risclite/SuperScalar-RISCV-CPU/wiki/中文帮助维基)  
  
Email: lixinbingg@163.com








