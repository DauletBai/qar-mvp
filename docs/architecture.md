# QAR-Core v0.1 Architecture Specification

This document describes the internal structure, instruction subset, and design principles of the QAR-Core v0.1 minimal prototype processor.

---

## 1. Overview

QAR-Core v0.1 is a minimal 32-bit RISC-style CPU designed to validate the feasibility of building a sovereign processor architecture for Kazakhstan.

This first milestone executes only the smallest useful slice of RV32I so that the full tool flow and testbenches stay easy to reason about.

---

## 2. Supported Instructions (RV32I subset)

- `ADDI`
- `ADD`
- `SUB`
- `AND`
- `OR`
- `XOR`
- `SLL`
- `SRL`
- `LW`
- `SW`
- `BEQ`
- `BNE`
- `BLT`
- `JAL`
- `JALR`

---

## 3. QAR-Core v0.1 Summary

### What it can do
- Single-cycle execution of ADDI/ADD programs loaded from `program.hex`
- 32 x 32-bit register file with combinational reads and synchronous writes
- Combinational ALU that already supports ADD/SUB/AND/OR/XOR/SLL/SRL for future ISA growth
- Deterministic simulation via the supplied Icarus Verilog testbenches

### What it cannot do yet
- No branches or jumps, so control flow is strictly linear
- No load/store data path; there is only instruction memory
- No pipeline or hazard handling
- No integration with real memory or peripherals; execution exists only in simulation

---

## 4. QAR-Core v0.2 Summary

### What changed
- RV32I subset expanded to cover the basic arithmetic/logic ops already in the ALU plus memory access (`LW`, `SW`) and a control-flow primitive (`BEQ`).
- Separate instruction/data memories (64-word IMEM, 256-word DMEM) are initialized from `program.hex` and `data.hex`.
- Reference program: sum an integer array stored in data RAM, place the result in `x10`, and store the value back to RAM to verify both LW and SW.
- Testbench now asserts both register state (`x10 = 10`) and memory state (`dmem[4] = 10`), giving deterministic evidence of the micro-architecture.

### Remaining gaps
- Still single-cycle (no pipeline, hazard handling, or multi-stage memory interface).
- No exception handling or CSR support.
- Branch support limited to `BEQ`; `BNE`, `BLT`, jumps, etc. stay future work.

---

## 5. QAR-Core v0.3 Summary

### What changed
- Control flow widened with `BNE`, `BLT`, `JAL`, and `JALR`, enabling structured loops without BEQ-only workarounds and subroutine calls with return-address registers.
- DevKit CLI (`qarsim`) now assembles human-readable `.qar` files, emits `program.hex` / `data.hex`, and can orchestrate simulations end-to-end.
- Verification expanded with deterministic execution checks, a randomized load/store regression (`qar_core_random_tb`), and a SymbiYosys harness that proves register-file invariants (`formal/regfile/regfile.sby`).

### Remaining gaps
- Memory subsystem still single-ported with no handshake exposed to the outside world.
- No pipeline, hazard detection, or interrupts yet.
- SymbiYosys coverage currently limited to the register file; core/ALU proofs remain future work.

---

## 6. Register File

The register file implements:
- 32 general-purpose registers (x0..x31)
- x0 is hardwired to zero
- 2 read ports
- 1 write port
- synchronous write, combinational reads

File: `qar-core/rtl/regfile.v`

---

## 7. ALU

The ALU performs the following operations:

| Operation | Code | Description |
|----------|------|-------------|
| ADD      | 0000 | a + b       |
| SUB      | 0001 | a - b       |
| AND      | 0010 | a & b       |
| OR       | 0011 | a \| b      |
| XOR      | 0100 | a ^ b       |
| SLL      | 0101 | shift-left  |
| SRL      | 0110 | shift-right |

File: `qar-core/rtl/alu.v`

---

## 8. Instruction Decode

The core decodes instructions according to RV32I encoding:
- opcode
- funct3
- funct7
- rs1, rs2, rd
- immediate (I-type)

Currently supported cases:
- `ADDI` (opcode `0010011`, funct3 = `000`)
- `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL` (opcode `0110011`, funct3/funct7 decode per RV32I spec)
- `LW`  (opcode `0000011`, funct3 = `010`)
- `SW`  (opcode `0100011`, funct3 = `010`)
- `BEQ` (opcode `1100011`, funct3 = `000`)

---

## 9. Program Counter (PC)

The PC is:
- 32-bit
- word-aligned
- increments by 4 every cycle

---

## 10. Instruction Memory

Instruction memory now consists of 64 words (aligned to 4-byte boundaries) so the sum-array routine fits comfortably with space for future experiments. It is initialized at simulation start via:

$readmemh("program.hex", imem);

Example (sum-positive) sequence:

```
00000093   # ADDI x1, x0, 0        ; ptr = 0
00600113   # ADDI x2, x0, 6        ; len = 6
00000513   # ADDI x10, x0, 0
0000A183   # LW   x3, 0(x1)
00408093   # ADDI x1, x1, 4
FFF10113   # ADDI x2, x2, -1
0001C463   # BLT  x3, x0, skip_add
00350533   # ADD  x10, x10, x3
FE0116E3   # BNE  x2, x0, loop
000102EF   # JAL  x5, store_sum
12300613   # ADDI x12, x0, 0x123   ; marker
04C02223   # SW   x12, 68(x0)
0000C06F   # JAL  x0, program_end
04A02023   # store_sum: SW x10, 64(x0)
00028067   #          JALR x0, x5, 0
```

## 11. Data Memory

- 256-word data RAM (`dmem[0]..dmem[255]`)
- initialized from `data.hex` (first six entries set to `[1, -2, 3, 4, -5, 6]`)
- single read/write port; loads are combinational reads, stores occur on the clock edge
- register-file addresses always treated as byte addresses, but the MVP assumes word alignment
- addresses `64` (word index 16) and `68` (index 17) are used by the reference program to store the sum and a return marker

---

## 12. Tooling: `qarsim` CLI

- Go-based CLI located under `devkit/cli`, wired up through the repository `go.work`.
- `qarsim build` assembles `.qar` files + optional data descriptions into `program.hex` / `data.hex`, padding to configurable IMEM/DMEM depths.
- `qarsim run` performs the build step and then invokes `./scripts/run_core_exec.sh` so end-to-end regressions are one command away.
- Example: `go run ./devkit/cli run --asm devkit/examples/sum_positive.qar --data devkit/examples/sum_positive.data`.

---

## 13. Verification Approach

- **Deterministic benches** — `qar_core_exec_tb` asserts both register and memory outputs for the canonical example.
- **Randomized regression** — `qar_core_random_tb` shuffles the first six data words with `$random` and checks that `uut.rf_inst.regs[10]` / `uut.dmem[16]` match recomputed sums across multiple iterations.
- **SymbiYosys** — `formal/regfile/regfile.sby` proves x0 immutability and write-back correctness for the register file (`sby -f formal/regfile/regfile.sby`).

---

## 14. Core Execution Flow
	1.	Fetch instruction at PC
	2.	Decode fields
	3.	Read registers
	4.	Execute ALU operation
	5.	Write back result
	6.	Increment PC by 4

This is a single-cycle model.

⸻

## 15. Target for QAR-Core v0.4

With qarsim, richer control flow, and baseline formal hooks in place, the next milestone focuses on system integration:

- **ISA/Flow control** — add the remaining branch/jump primitives (`BGE`, `BGEU`, `JALR` offsets with register indirection) plus rudimentary trap/CSR stubs.
- **Memory interface** — define and implement an external data-memory handshake (AXI-lite style) so the core can plug into FPGA testbenches without touching internal RAM.
- **Pipeline prep** — document the single-cycle hazards that will need attention, then experiment with a simple two-stage pipeline or microcode-friendly scheduler.
- **Tooling** — extend `qarsim` with assembler conveniences (labels, numeric expressions, includes) and bundle multiple example programs under `devkit/examples/`.
