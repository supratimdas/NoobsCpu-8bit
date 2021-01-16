ASSEMBLER = ../utils/noobsASM.pl 
CMODEL = ../cmodel/noobsCpu
VSIM = ../tb/vsim.out

SOURCE ?= test.asm

.PHONY: assemble clean 

all: exec_cmodel exec_vmodel

assemble: $(SOURCE)
	$(ASSEMBLER) $(SOURCE) 

exec_cmodel: assemble
	$(CMODEL)
	mv data_out.txt data_out_cmodel.txt
	
exec_vmodel: assemble
	$(VSIM)
	mv data_out.txt data_out_vmodel.txt

waves:
	gtkwave test.vcd


clean: 
	rm *.txt *.vcd
