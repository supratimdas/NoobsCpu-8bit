VLIB := asserts.v

RTL_FILES := ifetch.v
RTL_FILES += idecode.v
RTL_FILES += register_file.v
RTL_FILES += execute.v
RTL_FILES += noobs_cpu.v

VERILOG_COMPILER := iverilog
COMPILER_OPTS := -Wall -DDEBUG_PRINT=0

.PHONY: compile

compile:
	iverilog $(COMPILER_OPTS) $(RTL_FILES) $(VLIB)

clean:
	rm -f *.blif *.txt *.ex *.bin *.out
