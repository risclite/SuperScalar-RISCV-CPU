# SuperScalar-RISCV-CPU

SSRV(Super-Scalar RISC-V) --- Super-scalar out-of-order RV32IMC CPU core,  performance: 6.4 CoreMark/MHz.

## Feature ##

* Its instruction set is RV32IMC.

* Synthesizable verilog description.

![diagram](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/png/diagram.png)

SSRV is an instruction set processing architecture for RV32IMC. Its main architecture is four buffers linked together, with an instruction bus configured as 32\*N bit and a fixed 32 bit data bus. It has corresponding performance as long as the following parameters are configured:

* INSTR_MISALLIGNED --- Whether the instruction bus is in misaligned mode.

* FETCH_REGISTERED --- Whether the first buffer registers its output.

* MULT_NUM --- The number of hardware MUL/DIV modules.

* The ‘instrbits’ buffer --- （input/capacity/output）

* The ‘schedule’ buffer --- （input/capacity/output）

* The ‘membuf’ buffer --- （input/capacity/output）

* The ‘mprf’ buffer --- （input/capacity/output）
	
|Configuration                        |CoreMark/MHz            |   DMIPS/MHz(best) | DMIPS/MHz(legal)     |
|-------------------------------------|------------------------|-------------------|----------------------|
|Yes Yes 3 4-8-4 6-3 8-2 8-3          |  6.4                   |    4.8            | 2.8                  |
|No  Yes 3 4-8-4 6-3 8-2 8-3          |  6.2                   |    4.8            | 2.7                  |
|No  Yes 1 4-8-4 6-3 8-2 8-3          |  5.8                   |    4.8            | 2.7                  |
|No  No  1 1-2-1 2-1 2-1 2-1          |  2.9                   |    2.7            | 1.5                  |
|No  No  1 2-4-2 4-2 4-2 4-2          |  4.9                   |    4.3            | 2.5                  |
|Yes Yes 2 2-4-2 4-2 4-2 4-2          |  5.1                   |    4.3            | 2.5                  |
|Yes Yes 4 4-8-4 8-4 8-4 8-4          |  6.4                   |    4.8            | 2.8                  |
|Yes Yes 8 8-16-8 16-8 16-8 16-8      |  6.6                   |    5.0            | 2.8                  |
|Yes Yes 16 16-32-16 32-16 32-16 32-16|  6.6                   |    5.0            | 2.8                  |

--RISCV gcc version: 8.3.0

The above parameters can be configured arbitrarily to run the simulation. However, in FPGA synthesis, appropriate parameters must be selected to satisfy the timing requirement. Here are examples of configuration and timing on the DE2-115 FPGA development board:

|Configuration                        |CoreMark/MHz            |  Fmax(Slow model) | Logic ratio          |
|-------------------------------------|------------------------|-------------------|----------------------|
|SCR1  with fast MUL                  |  2.1                   |    34.0 MHz       | 5%                   |
|SCR1  without fast MUL               |  1.3                   |    30.7 MHz       | 5%                   |
|No  No  1 1-2-1 2-1 2-1 2-1          |  2.9                   |    32.6 MHz       | 12%                  |
|Yes Yes 2 2-4-2 4-2 4-2 4-2          |  4.9                   |    32.1 MHz       | 19%                  |
|Yes Yes 2 4-7-3 6-3 6-2 6-2          |  6.0                   |    29.2 MHz       | 31%                  |

This is my favorite configuration: " Yes Yes 3 4-8-4 6-3 8-2 8-3", which is at the critical point of synthesizable and high performance.
For more information, please download the Chinese guide: ![PDF](https://github.com/risclite/SuperScalar-RISCV-CPU/blob/master/wiki/SSRV%E5%85%A8%E8%A7%A3%E6%9E%90.pdf). Or,add my WeChat: rvlite and have a discussion.



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
	  |---- lsu.v
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








