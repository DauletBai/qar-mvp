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
- **QAR-Core v0.5 — DONE.** Two-stage IF/EX pipeline with streaming instruction + data buses, CSRRS/CSRRC/MRET traps, DevKit-powered program generation, and regression coverage (deterministic + randomized + SymbiYosys) define the new baseline.
- **QAR-Core v0.6 — DONE.** Three-stage IF/ID/EX pipeline with forwarding + load-use interlocks, a programmable timer + external interrupt path (`mie/mip/mtime/mtimecmp`), extended assembler support (`LUI/AUIPC/CSRR*/ECALL/MRET` with `%hi/%lo`), and a new `irq_demo` DevKit example/testbench that exercises ECALL/IRQ/MRET.

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
- verifies that timer/external interrupt counters reach their targets, `dmem[18] = 2`, `dmem[19] = 1`, and `dmem[20] = 0x1EE` after ECALL/IRQ/MRET flows (v0.6)

### ✔ Micro-programs + DevKit
- Reference array stored in `devkit/examples/sum_positive.*`, assembled via `qarsim`
- LW/SW + full branch set (`BEQ/BNE/BLT/BGE/BGEU`) plus JAL/JALR exercised inside the same test thanks to the callable subroutine and shared macro file (`common.inc`)
- `irq_demo` assembles timer/external interrupt demos (LUI/AUIPC/CSRR*/ECALL/MRET), re-programs `mtimecmp`, and validates CSR flows under the execution testbench
- `default_nettype none`, deterministic assertions, randomized regression with handshake wait-states, and SymbiYosys (`formal/regfile/regfile.sby`, BMC depth 8)

---

## In Progress

- Instruction- and data-bus evolution (prefetch buffer or cache stub plus multi-beat transfers)
- Interrupt prioritization/nesting and richer CSR assertions
- Verification/CI scale-up (additional SymbiYosys targets, regression bundling, GitHub Actions)
- QAR-OS v0.1 boot experiment once timer/IRQ tooling matures

---

## Next Steps (Short-term)

1. Prototype an instruction prefetch buffer and document a multi-beat data handshake for DMEM.
2. Flesh out interrupt prioritization/nesting plus software-visible acknowledgment strategy.
3. Broaden verification: extend SymbiYosys to ALU/decoder, add CSR/interrupt assertions, and begin CI automation.
4. Publish DevKit binaries (`qarsim`) and document contribution/release workflow (ROADMAP.md, CONTRIBUTING.md).

---

## Next Target: QAR-Core v0.7

1. **Memory hierarchy** — Introduce an instruction fetch buffer/cache stub plus configurable data bus widths for FPGA bring-up.
2. **Interrupt robustness** — Prioritized/nested interrupts, better external IRQ acknowledgment, and DevKit demos mixing timer/external sources.
3. **Verification & CI** — Extend SymbiYosys coverage beyond the register file, add CSR/interrupt assertions, and integrate CI so deterministic + random + formal suites run per push.
4. **Tooling & packaging** — Ship `qarsim` binaries, document ROADMAP/CONTRIBUTING, and grow the DevKit example suite.
