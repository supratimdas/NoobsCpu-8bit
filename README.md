# NoobsCpu-8bit
# This is a simple TOY (barebones) 8bit cpu architecture for fun as a side project
# Intent was to capture the entire frontend Design+Verif flow for educational purpose
<pre>
this has a complete c-model/v-model/assembler/synthesis scripts for ice40 fpga

long term, I'd like to add simple peripherals around it such as uart/spi and treat it as simple mcu, running a simple game


Directory Structure:
NoobsCpu-8bit/
    |
    |---cmodel  : a cycle accurate c functional model for the cpu
    |
    |---Doc     : documentation/scratch work while working on the project. The start was with an xls file that briefly captures the ISA
    |
    |---vmodel  : verilog RTL for the processor.
    |
    |---tb      : verilog based testbench
    |
    |---utils   : A simple 2-pass assembler written in perl for the NoobsCpu-ISA. a bram based memory generator+initializer for ice40 FPGA
    |
    |---tests   : collection of tests, and scripts to run them on cmodel and RTL
    |
    |---blinky_soc  : a simple soc/uController implementation with NoobsCpu core and 1 LED as GPIO + UART TX


WHAT's required to run this?
this is completely based on opensource tools freely available.
Ensure you have the following installed in your system:
1. GCC toolchain: the cmodel is written in C. so in order to compile it you need gcc, or some other C compiler.
2. iverilog: for simulating the RTL, iverilog is used, so you'll need that
3. GTKWave: GTKWave is a opensource waveform viewer, which can be used to view/debug from vcd wavedumps, the tb produces for each test
4. perl: the assembler is written in perl, so you'll need that. + also used for a fpga_bram generator, for ice40 fpga
5. YOSYS: will be using YOSYS for synthesis

</pre>

# Basic Highlights
# 1. 8 bit data path
# 2. 3 stage pipeline
# 3. Harvard Architecure (Separate Inst/Data memory)
# 4. 2 KB addressable Instruction/Data Memory
# 5. 4 General purpose registers
# 6. Support for Direct/Indirect addressing modes
# 7. Memory mapped IO
# 8. has 8 user-configurable reserved opcodes (Can be used as a great teaching tool to implement interesting operations)
