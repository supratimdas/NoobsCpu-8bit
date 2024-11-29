FASM_FILE = $(TARGET_STEM).fasm 
JSON_FILE = $(TARGET_STEM).json
FRAMES_FILE = $(TARGET_STEM).frames
CHIP_DB = xc7a100t.bin
XDC_FILE = pins_xilinx_nexysA7.xdc
XRAY_DIR=/home/supratimd/prjxray
UTILS_DIR=../utils
CHIP_DB_DIR=../artix7

$(JSON_FILE) : $(VERILOG_SRCS)
	$(YOSYS) $(YOSYS_ARGS) -p "synth_xilinx -flatten -arch xc7 -top blinky_soc; write_json $(TARGET_STEM).json " $(VERILOG_SRCS)

$(FASM_FILE) : $(JSON_FILE) $(CHIP_DB) $(XDC_FILE)  
	nextpnr-xilinx  --chipdb $(CHIP_DB) --xdc $(XDC_FILE) --json $(TARGET_STEM).json --write $(TARGET_STEM)_routed.json --fasm $(FASM_FILE) 

$(FRAMES_FILE):	$(FASM_FILE)
	${UTILS_DIR}/fasm2frames.py --part xc7a100tcsg324-1 --db-root ${CHIP_DB_DIR} $(FASM_FILE) > $(FRAMES_FILE)

$(BIN_FILE): $(FRAMES_FILE)
	${UTILS_DIR}/xc7frames2bit --part_file ${CHIP_DB_DIR}/xc7a100tcsg324-1/part.yaml --part_name xc7a100tcsg324-1  --frm_file $(FRAMES_FILE) --output_file $(BIN_FILE)

clean:
	rm -f $(BIN_FILE) $(FRAMES_FILE) $(YOSYS_LOG) $(DATA_MEM) $(INST_MEM) *.txt *.json $(FASM_FILE)

.PHONY:	all clean prog 
