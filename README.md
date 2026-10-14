# NoobsCpu — An 8-bit Homebrew CPU

![NoobsCPU Block Diagram](https://github.com/supratimdas/NoobsCpu-8bit/raw/master/NoobsCPU.png?raw=true)

A complete, from-scratch 8-bit CPU built as an educational side project — featuring a hand-written assembler, a cycle-accurate C functional model, synthesisable Verilog RTL, a self-checking testbench, and two real SoC examples running on FPGA: an LED + UART SoC on the Lattice iCEStick, and a UART + VGA SoC on the Digilent Nexys A7 that runs a Pong game. The intent is to capture the **entire front-end design and verification flow** in a single, self-contained repo.

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
- [NoobsC Compiler](#noobsc-compiler)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Supported Language Features](#supported-language-features)
  - [Limitations](#limitations)
  - [Compiler Example Programs](#compiler-example-programs)
- [Building and Running](#building-and-running)
  - [Running the Test Suite](#running-the-test-suite)
  - [Assembling a Program](#assembling-a-program)
  - [Running on the C Model](#running-on-the-c-model)
  - [Running RTL Simulation](#running-rtl-simulation)
  - [FPGA Synthesis](#fpga-synthesis)
- [iCEStick SoC — LED + UART](#icestick-soc--led--uart)
- [Nexys A7 SoC — UART + VGA](#nexys-a7-soc--uart--vga)
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
| High-level compiler | NoobsC — a C-like compiler (Python 3) that targets the CPU directly |

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
│   ├── gen_fpga_mem.pl  BRAM initialiser for iCE40 / Artix-7
│   └── NoobsC/       High-level C-like compiler (Python 3)
│       ├── noobsc.py     Compiler driver (entry point)
│       ├── lexer.py      Phase 1 — tokeniser
│       ├── parser.py     Phase 2 — recursive-descent parser
│       ├── semantic.py   Phase 3 — semantic analyser / symbol table
│       ├── codegen.py    Phase 4 — assembly code generator
│       ├── ast_nodes.py  AST node definitions
│       └── examples/     NoobsC example programs (.nc)
├── tests/            25+ self-checking assembly tests + run scripts
├── blinky_soc/       iCEStick SoC: LED blinky + "Hello World" over UART TX (open-source flow)
├── nexysa7_blinky_soc/  Vivado project: Nexys A7 SoC with UART + VGA text display (blinky.asm, pong.asm)
├── Doc/              Architecture sketches and ISA spreadsheet
└── artix7/           Xilinx Artix-7 technology files (for Yosys)
```

---

## Prerequisites

All tooling is free, and everything except Vivado (needed only for the Nexys A7 SoC) is open-source.

| Tool | Purpose | Install |
|---|---|---|
| **GCC** (or any C compiler) | Build the C functional model | `sudo apt install build-essential` |
| **Icarus Verilog (`iverilog`)** | RTL simulation | `sudo apt install iverilog` |
| **GTKWave** | Waveform viewer for `.vcd` dumps | `sudo apt install gtkwave` |
| **Perl** | Run the assembler and BRAM generator | `sudo apt install perl` (usually pre-installed) |
| **Python 3.8+** | Run the NoobsC compiler | `sudo apt install python3` (usually pre-installed) |
| **Yosys** | Synthesis for FPGA targets | `sudo apt install yosys` or build from source |
| **arachne-pnr + icestorm** | Place-and-route, bitstream packing (`icepack`) and programming (`iceprog`) for the iCEStick | See [icestorm.org](http://www.clifford.at/icestorm/) |
| **Xilinx Vivado** (free edition) | Build the Nexys A7 SoC | From AMD/Xilinx |

> The experimental open-source Xilinx flow for `blinky_soc` uses Yosys with the provided `artix7/` technology database and nextpnr-xilinx.

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

> **Note:** Addresses beyond the user data area can be used for **memory-mapped peripherals**. In both SoCs, address 100 (0x64) is the LED GPIO register and address 101 (0x65) is the UART TX register; the Nexys A7 SoC adds a VGA display and push buttons at addresses 102–106. See [iCEStick SoC — LED + UART](#icestick-soc--led--uart) and [Nexys A7 SoC — UART + VGA](#nexys-a7-soc--uart--vga).

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

## NoobsC Compiler

### Overview

**NoobsC** is a small C-like compiler that targets NoobsCpu assembly directly. It lets you write programs in a readable high-level language and have them compiled, assembled, and run on the CPU — closing the full stack from source code down to real silicon.

The compiler is written in Python 3 and implements a classic five-phase pipeline:

```
Source (.nc)
    │
    ▼  Phase 1 — Lexer       (lexer.py)
 Tokens
    │
    ▼  Phase 2 — Parser      (parser.py)
   AST
    │
    ▼  Phase 3 — Semantic    (semantic.py)
Symbol table + validated AST
    │
    ▼  Phase 4 — Code Gen    (codegen.py)
Assembly text (.asm)
    │
    ▼  Phase 5 — Assembler   (noobsASM.pl)
code.txt / data.txt
```

### Usage

```bash
# Full compile: source → .asm written to CWD, then assembled → code.txt + data.txt
python utils/NoobsC/noobsc.py path/to/program.nc

# Emit assembly only (skip the assembler step)
python utils/NoobsC/noobsc.py --asm path/to/program.nc

# Dump token stream (debug the lexer)
python utils/NoobsC/noobsc.py --lex path/to/program.nc

# Dump the AST (debug the parser)
python utils/NoobsC/noobsc.py --ast path/to/program.nc
```

The `.asm` file is always written to the **current working directory**, not next to the source file.

### Supported Language Features

#### Data Types

| Type | Description |
|---|---|
| `char` | Single 8-bit unsigned integer (0–255). The only scalar type. |
| `char name[N]` | Fixed-size array of N bytes. |

#### Declarations

- **Global variables and arrays** — allocated in the `.data` section, accessible from any function.
- **Local variables** — declared at the top of a function body; statically allocated per-function.
- **Function parameters** — up to **3 parameters**, passed in registers R0, R1, R2.
- **`void` and `char` return types** — `char` functions return a value in R0; `void` functions do not.

#### Operators

| Category | Operators |
|---|---|
| Arithmetic | `+`, `-` |
| Bitwise | `&`, `\|`, `^`, `~` |
| Logical | `!`, `&&`, `\|\|` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Assignment | `=`, `+=`, `-=`, `&=`, `\|=`, `^=` |
| Postfix increment / decrement | `i++`, `i--` |
| Unary | `-x` (two's-complement negation), `~x` (bitwise NOT), `!x` (logical NOT) |

#### Statements

| Statement | Syntax |
|---|---|
| Variable declaration | `char x;` or `char x = expr;` |
| If / else | `if (cond) { … } else { … }` |
| While loop | `while (cond) { … }` |
| For loop | `for (init; cond; step) { … }` |
| Return | `return expr;` or `return;` |
| Break | `break;` (exits the innermost loop) |
| Expression statement | `expr;` |

#### Comments

```c
// Line comment — runs to end of line

/* Block comment —
   spans multiple lines */
```

> **Note:** `#` is NOT a valid comment character in NoobsC source files (it is only valid in hand-written `.asm` files for the assembler).

#### Example

```c
// fibonacci.nc — compute fib(10) and store in result
char result;

char fib(char n) {
    char a; char b; char tmp;
    a = 0; b = 1;
    while (n) {
        tmp = b;
        b = a + b;
        a = tmp;
        n = n - 1;
    }
    return a;
}

void main() {
    result = fib(10);   // result = 55
}
```

```bash
cd /path/to/your/project
python utils/NoobsC/noobsc.py utils/NoobsC/examples/fibonacci.nc
# Assembly written to: ./fibonacci.asm
# Assembled successfully → code.txt / data.txt
./cmodel/noobsCpu code.txt data.txt
# result byte (0x37 = 55) is first entry in data_out.txt
```

---

### Limitations

These are intentional simplifications, not missing features — they keep the compiler and target ISA understandable without hiding complexity behind abstraction.

#### 1. No recursion

Local variables and parameters are **statically allocated** (not on a call stack). Calling a function recursively would overwrite its own in-progress locals. The compiler does not check for this at compile time — recursive programs silently produce wrong output.

#### 2. No multiplication, division, or modulo

The `*`, `/`, and `%` operators are **not supported** as expression values. The CPU has no MUL/DIV instruction, and implementing them inline would generate unbounded code size. Use a helper function instead:

```c
char mul(char a, char b) {
    char acc; acc = 0;
    while (b) { acc = acc + a; b = b - 1; }
    return acc;
}
```

#### 3. Single 8-bit data type only

Only `char` (unsigned 8-bit, range 0–255) exists. There are no `int`, `long`, `float`, pointers, structs, enums, or typedefs. Arithmetic that exceeds 255 silently wraps around.

#### 4. At most 3 function arguments

The calling convention passes arguments in registers R0, R1, R2. Functions with more than 3 parameters are a compile error.

#### 5. No initializers for global variables

```c
char x = 5;    // ✗ initializer on globals is not supported
char x;        // ✓ declare, then assign in code
```

Global arrays and scalars are always zero-initialised at load time. Initialise them explicitly inside `main()` or a setup function.

#### 6. Expression nesting depth limited to 4

The code generator uses 4 scratch memory slots (`__tmp0`–`__tmp3`) to hold intermediate values during complex expressions. Nesting more than 4 levels deep (e.g. `(a + (b + (c + (d + e))))`) produces a compile error:

```
CodeGen error: Expression too complex — nesting exceeds scratch temp limit
```

Break deeply nested expressions into temporary variables to work around this.

#### 7. No do-while loops

`do { … } while (cond);` is not implemented. Use a `while` loop with a pre-set flag or an explicit first iteration.

#### 8. No `else if` chains

```c
if (x == 1) { … }
else if (x == 2) { … }   // ✗ not supported
```

Use nested `if` / `else` blocks instead:

```c
if (x == 1) { … }
else { if (x == 2) { … } }
```

#### 9. No forward declarations

Functions must be declared (fully defined) before they are called if mutual recursion were attempted — but recursion is already unsupported, so in practice declaring functions before calling them is the natural order.

#### 10. Variable names must not be `data` or `code`

The assembler identifies section boundaries by matching `.data` and `.code` exactly. However, as a convention, avoid naming variables or functions anything that could interact with assembler syntax — specifically the bare strings `data` or `code` without a leading dot could cause issues with older versions of the assembler.

---

### Compiler Example Programs

All examples live in `utils/NoobsC/examples/` and can be compiled and run as shown above.

| File | What it demonstrates | Expected result |
|---|---|---|
| `blinky.nc` | Global variable, infinite `while` loop, XOR toggle | LED toggle pattern |
| `fibonacci.nc` | `while` loop, multiple locals, subtraction | `fib(10)` = 55 (0x37) |
| `multiply.nc` | `while` loop as repeated addition, function call | `6 × 7` = 42 (0x2A) |
| `array_fill.nc` | Global array, `for` loop, array indexing | `arr` = [0,1,2,3,4,5,6,7]; `total` = 28 |
| `bubble_sort.nc` | Nested loops, array read/write, `if`, `break` | Array sorted in ascending order |

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

There are two FPGA SoCs, each with its own section covering peripherals, memory map, example programs and build steps:

- [iCEStick SoC — LED + UART](#icestick-soc--led--uart) — Lattice iCE40, fully open-source Yosys / arachne-pnr / icestorm flow
- [Nexys A7 SoC — UART + VGA](#nexys-a7-soc--uart--vga) — Xilinx Artix-7, Vivado project

In both, the FPGA memory images (`inst_mem.v`, `data_mem.v`) are generated from the program's `.asm` source by `utils/gen_fpga_mem.pl` — no manual hex conversion needed.

---

## iCEStick SoC — LED + UART

`blinky_soc/` builds a minimal NoobsCpu SoC for the Lattice iCEStick (iCE40-HX1K) using the fully open-source Yosys → arachne-pnr → icestorm flow. Besides the CPU and its memories it has one LED and a **UART transmitter** (115200 baud). The CPU runs from the board's 12 MHz oscillator divided by 64 (187.5 kHz); an iCE40 PLL generates a 50.25 MHz clock for the UART baud-rate generator, and an internal power-on reset holds the CPU in reset for the first 4096 clock cycles.

**Memory-mapped I/O**

| Address | Access | Function |
|---|---|---|
| 100 | write | Green LED — any non-zero value turns it on |
| 101 | write | UART TX byte |
| 101 | read | UART busy flag (bit 0) |

**Pins** (`pins.pcf`)

| Signal | FPGA pin | Board location |
|---|---|---|
| `clk` | 21 | 12 MHz oscillator |
| `LED` | 95 | Green LED (centre) |
| `uart_tx` | 91 | PMOD pin 10 |
| `reset_` | 81 | PMOD pin 4 (not used by the iCE40 build, which uses the power-on reset) |

UART TX is routed to the PMOD header, so connect a 3.3 V USB-serial adapter to PMOD pin 10 (plus GND) and open a terminal at 115200 baud.

**Example programs** (in `blinky_soc/`)

| Program | Description |
|---|---|
| `blinky.asm` | The default program: toggles the LED and prints `Hello World` over the UART, with a delay between iterations — see [Blinky + UART Hello World](#blinky--uart-hello-world-blinky_socblinkyasm) |
| `blinky_without_delay.asm` | The same without the delay loop: prints `Hello World` back to back, toggling the LED once per line |

**Building**

The Makefile assembles the program, regenerates `inst_mem.v` / `data_mem.v` and runs the whole flow:

```bash
cd blinky_soc
make            # assemble blinky.asm, synthesise, place & route -> blinky_soc.bin
make prog       # flash the iCEStick with iceprog
make timings    # optional: static timing report with icetime
```

To build another program, start from a clean tree so the memory images are regenerated: `make clean && make ASM_FILE=blinky_without_delay.asm`. The Makefile runs Yosys from `/usr/local/bin/yosys`; pass `YOSYS=yosys` to use the one on your `PATH`.

The same `blinky_soc` RTL can also target the Nexys A7 through an experimental open-source Xilinx flow (`make TARGET=xilinx`: Yosys + nextpnr-xilinx + prjxray tools, using `pins_xilinx_nexysA7.xdc` and the `artix7/` database), but nextpnr-xilinx currently runs into routing problems. Use the Vivado-based [Nexys A7 SoC](#nexys-a7-soc--uart--vga) for that board.

---

## Nexys A7 SoC — UART + VGA

`nexysa7_blinky_soc/blinky_soc/` is a Vivado project that builds a NoobsCpu SoC for the Digilent Nexys A7 (Artix-7). Alongside the LED and the usual **UART TX** (115200 baud, on the board's USB-UART), it implements a **VGA controller**: a 40 × 30 character text display on a 640 × 480 VGA output, plus up/down push-button input. The sources (including the SoC's own copy of the CPU RTL) are in `blinky_soc.srcs/sources_1/`; pin constraints are in `blinky_soc.srcs/constrs_1/new/blinky_soc_nexys_a7.xdc`. The CPU runs at 100 MHz / 64 = 1.5625 MHz.

**Memory-mapped I/O**

| Address | Access | Function |
|---|---|---|
| 100 | write | LED0 — any non-zero value turns it on |
| 101 | write | UART TX byte (in VGA auto mode the byte is also printed on screen) |
| 101 | read | UART busy flag (bit 0) |
| 102 | write | VGA mode: 0 = auto (terminal), 1 = clear screen, 2 = programmed |
| 102 | read | VGA status: `{4'b0, mode[1:0], cleared, clear_in_progress}` |
| 103 | write | VGA row (0–29), programmed mode |
| 104 | write | VGA column (0–39), programmed mode |
| 105 | write | Character to draw at (row, column), programmed mode |
| 106 | read | Buttons: 0 = none, 1 = up (BTNU), 2 = down (BTND) |

**VGA modes**

- **Auto (0)** — bytes written to the UART address also appear on screen like a terminal: the cursor advances one column per character, CR (13) starts a new line, and NUL (0) is not drawn.
- **Clear (1)** — the controller writes a space into all 1200 cells, one per CPU cycle. Poll bit 1 of address 102 until the clear has finished, then switch to another mode.
- **Programmed (2)** — write the row, the column, then the character to place any glyph anywhere on screen.

The font ROM (`vga/prom.txt`) holds 128 glyphs, including graphics in the control-code range (for example 7 = bullet, 8 = solid box, 22 = thick bar), which Pong uses for the ball, paddles and walls.

Because the I/O registers sit inside the data address space, a program's `.data` section must end below address 100.

**Example programs** (in `blinky_soc.srcs/sources_1/`)

| Program | Description |
|---|---|
| `blinky.asm` | The standard blinky: toggles the LED and prints a counter digit followed by `Hello World` over the UART in a loop; the same text appears on the VGA display, which is cleared every 30 lines |
| `pong.asm` | A Pong game against a CPU-controlled paddle, drawn on the VGA display and played with BTNU / BTND — see [Pong](#pong-pongasm-nexys-a7-soc) |

**Building**

Assemble the program you want to run and regenerate the memory images (this rewrites `inst_mem.v` and `data_mem.v`):

```bash
cd nexysa7_blinky_soc/blinky_soc/blinky_soc.srcs/sources_1
perl ../../../../utils/noobsASM.pl pong.asm
perl ../../../../utils/gen_fpga_mem.pl -input_file code.txt -type inst -target xilinx
perl ../../../../utils/gen_fpga_mem.pl -input_file data.txt -type data -target xilinx
```

Then open `nexysa7_blinky_soc/blinky_soc/blinky_soc.xpr` in Vivado, generate the bitstream and program the board from the Hardware Manager. Connect a VGA monitor, and a serial terminal at 115200 baud to see the UART output.

---

## Example Programs

### Blinky + UART Hello World (`blinky_soc/blinky.asm`)

The default program of the [iCEStick SoC](#icestick-soc--led--uart). Blinks the LED and sends `"Hello World\n\r"` over UART in an infinite loop. Demonstrates subroutine calls, memory-mapped GPIO and UART, and indirect addressing for string traversal. (The `DELAY` / `DELAY_XX` delay routines are omitted below.)

```asm
.data
    STR:      72,101,108,108,111,32,119,111,114,108,100,10,13,0
    TMP_REG0: 0
    TMP_REG1: 0
    TMP_REG3: 0
    DELAY1:   0xff
    DELAY2:   0xff
.code
            LOAD    R0, 4           # read Control Register
            ANDI    R0, R0, 0x07    # move the stack to page 1 (0x100)
            STORE   R0, 4           # write back
            XOR     R0, R0          # R0 = 0
FOREVER:    STORE   R0, 100         # 100 = LED GPIO address
            XORI    R0, R0, 0xff    # toggle LED
            CALL    PRINT_HELLO_WORLD
            CLR_BC                  # clear the branch bits its JMPNZ left behind
            CALL    DELAY_XX        # otherwise this plain CALL would be conditional
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

The Nexys A7 SoC has its own `blinky.asm` (in `nexysa7_blinky_soc/blinky_soc/blinky_soc.srcs/sources_1/`) that additionally prints the text on the VGA display.

### Pong (`pong.asm`, Nexys A7 SoC)

A complete Pong game for the [Nexys A7 SoC](#nexys-a7-soc--uart--vga), in `nexysa7_blinky_soc/blinky_soc/blinky_soc.srcs/sources_1/pong.asm` (about 750 bytes of code).

- Your paddle is on the left, controlled with BTNU / BTND; the CPU plays the right paddle. Press either button to start, first to 9 points wins, and a button press starts a new game.
- The outer rows of a paddle return the ball at 45°, the inner rows at a shallow angle — use them to aim away from the CPU.
- The CPU paddle only reacts once the ball is heading its way and has crossed a set column, so well-angled shots beat it.
- The game runs on a ~30 ms tick, toggling LED0 every frame as a heartbeat.

Everything tunable lives in the `.data` section: court layout (width, paddle/net/text columns — currently a 35-column court, with values for 30 and 40 listed in the comments), frame delay, pause length, CPU difficulty (`AI_SPEED`, `AI_REACT_COL`) and the glyphs used for ball, paddles, walls and net.

Drawing uses the VGA controller's programmed mode — one character is three stores:

```asm
PUT_CHAR:   STORE   R1, 103    # select row
            STORE   R2, 104    # select column
            STORE   R0, 105    # draw the character
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

- [ ] PS/2 mouse controller peripheral
- [ ] SPI and UART RX peripherals

---

## ERRATA
- The open-source Xilinx flow (`make -C blinky_soc TARGET=xilinx`, nextpnr-xilinx) currently runs into routing problems, so Xilinx builds are done with Vivado (see [Nexys A7 SoC](#nexys-a7-soc--uart--vga)).
- On the Nexys A7 board the rightmost columns of the 40-column VGA text display are currently not visible, so `pong.asm` uses a 35-column court.
- Assembly files (`.asm`) use `#` for line comments. NoobsC source files (`.nc`) use `//` and `/* */` — `#` is not valid in NoobsC source.

---

## License

Apache 2.0 — see [LICENSE](LICENSE).

## Author

Supratim Das — supratimofficio@gmail.com
