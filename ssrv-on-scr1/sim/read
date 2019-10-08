*  sim/

    It likes the simulation environment of SSRV, but the difference is that the instruction bus bit width is fixed to 32 bit and could not be adjusted to other values. 

    The simulation could be switched from SSRV to SCR1 by commenting the verilog defination "USE_SSRV" of "rtl/define_para.v".

    *  rtl/
    
    "ssrv_pipe_top.sv" instantiates "ssrv_top" and " scr1_pipe_csr". It is the top module of SSRV CPU core. You can treat "rtl/" as a whole set of SSRV CPU core.

    *  scr1/
    
    This directory is inherited from SCR1, which provides a whole simulation package.

        build/ --- compiled hex/elf/dump files

        src/ --- source files of SCR1, which includes RTL and testbench files.

        sim/ --- where to start simulation and compile work library.

    Just enter sim/scr1/sim/ and run "compile.do" and "sim.do". 
