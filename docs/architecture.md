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
- `BGE`
- `BLTU`
- `BGEU`
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

## 6. QAR-Core v0.4 Summary

### What changed
- Data memory access now flows through a proper `mem_valid`/`mem_ready` streaming interface, while an internal RAM remains available behind the `USE_INTERNAL_MEM` parameter for pure simulation.
- Additional branches (`BGE`, `BGEU`) landed, and the core now exposes a minimal CSR/trap skeleton (`CSRRW`, `ECALL`, `mstatus`, `mtvec`, `mepc`, `mcause`) so DevKit programs can demonstrate supervisor-style flows.
- The Go DevKit (`qarsim`) understands `.include` / `.equ` directives, which enables shared macro files like `devkit/examples/common.inc` and new example programs (filtered sum, mem copy, branch demo).
- Verification injects randomized memory wait states and the SymbiYosys harness runs as part of the documented workflow (`sby -f formal/regfile/regfile.sby` at BMC depth 8).

### Remaining gaps
- Still single-cycle with manual stalls on loads/stores; no hazard detection or interrupt return path.
- CSR support is intentionally tiny (no CSRRS/CSRRC/MRET), and instruction fetch remains ROM-like.
- SymbiYosys only covers the register file today; datapath proofs remain TODO.

---

## 7. Register File

The register file implements:
- 32 general-purpose registers (x0..x31)
- x0 is hardwired to zero
- 2 read ports
- 1 write port
- synchronous write, combinational reads

File: `qar-core/rtl/regfile.v`

---

## 8. ALU

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

## 9. Instruction Decode

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
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` (opcode `1100011`, funct3 selects branch type)
- `JAL` (opcode `1101111`) and `JALR` (opcode `1100111`, funct3 = `000`)
- `CSRRW` / `ECALL` (opcode `1110011`) for the minimal CSR/trap implementation

---

## 10. Program Counter (PC)

The PC is:
- 32-bit
- word-aligned
- increments by 4 every cycle

---

## 11. Instruction Memory

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

## 12. Data Memory

- External handshake: the core drives `mem_valid`, `mem_we`, `mem_addr`, `mem_wdata` and waits for `mem_ready`. Loads capture `mem_rdata` once `mem_ready` asserts, stalling the PC until the transaction completes.
- Optional internal RAM (parameter `USE_INTERNAL_MEM=1`) still exists for lightweight simulations; it preloads from `data.hex` and responds immediately.
- Reference default data sets the first six entries to `[1, -2, 3, 4, -5, 6]`; word indices 16 (`0x40`) and 17 (`0x44`) store the filtered sum and return marker respectively.

---

## 13. Tooling: `qarsim` CLI

- Go-based CLI located under `devkit/cli`, wired up through the repository `go.work`.
- Supports `.include` and `.equ` directives so shared macro files (`devkit/examples/common.inc`) can define addresses/lengths once and be reused by `sum_positive`, `mem_copy`, and `branch_demo`.
- `qarsim build` assembles `.qar` files + optional data descriptions into `program.hex` / `data.hex`, padding to configurable IMEM/DMEM depths.
- `qarsim run` performs the build step and then invokes `./scripts/run_core_exec.sh` so end-to-end regressions are one command away.
- Example: `go run ./devkit/cli run --asm devkit/examples/sum_positive.qar --data devkit/examples/sum_positive.data`.

---

## 14. Verification Approach

- **Deterministic benches** — `qar_core_exec_tb` asserts both register and memory outputs for the canonical example.
- **Randomized regression** — `qar_core_random_tb` shuffles the first six data words with `$random` and injects random memory wait states to stress the load/store handshake logic.
- **SymbiYosys** — `formal/regfile/regfile.sby` (BMC depth 8) proves x0 immutability and write-back correctness for the register file (`PATH=$HOME/.local/bin:$PATH sby -f formal/regfile/regfile.sby`).

---

## 15. Core Execution Flow
	1.	Fetch instruction at PC
	2.	Decode fields
	3.	Read registers
	4.	Execute ALU operation
	5.	Write back result
	6.	Increment PC by 4

This is a single-cycle model.

⸻

## 16. Target for QAR-Core v0.5

With the streaming DMEM interface, CSR/trap skeleton, and richer DevKit in place, the next milestone focuses on synthesis-grade behavior:

- **Pipeline & hazards** — explore a two-stage pipeline (IF/EX) or lightweight microcode so loads/stores no longer freeze fetch, and document how hazards/interlocks will work.
- **CSR/interrupt depth** — add `CSRRS/CSRRC`, `MRET`, and a basic interrupt entry/exit so ECALL/IRQ flows can round-trip.
- **Instruction-memory interface** — expose a handshake for instruction fetch (or an optional instruction cache) so the core can natively bind to FPGA block RAMs.
- **Verification automation** — broaden SymbiYosys coverage beyond the register file (ALU/datapath modules) and hook the regression + formal runs into CI (GitHub Actions).
