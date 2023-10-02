ASSEMBLER = ../utils/noobsASM.pl 
CMODEL = ../cmodel/noobsCpu
VSIM = ../tb/vsim.out

SOURCE ?= test.asm
DEBUG ?= 1

.PHONY: assemble clean 

all: exec_cmodel exec_vmodel

$(CMODEL):
	make -C ../cmodel

$(VSIM):
	make -C ../tb/ DEBUG=$(DEBUG)

assemble: $(SOURCE)
	$(ASSEMBLER) $(SOURCE) 

exec_cmodel: $(CMODEL) assemble
	export NOOBS_DEBUG=$(DEBUG)
	$(CMODEL)
	mv data_out.txt data_out_cmodel.txt
	
exec_vmodel: $(VSIM) assemble
	$(VSIM)
	mv data_out.txt data_out_vmodel.txt

waves:
	gtkwave test.vcd


clean: 
	rm *.txt *.vcd
	make -C ../cmodel clean
	make -C ../tb clean
