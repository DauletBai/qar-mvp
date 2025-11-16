# QAR-Core v0.1 Architecture Specification

This document describes the internal structure, instruction subset, and design principles of the QAR-Core v0.1 minimal prototype processor.

---

## 1. Overview

QAR-Core v0.1 is a minimal 32-bit RISC-style CPU designed to validate the feasibility of building a sovereign processor architecture for Kazakhstan.

It executes a small subset of the RV32I instruction set:

- `ADDI` (I-type)
- `ADD`  (R-type)

This version is intentionally simple:
- single-cycle execution model
- no pipeline
- no branching logic yet
- no memory load/store
- instruction memory initialized from `program.hex`

---

## 2. Register File

The register file implements:
- 32 general-purpose registers (x0..x31)
- x0 is hardwired to zero
- 2 read ports
- 1 write port
- synchronous write, combinational reads

File: `qar-core/rtl/regfile.v`

---

## 3. ALU

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

## 4. Instruction Decode

The core decodes instructions according to RV32I encoding:
- opcode
- funct3
- funct7
- rs1, rs2, rd
- immediate (I-type)

Currently supported:
- `ADDI` (opcode `0010011`)
- `ADD`  (opcode `0110011`, funct3 = 000, funct7 = 0000000)

---

## 5. Program Counter (PC)

The PC is:
- 32-bit
- word-aligned
- increments by 4 every cycle

---

## 6. Instruction Memory

Instruction memory consists of 8 words:

imem[0], imem[1], …, imem[7]

It is initialized at simulation start via:

$readmemh(“program.hex”, imem);

A typical example program:

00500093   # ADDI x1, x0, 5
00300113   # ADDI x2, x0, 3
002081B3   # ADD  x3, x1, x2

## 7. Core Execution Flow
	1.	Fetch instruction at PC
	2.	Decode fields
	3.	Read registers
	4.	Execute ALU operation
	5.	Write back result
	6.	Increment PC by 4

This is a single-cycle model.

⸻

## 8. Future Extensions

Planned expansions for QAR-Core v0.2:
	•	LOAD/STORE (LW, SW)
	•	BRANCH (BEQ)
	•	immediate shifts
	•	basic pipeline (optional)
	•	better memory model
	•	system call interface for QAR-OS