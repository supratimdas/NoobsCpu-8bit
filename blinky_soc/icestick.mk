ARACHNE_DEVICE = 1k
PACKAGE        = tq144
ICETIME_DEVICE = hx1k
PROG_BIN       = iceprog
PINS_FILE = pins.pcf
ASC_FILE  = $(TARGET_STEM).asc
BLIF_FILE = $(TARGET_STEM).blif


$(BIN_FILE):	$(ASC_FILE)
	icepack	$< $@

$(ASC_FILE):	$(BLIF_FILE) $(PINS_FILE)
	arachne-pnr -d $(ARACHNE_DEVICE) -P $(PACKAGE) -o $(ASC_FILE) -p $(PINS_FILE) $<

$(BLIF_FILE):	$(VERILOG_SRCS)
	$(YOSYS) $(YOSYS_ARGS) -p "synth_ice40 -blif $(BLIF_FILE)" $(VERILOG_SRCS)

prog:	$(BIN_FILE)
	$(PROG_BIN) $<

timings:$(ASC_FILE)
	icetime -tmd $(ICETIME_DEVICE) $<

clean:
	rm -f $(BIN_FILE) $(ASC_FILE) $(BLIF_FILE) $(YOSYS_LOG) $(DATA_MEM) $(INST_MEM) *.txt 

.PHONY:	all clean prog timings
