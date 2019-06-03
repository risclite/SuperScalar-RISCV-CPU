A successful simulation includes two step: 1, compile all source files; 2, find top testbench files and run simulation command to them.
There are two "do" files：compile.do--do the first thing; sim.do--run siumlation command for testbench files. 
These two "do" files are aimed to the simulation tool: MODELSIM. If you use different tools, please modify them manually. There are some tips here:
1, compile.do
  ---Two included directories: ../src/includes/ （SCR1) ../../rtl/ (This core)
  ---tb_ssrv.v is a link file between SCR1 and this core. Files in "rtl" directory are synthesizable.
2, sim.do
  --- scr1_top_tb_ahb: testbench file of SCR1. SCR1 may have another testbench file: scr1_top_tb_axi.sv, aimed to AXI interface. This AXI top file is not modified to suit this core. If you want to use it, you should reference to "scr1_top_tb_ahb.sv" and modify it manually.
  ---tb_ssrv: testbench file of this core. It does not work individually. It should go with SCR1's simulation environment.