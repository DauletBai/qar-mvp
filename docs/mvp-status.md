# 3. **MVP progress report: `docs/mvp-status.md`**

# QAR-MVP Progress Report

---

## Overview

The project began with the goal of creating a functional RV32I-style prototype CPU entirely on a MacBook Air M2 using open tools.

---

## Milestone Status

- **QAR-Core v0.1 — DONE.** Minimal RV32I execution path validated in simulation with automated testbenches.
- **QAR-Core v0.2 — DONE.** RV32I subset expanded (SUB/logic/shifts/LW/SW/BEQ), data RAM introduced, and the sum-array reference program verified via assertions.

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
- verifies that x10 = sum(array) = 10 and `dmem[4] = 10` (v0.2)

### ✔ QAR-Core v0.2 Micro-program
- Reference array stored in `data.hex`, execution result stored in register + RAM
- LW/SW/BEQ exercised inside the same test
- `default_nettype none` + assertions added to RTL/testbenches

---

## In Progress

- DevKit CLI (`qarsim`) to orchestrate simulations
- Go-based assembler / program-to-hex converter
- Formal/read-coverage preparation and randomized regression benches
- QAR-OS v0.1 boot model (blocked on richer ISA + tooling)

---

## Next Steps (Short-term)

1. Extend ISA control flow (BNE/BLT/JAL/JALR) to unblock richer firmware.
2. Build the Go-based DevKit CLI + minimal assembler so programs no longer require manual hex math.
3. Add randomized/negative test cases plus regression scripts (SymbiYosys prep).
4. Create example programs under `devkit/examples/` (array sum, mem copy, simple loop).
5. Document contribution process (ROADMAP.md, CONTRIBUTING.md skeleton).

---

## Next Target: QAR-Core v0.3

1. **Control flow richness** — Add BNE/BLT plus jump instructions so DevKit examples can branch/jump natively.
2. **Toolchain** — Ship the initial `qarsim` CLI + assembler to automate `program.hex`/`data.hex` generation and simulation execution.
3. **Memory interface** — Define a clean load/store handshake so the core can interface with external RAM or SoC fabrics (prep for FPGA bring-up).
4. **Verification** — Layer randomized stimulus + SymbiYosys-ready modules to raise confidence before taping in more ISA features.
