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

## Current Core Capabilities (QAR-Core v0.4)

### Supported Instructions (RV32I subset)
- ADDI, ADD, SUB, AND, OR, XOR, SLL, SRL
- LW, SW (through external valid/ready memory interface)
- BEQ, BNE, BLT, BGE, BLTU, BGEU
- JAL, JALR
- CSRRW + ECALL (minimal CSR/trap skeleton)

### Micro-program + Data Memory
- `program.hex` encodes a tiny RV32I routine that walks an integer array in `data.hex`, filters out negative values, sums the rest into `x10`, then calls a subroutine via `JAL/JALR` to persist the result.
- `data.hex` seeds a 256-word RAM with the array data; address 64 (word index 16) is used to persist the sum and address 68 (index 17) records that the return path completed.

### Execution Model
- Single-cycle core that now streams data memory transactions over a simple `mem_valid`/`mem_ready` handshake (internal RAM is still available for pure simulation via parameter).
- Register file exposes two read ports/one write port (x0 hardwired to zero); `default_nettype none` guards plus SymbiYosys harnesses (BMC) cover the regfile.
- Minimal CSR file (`mstatus`, `mtvec`, `mepc`, `mcause`) allows CSRRW and ECALL-driven trap redirects.

### Simulation Output Example
```
QAR-Core: loading program from program.hex ...
QAR-Core: loading data memory from data.hex ...
=== QAR-Core v0.4 EXECUTION TEST ===
Register x10 = 14 (expected 14)
Data memory[16] = 14 (expected 14)
Data memory[17] = 0x00000123 (expected 0x00000123)
Execution test completed.
```

### DevKit CLI (qarsim)

The Go-based `qarsim` tool assembles `.qar` programs (with `.include` directives and `.equ` macro support), generates `program.hex` / `data.hex`, and can launch simulations:

```sh
# Build (assemble) the default example
go run ./devkit/cli build \
  --asm devkit/examples/sum_positive.qar \
  --data devkit/examples/sum_positive.data \
  --imem 64 \
  --dmem 256 \
  --program program.hex \
  --data-out data.hex

# Assemble and immediately run the execution testbench
go run ./devkit/cli run \
  --asm devkit/examples/sum_positive.qar \
  --data devkit/examples/sum_positive.data \
  --imem 64 \
  --dmem 256
```

# Additional Examples
- `devkit/examples/sum_positive.qar` — filters out negative values and exercises JAL/JALR.
- `devkit/examples/mem_copy.qar` — copies a block of words via LW/SW.
- `devkit/examples/branch_demo.qar` — demonstrates the BGE/BGEU flow control.

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

## Randomized Load/Store Regression
```sh
./scripts/run_random.sh
```

## Formal Check (SymbiYosys)
```sh
sby -f formal/regfile/regfile.sby
```

# Documentation
	•	Architecture specification￼
	•	MVP progress report￼

# Vision

The long-term goal is to establish a sovereign processor, OS, compiler, and hardware ecosystem for the Republic of Kazakhstan, based on QAR — an open and extensible architecture inspired by RISC-V.

# License

This project is currently released under the MIT License.
