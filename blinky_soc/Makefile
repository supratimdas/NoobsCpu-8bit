SHELL = /bin/bash
GEN_FPGA_MEM   = ../utils/gen_fpga_mem.pl
NOOBS_ASM      = ../utils/noobsASM.pl
YOSYS = /usr/local/bin/yosys
##YOSYS = yosys

TARGET ?= lattice

TARGET_STEM = blinky_soc

YOSYS_LOG  = synth.log

YOSYS_ARGS = -v3 -l $(YOSYS_LOG)  -D$(TARGET)=1

VERILOG_SRCS = blinky_soc.v noobs_vlib.v data_mem.v inst_mem.v pll.v baud_rate_gen.v transmitter.v 
##rom_blinky.v rom_blinky_hello_world.v
##VERILOG_SRCS = blinky.v 

ASM_FILE = blinky.asm
DATA_MEM = data_mem.v
INST_MEM = inst_mem.v


data.txt code.txt: $(ASM_FILE)
	$(NOOBS_ASM) $(ASM_FILE)	

$(INST_MEM): code.txt
	$(GEN_FPGA_MEM) -input_file code.txt -type inst -target $(TARGET)

$(DATA_MEM): data.txt
	$(GEN_FPGA_MEM) -input_file data.txt -type data -target $(TARGET)

ifeq ($(TARGET), xilinx)
BIN_FILE  = $(TARGET_STEM).bit
    include nexysa7.mk
else
BIN_FILE  = $(TARGET_STEM).bin
    include icestick.mk
endif


all:	$(BIN_FILE)

