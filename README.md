# QAR-MVP — Minimal Prototype of the QAR Architecture

QAR-MVP is the first working prototype of the **QAR (Qazaq Architecture of RISC)** initiative.  
This project demonstrates that Kazakhstan can design and implement its own processor architecture, instruction set subset, and development toolkit using only:

- 1 MacBook Air M2 (8 GB RAM)
- 2 engineers (human + AI collaboration)
- open-source tools (Verilog, Icarus, Go)

The current MVP implements:
- a functional 32-bit register file  
- a functional ALU (ADD, SUB, AND, OR, XOR, SLL, SRL)  
- a minimal RV32I-compatible core capable of executing real instructions  
- an external `program.hex` loader  
- full simulation environment and testbenches  

This is the **first step** toward a sovereign processor ecosystem in Kazakhstan.

---

## Project Structure

qar-mvp/
  docs/               # Documentation (architecture, specifications, reports)
  qar-core/
    rtl/              # Verilog RTL modules (regfile, alu, core)
    sim/              # Testbenches and simulation files
    test/             # Program-level tests (future)
  qar-os/
    boot/             # Bootloader (planned)
    kernel/           # Minimal OS kernel (planned)
    lib/              # Runtime libraries (planned)
  devkit/
    cli/              # CLI tools (assembler, runner) — planned
    web/              # Web UI — planned
  scripts/            # Simulation scripts, build helpers
  program.hex         # Current program executed by the core
  data.hex            # Data memory image consumed by LW/SW

---

## Current Core Capabilities (QAR-Core v0.2)

### Supported Instructions (RV32I subset)
- ADDI, ADD, SUB, AND, OR, XOR, SLL, SRL
- LW, SW
- BEQ (used for loop/termination control)

### Micro-program + Data Memory
- `program.hex` encodes a tiny RV32I routine that walks an integer array in `data.hex`, sums 4 values (1,2,3,4), and stores the result in register `x10`.
- `data.hex` seeds a 256-word RAM; slot 4 (address 16) is reserved for the stored sum so we also exercise SW.

### Execution Model
- Single-cycle control path, combinational ALU, and separate instruction/data memories (64-word IMEM, 256-word DMEM).
- Register file exposes two read ports/one write port (x0 hardwired to zero) and `default_nettype none` guards have been enabled across RTL.

### Simulation Output Example
```
QAR-Core: loading program from program.hex ...
QAR-Core: loading data memory from data.hex ...
=== QAR-Core v0.2 EXECUTION TEST ===
Register x10 = 10 (expected 10)
Data memory[4] = 10 (expected 10)
Execution test completed.
```

## Tools Required

Install Verilog simulator:
brew install icarus-verilog

## How to Run Simulations

ALU Test
```sh
./scripts/run_alu.sh
```

## Register File Test
```sh
./scripts/run_regfile.sh
```

## Full Core Execution Test
```sh
./scripts/run_core_exec.sh
```

# Documentation
	•	Architecture specification￼
	•	MVP progress report￼

# Vision

The long-term goal is to establish a sovereign processor, OS, compiler, and hardware ecosystem for the Republic of Kazakhstan, based on QAR — an open and extensible architecture inspired by RISC-V.

# License

This project is currently released under the MIT License.
