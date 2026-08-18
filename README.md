# NoobsCpu — An 8-bit Homebrew CPU

![NoobsCPU Block Diagram](https://github.com/supratimdas/NoobsCpu-8bit/raw/master/NoobsCPU.png?raw=true)

A complete, from-scratch 8-bit CPU built as an educational side project — featuring a hand-written assembler, a cycle-accurate C functional model, synthesisable Verilog RTL, a self-checking testbench, and two real SoC examples running on FPGA. The intent is to capture the **entire front-end design and verification flow** in a single, self-contained repo.

---

## Table of Contents

- [Highlights](#highlights)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
  - [Pipeline](#pipeline)
  - [Registers](#registers)
  - [Memory](#memory)
  - [Status Flags](#status-flags)
  - [Addressing Modes](#addressing-modes)
- [Assembly Language Reference](#assembly-language-reference)
  - [Program Structure — .data and .code Sections](#program-structure--data-and-code-sections)
  - [Instruction Set](#instruction-set)
- [Building and Running](#building-and-running)
  - [Running the Test Suite](#running-the-test-suite)
  - [Assembling a Program](#assembling-a-program)
  - [Running on the C Model](#running-on-the-c-model)
  - [Running RTL Simulation](#running-rtl-simulation)
  - [FPGA Synthesis](#fpga-synthesis)
- [Example Programs](#example-programs)
- [Gallery](#gallery)
- [Roadmap](#roadmap)
- [ERRATA](#errata)

---

## Highlights

| Feature | Detail |
|---|---|
| Data width | 8-bit |
| Pipeline depth | 3 stages (Fetch → Decode → Execute) |
| Memory architecture | Harvard (separate instruction and data buses) |
| Instruction memory | 2 KB (12-bit address) |
| Data memory | 2 KB (12-bit address) |
| General purpose registers | 4 × 8-bit (R0 – R3) |
| Addressing modes | Direct and indirect (register-indexed) |
| I/O | Memory-mapped |
| Configurable opcodes | 8 user-definable reserved opcodes |
| FPGA targets | Lattice iCE40 (iCEStick), Xilinx Artix-7 (Nexys A7) |

---

## Repository Structure

```
NoobsCpu-8bit/
├── cmodel/           Cycle-accurate C functional model
├── vmodel/           Synthesisable Verilog RTL
│   ├── ifetch.v      Stage 1 – Instruction Fetch
│   ├── idecode.v     Stage 2 – Instruction Decode
│   ├── execute.v     Stage 3 – Execute
│   ├── register_file.v
│   ├── noobs_cpu.v   Top-level CPU module
│   └── noobs_cpu_defines.vh  ISA constants and macros
├── tb/               Verilog testbench (produces .vcd waveforms)
├── utils/
│   ├── noobsASM.pl   2-pass assembler (Perl)
│   └── gen_fpga_mem.pl  BRAM initialiser for iCE40 / Artix-7
├── tests/            25+ self-checking assembly tests + run scripts
├── blinky_soc/       SoC: LED blinky + "Hello World" over UART TX
├── tic_tac_toe_soc/  SoC: Tic-tac-toe draw routines
├── Doc/              Architecture sketches and ISA spreadsheet
└── artix7/           Xilinx Artix-7 technology files (for Yosys)
```

---

## Prerequisites

All tooling is free and open-source.

| Tool | Purpose | Install |
|---|---|---|
| **GCC** (or any C compiler) | Build the C functional model | `sudo apt install build-essential` |
| **Icarus Verilog (`iverilog`)** | RTL simulation | `sudo apt install iverilog` |
| **GTKWave** | Waveform viewer for `.vcd` dumps | `sudo apt install gtkwave` |
| **Perl** | Run the assembler and BRAM generator | `sudo apt install perl` (usually pre-installed) |
| **Yosys** | Synthesis for FPGA targets | `sudo apt install yosys` or build from source |
| **nextpnr / icestorm** | Place-and-route for Lattice iCE40 | See [icestorm.org](http://www.clifford.at/icestorm/) |

> For Xilinx Nexys A7, Yosys uses the provided `artix7/` technology database together with nextpnr-xilinx (or Vivado for bitstream generation).

---

## Architecture Overview

### Pipeline

NoobsCpu is a classic **3-stage in-order pipeline**:

```
  Clock N        Clock N+1      Clock N+2
┌──────────┐   ┌──────────┐   ┌──────────┐
│  IFETCH  │ → │ IDECODE  │ → │ EXECUTE  │
│ ifetch.v │   │idecode.v │   │execute.v │
└──────────┘   └──────────┘   └──────────┘
     │               │               │
  Instruction    Operand         ALU / Mem /
  memory read    extraction      Branch
```

The decode stage stalls the fetch stage when it needs an extra byte (e.g. for immediate values or addresses), so the pipeline naturally handles multi-byte instructions without a separate hazard unit.

### Registers

| Name | Width | Description |
|---|---|---|
| R0 | 8-bit | General-purpose register 0 |
| R1 | 8-bit | General-purpose register 1 |
| R2 | 8-bit | General-purpose register 2 |
| R3 | 8-bit | General-purpose register 3 / indirect address index |
| CR | 8-bit | Control Register — branch condition and address-mode bits |
| SR | 8-bit | Status Register — result flags |
| SP | 12-bit | Stack Pointer (upper 3 bits programmable via CR; lower 8 bits internal) |

All four general-purpose registers are also **memory-mapped** at the lowest data-memory addresses, enabling direct inspection and manipulation via `LOAD`/`STORE`.

### Memory

**Data memory map (2 KB)**

| Address | Alias | Description |
|---|---|---|
| 0x000 | R0 | Mirror of register R0 |
| 0x001 | R1 | Mirror of register R1 |
| 0x002 | R2 | Mirror of register R2 |
| 0x003 | R3 | Mirror of register R3 |
| 0x004 | CR | Control Register |
| 0x005 | SR | Status Register (read-only) |
| 0x006 | SP | Stack Pointer upper bits (10:8) |
| 0x007 | — | Reserved |
| 0x008 – 0x7FF | User data | First `.data` label resolves to address 8 |

> **Note:** Addresses beyond the user data area can be used for **memory-mapped peripherals**. In `blinky_soc`, address 100 (0x64) is the LED GPIO register and address 101 (0x65) is the UART TX register.

### Status Flags

The Status Register (SR) is updated after every ALU operation and memory access.

| Bit | Name | Set when … |
|---|---|---|
| 0 | `OVF` | The 8-bit result overflowed (carry out or 2's complement overflow) |
| 1 | `ST_OVF` | Stack overflow detected |
| 2 | `NZ` | Result is **not** zero |
| 3 | `Z` | Result **is** zero |
| 4 | `I_TRP` | Interrupt trap pending |

### Addressing Modes

**Direct mode** (default): `LOAD` and `STORE` use the literal 12-bit address (or a label that resolves to one).

```asm
LOAD  R0, MY_VAR    # R0 ← Mem[address of MY_VAR]
STORE R0, MY_VAR    # Mem[address of MY_VAR] ← R0
```

**Indirect mode**: activated with `SET_ADR_MODE`. In this mode, **R3 is used as an index offset** added to the base address in `LOAD`/`STORE`. Use `RST_ADR_MODE` to return to direct mode.

```asm
XOR  R3, R3         # R3 = 0 (index = 0)
SET_ADR_MODE
LOOP:
    LOAD  R1, MY_ARRAY   # R1 ← Mem[MY_ARRAY + R3]
    STORE R1, DST        # Mem[DST + R3] ← R1
    ADDI  R3, R3, 1      # R3++
    SUBI  R0, R0, 1
    JMPNZ LOOP
RST_ADR_MODE
```

---

## Assembly Language Reference

### Program Structure — .data and .code Sections

Every NoobsCpu assembly file is divided into two sections, in order:

```
.data
    <data declarations>
.code
    <instructions>
```

- **Comments** start with `#` and run to end of line.
- **Labels** are identifiers followed by `:`. They may appear at the start of a data declaration or before any instruction.
- Label names must not start with a digit.

#### .data Section

Declare named variables and arrays. Each entry is a label, followed by `:`, followed by one or more comma-separated 8-bit values.

```asm
.data
    COUNTER: 0x00               # single byte, initialised to 0
    LIMIT:   0x0a               # single byte, value 10
    ARRAY:   0x01,0x02,0x03     # array of 3 bytes
    MSG:     72,101,108,108,111  # "Hello" in ASCII
```

> Data labels resolve to absolute data-memory addresses starting at **0x08** (the first 8 addresses are reserved for internal registers). Arrays consume consecutive addresses; the label points to the first element.

#### .code Section

Write instructions below `.code`. Labels mark jump/call targets:

```asm
.code
        XOR   R0, R0        # zero out R0
LOOP:   ADDI  R0, R0, 1     # R0++
        SUBI  R1, R1, 1
        JMPNZ LOOP          # repeat until R1 == 0
        HALT
```

---

### Instruction Set

#### Notation

| Symbol | Meaning |
|---|---|
| `Rd` | Destination register (R0–R3) |
| `Rs`, `Rs1`, `Rs2` | Source register (R0–R3) |
| `#imm` | 8-bit immediate value (decimal, `0x` hex, or `0b` binary) |
| `addr` / `label` | 12-bit data/code address or assembler label |

---

#### Machine Control

| Mnemonic | Size | Description | Example |
|---|---|---|---|
| `NOP` | 1 byte | No operation | `NOP` |
| `HALT` | 1 byte | Stop CPU execution | `HALT` |
| `RET` | 1 byte | Return from subroutine (pops return address from stack) | `RET` |
| `SET_ADR_MODE` | 1 byte | Enable indirect (register-indexed) addressing | `SET_ADR_MODE` |
| `RST_ADR_MODE` | 1 byte | Return to direct addressing mode | `RST_ADR_MODE` |
| `CLR_BC` | 1 byte | Clear branch-condition bits in CR | `CLR_BC` |
| `SET_BCZ` | 1 byte | Set branch condition = "branch if Zero flag" | `SET_BCZ` |
| `SET_BCNZ` | 1 byte | Set branch condition = "branch if Not-Zero flag" | `SET_BCNZ` |

---

#### ALU — Register × Register

All register-register ALU operations are **1 byte**. The result is written back to the first operand (`Rd = Rd op Rs`).

| Mnemonic | Operation | Description | Example |
|---|---|---|---|
| `ADD Rd, Rs` | `Rd = Rd + Rs` | Add two registers | `ADD R0, R1` |
| `SUB Rd, Rs` | `Rd = Rd − Rs` | Subtract Rs from Rd | `SUB R0, R1` |
| `AND Rd, Rs` | `Rd = Rd & Rs` | Bitwise AND | `AND R0, R1` |
| `OR  Rd, Rs` | `Rd = Rd \| Rs` | Bitwise OR | `OR  R0, R1` |
| `XOR Rd, Rs` | `Rd = Rd ^ Rs` | Bitwise XOR; `XOR Rx, Rx` is the idiomatic **zero a register** | `XOR R0, R0` |

All five update SR flags (`Z`, `NZ`, `OVF`).

---

#### ALU — Register × Immediate

Immediate-form instructions are **2 bytes** (opcode byte + immediate byte). The destination **can differ** from the source operand (`Rd = Rs op #imm`).

| Mnemonic | Operation | Description | Example |
|---|---|---|---|
| `ADDI Rd, Rs, #imm` | `Rd = Rs + imm` | Add immediate | `ADDI R0, R0, 1` |
| `SUBI Rd, Rs, #imm` | `Rd = Rs − imm` | Subtract immediate | `SUBI R1, R1, 0x0a` |
| `ANDI Rd, Rs, #imm` | `Rd = Rs & imm` | Bitwise AND immediate | `ANDI R0, R0, 0x07` |
| `ORI  Rd, Rs, #imm` | `Rd = Rs \| imm` | Bitwise OR immediate | `ORI  R2, R2, 0x80` |
| `XORI Rd, Rs, #imm` | `Rd = Rs ^ imm` | Bitwise XOR immediate; `XORI Rx, Rx, 0xff` inverts all bits | `XORI R0, R0, 0xff` |

> **Tip:** `ADDI Rd, Rs, 0` is the canonical **register copy** (`Rd = Rs`).

---

#### Memory — Load and Store

Both instructions are **2 bytes** (opcode + address LSB; address MSB is packed into the opcode byte).

| Mnemonic | Operation | Description | Example |
|---|---|---|---|
| `LOAD  Rd, addr` | `Rd = Mem[addr]` | Load byte from data memory into register | `LOAD R0, MY_VAR` |
| `STORE Rd, addr` | `Mem[addr] = Rd` | Store register byte to data memory | `STORE R0, MY_VAR` |

In **indirect mode** (`SET_ADR_MODE` active), the effective address is `addr + R3`.

```asm
# Example: load element [2] of ARRAY
ADDI  R3, R3, 2      # set index to 2
SET_ADR_MODE
LOAD  R0, ARRAY      # R0 ← Mem[ARRAY + 2]
RST_ADR_MODE
```

---

#### Flow Control — Jumps

The assembler expands conditional jumps into 1–3 helper bytes followed by the 2-byte core `JMP`, so the **effective instruction size** is shown below.

| Mnemonic | Effective size | Condition | Example |
|---|---|---|---|
| `JMP   addr` | 2 bytes | Unconditional | `JMP MAIN_LOOP` |
| `JMPNC addr` | 3 bytes | Unconditional (clears CR first) | `JMPNC FOREVER` |
| `JMPZ  addr` | 4 bytes | Jump if **Zero** flag is set | `JMPZ  END` |
| `JMPNZ addr` | 4 bytes | Jump if **Not-Zero** flag is set | `JMPNZ LOOP` |
| `JMPOVF addr` | 5 bytes | Jump if **Overflow** flag is set | `JMPOVF HANDLE_OVF` |

`JMPZ` and `JMPNZ` test the flag set by the **immediately preceding** ALU instruction. The idiomatic countdown loop pattern is:

```asm
        ADDI  R0, R0, 10     # initialise counter
LOOP:   # ... loop body ...
        SUBI  R0, R0, 1      # decrement — sets Z/NZ flags
        JMPNZ LOOP           # repeat until R0 == 0
```

`JMPOVF` is useful for detecting 8-bit boundary crossings in pointer arithmetic, as used in bubble-sort:

```asm
SUBI  R3, R3, 8
JMPOVF INNER_LOOP   # continue if subtraction overflowed (i.e. still in range)
```

---

#### Flow Control — Subroutine Calls

`CALL` pushes the return address onto the internal stack and jumps to the target. `RET` pops it. The stack is hardware-managed and its upper address bits are configured via CR at address 4.

| Mnemonic | Effective size | Condition | Example |
|---|---|---|---|
| `CALL   addr` | 2 bytes | Unconditional | `CALL MY_FUNC` |
| `CALLNC addr` | 3 bytes | Unconditional (clears CR first) | `CALLNC MY_FUNC` |
| `CALLZ  addr` | 4 bytes | Call if **Zero** flag is set | `CALLZ HANDLE_ZERO` |
| `CALLNZ addr` | 4 bytes | Call if **Not-Zero** flag is set | `CALLNZ DRAW_X` |
| `CALLOVF addr` | 5 bytes | Call if **Overflow** flag is set | `CALLOVF OVERFLOW_HANDLER` |
| `RET` | 1 byte | — | `RET` |

```asm
# Unconditional call
CLR_BC
CALL    DELAY        # always call

# Conditional call — only call if last ALU result was non-zero
ANDI    R1, R1, 0x40
CALLNZ  DRAW_X       # call DRAW_X if bit 6 was set
```

---

## Building and Running

### Running the Test Suite

```bash
# 1. Build the C model
cd cmodel && make && cd ..

# 2. Build the Verilog testbench
cd tb && make && cd ..

# 3. Run all tests (compares C model output vs RTL output)
cd tests && ./run_tests.sh
```

Each test prints PASS or FAIL; the script exits with a summary. To run a single test:

```bash
cd tests
make SOURCE=fibonacci.asm      # assembles, runs on C model and RTL
make waves                     # opens GTKWave to view the waveform
```

To turn on verbose debug prints from the C model:

```bash
export NOOBS_DEBUG=1
```

### Assembling a Program

```bash
perl utils/noobsASM.pl my_program.asm
```

Outputs two files:
- `code.txt` — hex dump of the instruction memory image
- `data.txt` — hex dump of the data memory image

### Running on the C Model

```bash
cd cmodel
make
cp ../my_program/code.txt .
cp ../my_program/data.txt .
./noobsCpu
# result is in data_out.txt
```

### Running RTL Simulation

```bash
cd tb
make
cp ../my_program/code.txt .
cp ../my_program/data.txt .
./vsim.out
# result is in data_out.txt; waveform is in test.vcd
gtkwave test.vcd
```

### FPGA Synthesis

**Lattice iCE40 (iCEStick)**

```bash
cd blinky_soc
make TARGET=lattice
# produces blinky_soc.bin; flash with iceprog
iceprog blinky_soc.bin
```

**Xilinx Artix-7 (Nexys A7)**

```bash
cd blinky_soc
make TARGET=xilinx
# produces blinky_soc.bit; program with Vivado hardware manager
```

The FPGA memory images are generated automatically from the `.asm` source file by the `gen_fpga_mem.pl` utility — no manual hex conversion needed.

---

## Example Programs

### Blinky + UART Hello World (`blinky_soc/blinky.asm`)

Blinks an on-board LED and sends `"Hello World\r\n"` over UART in an infinite loop. Demonstrates subroutine calls, memory-mapped GPIO and UART, and indirect addressing for string traversal.

```asm
.data
    DELAY1: 0xff
    DELAY2: 0xff
    STR:    72,101,108,108,111,32,119,111,114,108,100,10,13,0
    TMP_REG0: 0
    TMP_REG1: 0
    TMP_REG3: 0
.code
            LOAD    R0, 4           # read Control Register
            ANDI    R0, R0, 0x07    # preserve stack-pointer upper bits
            STORE   R0, 4           # write back
            XOR     R0, R0          # R0 = 0
FOREVER:    STORE   R0, 100         # 100 = LED GPIO address
            XORI    R0, R0, 0xff    # toggle LED
            CALL    DELAY_4X
            CALL    PRINT_HELLO_WORLD
            JMPNC   FOREVER         # loop forever

PRINT_HELLO_WORLD:  XOR     R3, R3
       PRINT_LOOP:  SET_ADR_MODE
                    LOAD    R1, STR     # R1 ← STR[R3] (indirect)
                    RST_ADR_MODE
       WAIT_BUSY:   LOAD    R2, 101    # 101 = UART busy flag
                    SUBI    R2, R2, 1
                    JMPZ    WAIT_BUSY  # wait until UART is ready
                    STORE   R1, 101    # 101 = UART TX register
                    ADDI    R3, R3, 1  # advance string index
                    SUBI    R1, R1, 0  # refresh Z flag from R1
                    JMPNZ   PRINT_LOOP # loop until null terminator
                    RET
```

### Fibonacci (`tests/fibonacci.asm`)

Computes the Nth Fibonacci number (N stored in `VAR2`) and writes the result to `VAR3`.

```asm
.data
    VAR1: 0x00    # F(0) = 0
    VAR2: 0x05    # compute F(5)
    VAR3: 0x00    # result
.code
        LOAD  R0, VAR1
        ADDI  R1, R0, 1     # R1 = F(1) = 1
        LOAD  R3, VAR2
        SUBI  R3, R3, 1
        JMPZ  FIB_0
        SUBI  R3, R3, 1
        JMPZ  FIB_1
LOOP:   CLR_BC
        CALL  NEXT_FIBONACCI
        SUBI  R3, R3, 1
        JMPNZ LOOP
        STORE R1, VAR3
        HALT

NEXT_FIBONACCI: ADDI R2, R1, 0   # R2 = R1 (copy)
                ADD  R1, R0       # R1 = R1 + R0
                ADDI R0, R2, 0   # R0 = R2 (previous R1)
                RET
```

### Multiply (`tests/multiply.asm`)

Implements multiplication via repeated addition.

```asm
.data
    MULTIPLIER1:  0x05
    MULTIPLIER2:  0x07
    MULTIPLICAND: 0x00
.code
        LOAD  R0, MULTIPLIER1
        LOAD  R1, MULTIPLIER2
        CALL  MUL
        STORE R0, MULTIPLICAND
        HALT

MUL:        ADDI  R2, R0, 0   # R2 = R0 (copy multiplicand)
            XOR   R0, R0       # R0 = 0 (accumulator)
MUL_LOOP:   ADD   R0, R2       # accumulate
            SUBI  R1, R1, 1
            JMPNZ MUL_LOOP
            RET
```

### Bubble Sort (`tests/bubble_sort.asm`)

Sorts an 8-element array in-place using the bubble sort algorithm with indirect addressing and overflow-based bounds detection.

```asm
.data
    ARRAY: 0x05,0x01,0x08,0x02,0x0f,0x07,0x04,0x09
    TMP_CR: 0x00
    TMP_REG1: 0x00
    TMP_REG2: 0x00
    TMP_REG3: 0x00
.code
            XOR    R2, R2
OUTER_LOOP: LOAD   R2, TMP_REG2
            ADDI   R2, R2, 1
            STORE  R2, TMP_REG2
            XOR    R3, R3
            STORE  R3, TMP_REG3
INNER_LOOP: LOAD   R3, TMP_REG3
            SET_ADR_MODE
            LOAD   R0, ARRAY    # R0 ← ARRAY[R3]
            ADDI   R3, R3, 1
            LOAD   R1, ARRAY    # R1 ← ARRAY[R3+1]
            RST_ADR_MODE
            CLR_BC
            CALL   SORT_N_STORE
            STORE  R3, TMP_REG3
            SUBI   R3, R3, 8
            JMPOVF INNER_LOOP   # continue while index < 8
            LOAD   R2, TMP_REG2
            SUBI   R2, R2, 8
            JMPOVF OUTER_LOOP
            HALT
```

---

## Gallery

**Running the full test suite (C model + RTL):**

![Test Suite](https://github.com/supratimdas/NoobsCpu-8bit/raw/master/gifs/running_test_suite.gif?raw=true)

**Hello World over UART on FPGA (iCEStick):**

![Hello World UART](https://github.com/supratimdas/NoobsCpu-8bit/raw/master/gifs/blinky_soc_programming.gif?raw=true)

---

## Roadmap

- [ ] VGA controller peripheral for `blinky_soc`
- [ ] PS/2 mouse controller peripheral
- [ ] SPI and UART RX peripherals
- [ ] Tic-tac-toe game running end-to-end on FPGA

---

## ERRATA
- Real working example only tested in iCEStick FPGA. Xilinx FPGA still not supported.

---

## License

Apache 2.0 — see [LICENSE](LICENSE).

## Author

Supratim Das — supratimofficio@gmail.com
