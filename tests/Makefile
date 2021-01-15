ASSEMBLER = ../utils/noobsASM.pl 

SOURCE ?= test.asm

.PHONY: assemble clean 

assemble: $(SOURCE)
	$(ASSEMBLER) $(SOURCE) 

clean: 
	rm *.txt *.vcd
