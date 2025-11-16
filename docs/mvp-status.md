# 3. **MVP progress report: `docs/mvp-status.md`**

# QAR-MVP Progress Report

---

## Overview

The project began with the goal of creating a functional RV32I-style prototype CPU entirely on a MacBook Air M2 using open tools.

---

## Completed

### ✔ Register File
- 32 registers
- combinational read
- synchronous write
- x0 fixed to zero
- full testbench (`regfile_tb.v`)

### ✔ ALU
- ADD, SUB, AND, OR, XOR, SLL, SRL
- tested via `alu_tb.v`

### ✔ Minimal QAR-Core v0.1
- single-cycle execution
- ADDI and ADD support
- register file + ALU + PC + imem
- executes a real RV32I program
- external program loader (`program.hex`)

### ✔ Testbench: Full Core Execution
- verifies that x3 = x1 + x2 = 8

---

## In Progress

- More instructions (LW, SW, BEQ)
- DevKit CLI (`qarsim`)
- Mini loader and assembler
- QAR-OS v0.1 boot model

---

## Next Steps (Short-term)

1. Add memory load/store
2. Add branch instructions
3. Build the Go-based DevKit (assembler + runner)
4. Create example programs under `examples/`
5. Expand documentation
