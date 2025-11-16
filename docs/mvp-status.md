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
- **QAR-Core v0.4 — DONE.** Data memory now streams through a valid/ready interface, BGE/BGEU landed, minimal CSR/trap support (`CSRRW`, `ECALL`) is live, `qarsim` gained `.include`/`.equ` support with new example programs, and the SymbiYosys flow (BMC depth 8) + randomized wait-state regression are part of the documented workflow.

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
- LW/SW + full branch set (`BEQ/BNE/BLT/BGE/BGEU`) plus JAL/JALR exercised inside the same test thanks to the callable subroutine and shared macro file (`common.inc`)
- `default_nettype none`, deterministic assertions, randomized regression with handshake wait-states, and SymbiYosys (`formal/regfile/regfile.sby`, BMC depth 8)

---

## In Progress

- Pipeline / hazard plan for single-cycle → two-stage migration
- CSR/interrupt depth (CSRRS/CSRRC, MRET, IRQ entry/exit)
- Instruction-memory handshake/caching strategy
- QAR-OS v0.1 boot model (blocked on traps/interrupts/tooling polish)

---

## Next Steps (Short-term)

1. Outline/implement a simple two-stage pipeline (or FSM) so the memory interface no longer stalls fetch.
2. Expand CSR support (CSRRS/CSRRC, MRET) and add a basic interrupt flow for QAR-OS experiments.
3. Expose an instruction-memory handshake (or cache stub) to ease FPGA bring-up.
4. Broaden verification (additional SymbiYosys targets, CI automation, lint).
5. Document contribution process (ROADMAP.md, CONTRIBUTING.md) and codify the release cadence.

---

## Next Target: QAR-Core v0.5

1. **Pipeline & hazards** — Introduce a two-stage pipeline or structured microcode and define hazard/interlock policy.
2. **CSR/interrupt depth** — Add CSRRS/CSRRC, MRET, and IRQ entry/exit so traps can round-trip.
3. **Instruction-memory interface** — Provide a fetch handshake/cache stub compatible with FPGA memories.
4. **Tooling & verification** — Extend `qarsim`, grow the example suite, and add additional SymbiYosys targets plus CI wiring.
