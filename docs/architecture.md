# QAR-Core Architecture Specification (Current Milestone: v0.6)

This document captures the architecture, instruction subset, design decisions, and verification strategy for QAR-Core. Each milestone snapshot explains how the core evolves from the original v0.1 proof-of-concept toward an industrial-grade CPU.

---

## 1. Overview

QAR-Core is a 32-bit RV32I-style processor designed and verified entirely with open tools on a MacBook Air M2. The current milestone (v0.5) implements a two-stage pipeline, streaming instruction/data buses, a minimal CSR/trap subsystem, and a Go-based DevKit that assembles and runs QAR programs end-to-end.

The architecture remains intentionally compact:
- 32 x 32-bit register file with combinational reads and synchronous writes (`default_nettype none` across RTL files).
- Combinational ALU for ADD/SUB/logic/shift operations.
- Optional internal ROM/RAM for self-contained simulations, plus valid/ready interfaces for external buses.
- Deterministic simulation, randomized regressions, and SymbiYosys BMC for the register file.

---

## 2. Supported Instructions (RV32I subset @ v0.5)

### Arithmetic / Immediate
- `ADDI`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `LUI`, `AUIPC`

### Memory
- `LW`, `SW` via the streaming data-memory handshake (optional internal RAM still available).

### Control Flow
- Branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- Jumps: `JAL`, `JALR`

### CSR / Trap
- `CSRRW`, `CSRRS`, `CSRRC`
- `ECALL`, `MRET`

These instructions form the public contract advertised by DevKit programs and automated regressions.

---

## 3. QAR-Core v0.1 Summary

### What it can do
- Single-cycle execution of ADDI/ADD programs loaded from `program.hex`.
- 32-register file, combinational ALU, deterministic simulation scripts.

### What it cannot do yet
- No branches, loads/stores, or pipeline.
- Simulation-only; no CSR/trap handling.

---

## 4. QAR-Core v0.2 Summary

### What changed
- ISA widened to include SUB/logic/shift ops already present in the ALU plus `LW`, `SW`, and `BEQ`.
- Separate instruction/data memories (64-word IMEM, 256-word DMEM) initialized from `program.hex` / `data.hex`.
- Reference program sums an integer array and asserts both register and memory state.

### Remaining gaps
- Still single-cycle with no handshake, hazards, or CSR support.
- Branching limited to BEQ.

---

## 5. QAR-Core v0.3 Summary

### What changed
- Added `BNE`, `BLT`, `JAL`, `JALR` so DevKit examples can form structured loops and subroutines.
- Introduced the initial Go-based DevKit (`qarsim`) that emits `program.hex` / `data.hex` from `.qar` source files.
- Added randomized load/store regressions and a SymbiYosys harness for the register file.

### Remaining gaps
- Memory subsystem still single-ported without handshakes.
- No pipeline, hazard detection, or CSR flow.

---

## 6. QAR-Core v0.4 Summary

### What changed
- Data memory now exposes a `mem_valid`/`mem_ready` streaming interface (internal RAM remains for quick sims).
- Added `BGE`/`BGEU` plus a minimal CSR/trap skeleton (`CSRRW`, `ECALL`, `mstatus`, `mtvec`, `mepc`, `mcause`).
- `qarsim` gained `.include` / `.equ` directives with shared macro files and multiple DevKit examples.
- Randomized verification injects wait states, and SymbiYosys (BMC depth 8) is part of the documented workflow.

### Remaining gaps
- Core still single-cycle; instruction fetch is ROM-like with no handshake.
- CSR support is minimal (no CSRRS/CSRRC/MRET).
- Formal coverage stays focused on the register file.

---

## 7. QAR-Core v0.5 Summary

### What changed
- **Two-stage pipeline:** the core now runs an IF/EX pipeline with `valid/ready` instruction streaming plus interlocks for loads and traps. Fetch requests continue even while the execute stage waits on data memory.
- **Streaming instruction bus:** both IMEM and DMEM use the same handshake semantics, and optional internal ROM/RAM blocks hook in through parameters (`USE_INTERNAL_IMEM/DMEM`).
- **CSR depth:** CSRRS, CSRRC, and MRET landed on top of the earlier CSRRW/ECALL path, making ECALL→handler→MRET round-trips possible inside DevKit programs.
- **DevKit integration:** `qarsim` assembles `.qar` (with `.include`, `.equ`, and reusable macros), emits `program.hex`/`data.hex`, and can immediately launch the simulation scripts. Examples include `sum_positive`, `mem_copy`, and `branch_demo`.
- **Verification polish:** deterministic benches assert register/memory state, randomized regressions fuzz the load/store path with wait states, and the SymbiYosys regfile proof is part of the regression checklist.

### What it can do
- Demonstrate a minimal yet realistic RV32I core with streaming buses and CSR-based trap handling.
- Exercise JAL/JALR subroutines plus CSR saves/restores inside the DevKit sum/filter example.

### Remaining gaps
- No bypass/forwarding network yet; hazards rely on simple interlocks.
- Instruction fetch lacks caching/prefetch; IMEM is still a single outstanding request.
- Interrupts beyond ECALL are not wired yet, and formal coverage still targets only the register file.

---

## 8. QAR-Core v0.6 Summary

### What changed
- **Three-stage pipeline:** the core now runs IF→ID→EX with a forwarding network for single-cycle RAW hazards plus an interlock that detects load-use cases. Fetch keeps issuing while EX waits for data, so throughput matches a textbook three-stage microarchitecture.
- **Interrupt and CSR subsystem:** timer and external interrupts feed through `mie/mip`, `mtime/mtimecmp`, and `mstatus` (MIE/MPIE). ECALL, timer IRQ, external IRQ, and MRET now all share the same trap entry code path.
- **Assembler + DevKit:** `qarsim` emits `LUI`, `AUIPC`, `CSRR*`, `ECALL`, and `MRET`, plus `%hi/%lo` label helpers. The new `irq_demo` example programs the timer, handles an external interrupt, and exercises ECALL/MRET with automated verification in `qar_core_exec_tb`.
- **Verification:** the execution bench checks timer/external counters and memory markers, while randomized load/store tests continue to stress the memory handshake via the sum-positive program. Interrupt regression is now part of the default `run_core_exec.sh` flow.

### What it can do
- Demonstrate software-configurable timer interrupts (via `mtimecmp`) and level-sensitive external interrupts with automatic CSR bookkeeping.
- Run ECALL → handler → MRET loops where the handler discriminates between timer IRQs, external IRQs, and ECALLs by reading `mcause`.
- Keep IF/ID busy even when EX is stalled behind a pending load, relying on forwarding for ALU dependencies and explicit interlocks for load-use cases.

### Remaining gaps
- No caches or burst support on IMEM/DMEM; both buses still allow a single outstanding transaction.
- Interrupts are single-priority (timer wins over external) with no nested handling beyond `mstatus.MPIE`.
- Formal coverage remains centered on the register file; ALU/decoder proofs and interrupt-focused assertions are future work.

---

## 9. Roadmap: QAR-Core v0.7

The next iteration targets synthesis-grade behavior and deeper verification:

1. **Memory system evolution:** introduce a small instruction prefetch buffer (or cache stub) plus multi-beat data transactions so the streaming buses look more like FPGA/SoC fabrics.
2. **Interrupt robustness:** prioritize and potentially nest interrupts, add software acknowledgments for external sources, and exercise timer/external IRQ mixes in both DevKit programs and testbenches.
3. **Verification expansion:** push SymbiYosys coverage down into the ALU/decoder, add CSR/interrupt assertions, and wire deterministic + random + formal runs into CI.
4. **Tooling/packaging:** grow DevKit with additional examples (e.g., IRQ-driven memcpy), package the Go CLI as a binary release, and document contribution/onboarding steps.

---

## 10. Register File

- 32 general-purpose registers (`x0..x31`).
- `x0` hardwired to zero regardless of writes.
- Two combinational read ports, one synchronous write port.
- Implementation: `qar-core/rtl/regfile.v` with `default_nettype none` and accompanying `regfile_tb.v` plus SymbiYosys proof (`formal/regfile/regfile.sby`).

---

## 11. ALU

| Operation | Code | Description      |
|-----------|------|------------------|
| ADD       | 0000 | `op_a + op_b`    |
| SUB       | 0001 | `op_a - op_b`    |
| AND       | 0010 | Bitwise AND      |
| OR        | 0011 | Bitwise OR       |
| XOR       | 0100 | Bitwise XOR      |
| SLL       | 0101 | Logical left     |
| SRL       | 0110 | Logical right    |

File: `qar-core/rtl/alu.v` with `alu_tb.v` verifying each opcode.

---

## 12. Instruction Decode

The decode stage (inside `qar_core.v`) parses the standard RV32I fields (opcode, funct3, funct7, rs1/rs2/rd, immediate) and selects the matching execute behavior:
- R-type arithmetic (ADD/SUB/logic/shift) and I-type immediate ops (ADDI).
- I-type loads (`LW`) and S-type stores (`SW`).
- B-type branches (`BEQ/BNE/BLT/BGE/BLTU/BGEU`).
- J-type (`JAL`) and I-type (`JALR`) jumps.
- SYSTEM instructions mapping to CSRRW/CSRRS/CSRRC plus ECALL/MRET.

Decoding drives the ALU operands, write-back multiplexer, branch target logic, and CSR file.

---

## 13. Program Counter (PC)

- 32-bit, word-aligned, stored in the fetch stage (`pc_fetch`).
- Increments by 4 after each non-branch unless a branch/jump/trap overrides it.
- Pipeline flushes enforce control-transfer semantics (jumps, branches, ECALL, MRET).

---

## 14. Instruction Memory

- Fetch stage issues addresses over the streaming bus (`imem_valid`, `imem_addr`) and waits for `imem_ready` + `imem_rdata`.
- Optional internal ROM (`USE_INTERNAL_IMEM=1`) initializes from `program.hex` for pure simulation; otherwise, the core relies on an external bus or the DevKit-provided memory wrapper.
- Default IMEM depth: 64 instructions.
- Example (from `devkit/examples/sum_positive.qar`):

```
00000093   # ADDI x1, x0, 0        ; ptr = base of array
00600113   # ADDI x2, x0, 6        ; len = 6
00000513   # ADDI x10, x0, 0       ; accumulator
0000A183   # LW   x3, 0(x1)
00408093   # ADDI x1, x1, 4
FFF10113   # ADDI x2, x2, -1
0001C463   # BLT  x3, x0, skip_add
00350533   # ADD  x10, x10, x3
FE0116E3   # BNE  x2, x0, loop
000102EF   # JAL  x5, store_sum
12300613   # ADDI x12, x0, 0x123
04C02223   # SW   x12, 68(x0)
0000C06F   # JAL  x0, program_end
04A02023   # store_sum: SW x10, 64(x0)
00028067   #            JALR x0, x5, 0
```

---

## 15. Data Memory

- Streaming handshake identical to IMEM: `mem_valid`, `mem_we`, `mem_addr`, `mem_wdata`, `mem_ready`, `mem_rdata`.
- Optional internal RAM (`USE_INTERNAL_DMEM=1`) preloads from `data.hex` (default 256 words). External memories connect directly otherwise.
- Load-use hazards are interlocked so the execute stage waits for `mem_ready` before retiring.
- Reference `data.hex` stores the six-word array `[1, -2, 3, 4, -5, 6]` followed by result slots at word indices 16 (sum) and 17 (marker `0x123`).

---

## 16. Interrupt & CSR Subsystem

- `mstatus` implements the `MIE` bit (global enable) and `MPIE` bit (saved copy). Trap entry clears `MIE` and copies it into `MPIE`; `MRET` restores `MIE` from `MPIE` while forcing `MPIE=1` per the RV privilege spec.
- `mie` (0x304) currently honors `MTIE` (bit 7) and `MEIE` (bit 11). `mip` mirrors the pending status of the timer comparator (`mtime >= mtimecmp` or `irq_timer` input) and the external interrupt input.
- `mtime` increments every cycle, `mtimecmp` provides the programmable compare point, and firmware re-arms the timer by writing a future deadline to `mtimecmp`.
- External interrupts assert via the top-level `irq_external` pin. All interrupts/exceptions write `mcause`, save `mepc`, and redirect to `mtvec`, so firmware distinguishes timer (`0x80000007`), external (`0x8000000B`), and ECALL (`0x0000000B`) cases by reading `mcause`.
- ECALL/IRQ handlers share the same `trap_entry` while the new DevKit example demonstrates ECALL → handler → `MRET` transitions that update both registers and data memory.

---

## 17. Tooling: `qarsim` CLI

- Located in `devkit/cli` (Go 1.22 workspace via `go.work`).
- Supports `.include` / `.equ`, reusable macro files (`devkit/examples/common.inc`), and both build/run commands.
- `qarsim build` assembles `.qar` + `.data` into `program.hex` / `data.hex`, padding to configurable IMEM/DMEM sizes.
- `qarsim run` chains the build step with `./scripts/run_core_exec.sh` for a turnkey regression.
- Example: `go run ./devkit/cli run --asm devkit/examples/sum_positive.qar --data devkit/examples/sum_positive.data --imem 64 --dmem 256`.

---

## 18. Verification Approach

- **Deterministic benches** — `qar_core_exec_tb` asserts register and memory outputs for the canonical example (including CSR round-trip checks).
- **Randomized regression** — `qar_core_random_tb` shuffles array contents, injects random wait states, and ensures load/store plus pipeline interlocks behave as expected.
- **SymbiYosys** — `formal/regfile/regfile.sby` (BMC depth 8) proves x0 immutability and write-back correctness (`PATH=$HOME/.local/bin:$PATH sby -f formal/regfile/regfile.sby`).

---

## 19. Core Execution Flow (Three-Stage Pipeline)

1. **Fetch (IF):** Issue `imem_valid` with the current PC, capture instructions when `imem_ready` returns, and place them into the IF/ID buffer while the PC keeps marching.
2. **Decode (ID):** Hold one instruction, read its register operands, and evaluate hazards. A forwarding mux observes the EX write-back bus so back-to-back ALU dependencies move without stalls. Load-use matches assert an interlock that freezes IF/ID until the pending `LW` completes.
3. **Execute (EX):** Perform ALU/branch/CSR work, start memory transactions, or retire previously issued loads/stores. When a branch, jump, or trap fires, the pipeline flushes IF/ID and redirects `pc_fetch` to the branch target or `csr_mtvec`/`csr_mepc`.
4. **Memory wait interlock:** Loads and stores assert `mem_valid` and EX holds its slot until `mem_ready` returns so that write-back and forwarding expose consistent data.
5. **Trap/interrupt policy:** ECALL, illegal instructions, timer interrupts, and external interrupts all share the same trap machinery (saving `mepc`, writing `mcause`, pushing `mstatus.MPIE/MIE`), while `MRET` acts like a control-flow redirect to `mepc` with `mstatus` restoration.

---
