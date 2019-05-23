vsim -gui work.scr1_top_tb_ahb ssrv.tb_ssrv -L ssrv -voptargs=+acc \
	+test_info=../build/test_info \
	+test_results=../build/test_results.txt \
	+imem_pattern=FFFFFFFF \
	+dmem_pattern=FFFFFFFF 