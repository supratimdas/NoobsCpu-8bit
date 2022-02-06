ARACHNE_DEVICE = 1k
PACKAGE        = tq144

ICETIME_DEVICE = hx1k

PROG_BIN       = iceprog
GEN_FPGA_MEM   = ../utils/gen_fpga_mem.pl
NOOBS_ASM      = ../utils/noobsASM.pl

TARGET_STEM = blinky_soc

PINS_FILE = pins.pcf

YOSYS_LOG  = synth.log

YOSYS_ARGS = -v3 -l $(YOSYS_LOG) 

VERILOG_SRCS = blinky_soc.v noobs_vlib.v data_mem.v inst_mem.v pll.v baud_rate_gen.v transmitter.v rom_blinky.v rom_blinky_hello_world.v

BIN_FILE  = $(TARGET_STEM).bin
ASC_FILE  = $(TARGET_STEM).asc
BLIF_FILE = $(TARGET_STEM).blif
ASM_FILE = blinky.asm
DATA_MEM = data_mem.v
INST_MEM = inst_mem.v

all:	$(BIN_FILE)

data.txt code.txt: $(ASM_FILE)
	$(NOOBS_ASM) $(ASM_FILE)	

$(INST_MEM): code.txt
	$(GEN_FPGA_MEM) -input_file code.txt -type inst

$(DATA_MEM): data.txt
	$(GEN_FPGA_MEM) -input_file data.txt -type data

$(BIN_FILE):	$(ASC_FILE)
	icepack	$< $@

$(ASC_FILE):	$(BLIF_FILE) $(PINS_FILE)
	arachne-pnr -d $(ARACHNE_DEVICE) -P $(PACKAGE) -o $(ASC_FILE) -p $(PINS_FILE) $<

$(BLIF_FILE):	$(VERILOG_SRCS)
	yosys $(YOSYS_ARGS) -p "synth_ice40 -blif $(BLIF_FILE)" $(VERILOG_SRCS)

prog:	$(BIN_FILE)
	$(PROG_BIN) $<

timings:$(ASC_FILE)
	icetime -tmd $(ICETIME_DEVICE) $<

clean:
	rm -f $(BIN_FILE) $(ASC_FILE) $(BLIF_FILE) $(YOSYS_LOG) $(DATA_MEM) $(INST_MEM) *.txt 

.PHONY:	all clean prog timings


