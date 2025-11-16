# 3. **MVP progress report: `docs/mvp-status.md`**

# QAR-MVP Progress Report

---

## Overview

The project began with the goal of creating a functional RV32I-style prototype CPU entirely on a MacBook Air M2 using open tools.

---

## Milestone Status

- **QAR-Core v0.1 — DONE.** Minimal RV32I execution path validated in simulation with automated testbenches.
- **QAR-Core v0.2 — DONE.** RV32I subset expanded (SUB/logic/shifts/LW/SW/BEQ), data RAM introduced, and the sum-array reference program verified via assertions.
- **QAR-Core v0.3 — DONE.** Control flow widened (BNE/BLT/JAL/JALR), the Go-based DevKit CLI/assembler (`qarsim`) now generates `program.hex`/`data.hex`, and verification includes randomized regressions plus a SymbiYosys harness.

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
- verifies that x3 = x1 + x2 = 8 (v0.1)
- verifies that x10 = filtered sum = 14 and `dmem[16] = 14`, `dmem[17] = 0x123` (v0.3)

### ✔ Micro-programs + DevKit
- Reference array stored in `devkit/examples/sum_positive.*`, assembled via `qarsim`
- LW/SW/BEQ/BNE/BLT + JAL/JALR exercised inside the same test thanks to the callable subroutine
- `default_nettype none`, deterministic assertions, randomized regression bench, and `formal/regfile/regfile.sby`

---

## In Progress

- External memory interface definition + handshake for future SoC/FPGA bring-up
- Expanded ISA work (BGE/BGEU, system instructions, CSR skeleton)
- qarsim feature backlog (macros, include files, richer examples)
- QAR-OS v0.1 boot model (blocked on richer ISA + tooling)

---

## Next Steps (Short-term)

1. Define and implement the external load/store handshake so DMEM can be swapped for FPGA-attached RAM.
2. Extend ISA coverage (BGE/BGEU, JALR offsets, simple CSR/trap stubs) to support QAR-OS experiments.
3. Grow qarsim: macro support, additional sample programs, and a friendlier UX for generating `program.hex`/`data.hex`.
4. Broaden verification (additional SymbiYosys targets, negative/randomized programs, lint integration).
5. Document contribution process (ROADMAP.md, CONTRIBUTING.md) and codify the release cadence.

---

## Next Target: QAR-Core v0.4

1. **Memory interface** — Provide a simple AXI-lite-style or handshake-based external DMEM port so the core can drop into FPGA/SoC shells.
2. **ISA & system hooks** — Add the remaining branch/jump variants plus skeletal CSR/trap handling needed by QAR-OS.
3. **Pipeline prep** — Document hazards and experiment with a two-stage pipeline or structured microcode to unblock higher clock targets.
4. **Tooling & verification** — Enhance `qarsim`, expand the example suite, and extend SymbiYosys coverage beyond the register file.
