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

/*Notes*/
3/25/2019: 
replaced MUL instruction with SUB.
Implemented almost entirely the entire instruction set in cmodel
updated the ISA, changed program/data space from 4K to 2K
</pre>
