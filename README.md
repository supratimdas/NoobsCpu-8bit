# NoobsCpu-8bit
# This is a simple TOY 8bit cpu architecture for fun as a side project
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
    |---utils   : A simple 2-pass assembler written in perl for the NoobsCpu-ISA, example codes
    |
    |---tests   : collection of tests, and scripts to run them on cmodel and RTL


WHAT's required to run this?
this is completely based on opensource tools freely available.
Ensure you have the following installed in your system:
1. GCC toolchain: the cmodel is written in C. so in order to compile it you need gcc, or some other C compiler.
2. iverilog: for simulating the RTL, iverilog is used, so you'll need that
3. GTKWave: GTKWave is a opensource waveform viewer, which can be used to view/debug from vcd wavedumps, the tb produces for each test
4. perl: the assembler is written in perl, so you'll need that
5. YOSYS: will be using YOSYS for synthesis

/*Notes*/
3/25/2019: 
replaced MUL instruction with SUB.
Implemented almost entirely the entire instruction set in cmodel
updated the ISA, changed program/data space from 4K to 2K

3/26/2019:
A simple 2 pass assembler written in perl for the CPU.

1/14/2021:
basic tb infra, and cleanup

1/15/2021:
setup of test running infra
1st test up, basic load from memory, store to memory

2/06/2021:
all basic features coded, and verified.
</pre>
