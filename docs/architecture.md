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

## 5. Register File

The register file implements:
- 32 general-purpose registers (x0..x31)
- x0 is hardwired to zero
- 2 read ports
- 1 write port
- synchronous write, combinational reads

File: `qar-core/rtl/regfile.v`

---

## 6. ALU

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

## 7. Instruction Decode

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

## 8. Program Counter (PC)

The PC is:
- 32-bit
- word-aligned
- increments by 4 every cycle

---

## 9. Instruction Memory

Instruction memory now consists of 64 words (aligned to 4-byte boundaries) so the sum-array routine fits comfortably with space for future experiments. It is initialized at simulation start via:

$readmemh("program.hex", imem);

Example (sum-array) sequence:

```
00000093   # ADDI x1, x0, 0
00400113   # ADDI x2, x0, 4
00000513   # ADDI x10, x0, 0
0000A183   # LW   x3, 0(x1)
00350533   # ADD  x10, x10, x3
00408093   # ADDI x1, x1, 4
FFF10113   # ADDI x2, x2, -1
00010463   # BEQ  x2, x0, done
FE0006E3   # BEQ  x0, x0, loop
00A02823   # SW   x10, 16(x0)
```

## 10. Data Memory

- 256-word data RAM (`dmem[0]..dmem[255]`)
- initialized from `data.hex` (first four entries set to 1,2,3,4; entry 4 reserved for the result)
- single read/write port; loads are combinational reads, stores occur on the clock edge
- register-file addresses always treated as byte addresses, but the MVP assumes word alignment

---

## 11. Core Execution Flow
	1.	Fetch instruction at PC
	2.	Decode fields
	3.	Read registers
	4.	Execute ALU operation
	5.	Write back result
	6.	Increment PC by 4

This is a single-cycle model.

⸻

## 12. Target for QAR-Core v0.3

With the v0.2 baseline stabilized, the next milestone focuses on ecosystem-grade robustness:

- **ISA extensions**: add additional control-flow primitives (`BNE`, `BLT`, `JAL`, `JALR`) so example programs can branch/jump without workarounds.
- **Tooling integration**: stand up the Go-based DevKit (`qarsim`, minimal assembler) to automate `program.hex` generation and simulation orchestration.
- **Verification depth**: expand assertion coverage, introduce randomized test cases, and prepare for SymbiYosys/other formal checks.
- **System hooks**: define a cleaner external memory interface (AXI-lite-style or simple handshake) so the core can drop into FPGA/SoC testbeds later.
