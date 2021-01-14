TB_FILES += tb_top.v

TB_TOP := tb_top

VERILOG_COMPILER := iverilog
COMPILER_OPTS := -Wall -v  -I../vmodel

.PHONY:

compile:
	iverilog $(COMPILER_OPTS) $(TB_FILES) -s $(TB_TOP) -o vsim.out

run:
	cp ../utils/*.txt ./
	./vsim.out	

waves:
	gtkwave test.vcd

clean:
	rm -f  *.out *.vcd *.txt
