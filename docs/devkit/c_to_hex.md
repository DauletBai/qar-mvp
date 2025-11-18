# C → HEX Prototype Plan

To reach “C firmware → `program.hex`” we need two layers:
1. **Frontend** that ingests C source (and our HAL headers).
2. **Backend** that emits QAR machine code (currently RV32I subset).

This doc captures the prototype approach.

## Option 1 — C → `.qar` Transpiler

Shortest path:
1. Use Clang/LLVM front-end to emit LLVM IR or target-independent assembly.
2. Write a thin Go utility (`devkit/tools/ctoq`) that:
   - Accepts C AST/IR (e.g., Clang -S -emit-llvm).
   - Translates a constrained subset (no structs/unions initially) to `.qar` assembly using our existing ISA subset.
3. Feed generated `.qar` into `qarsim build`.

Pros: fast to prototype; reuses assembler. Cons: limited C subset at first; manual register allocation.

## Option 2 — Bootstrapping with RV GCC

Since QAR matches RV32I semantics today, we could:
1. Install a RISC-V GCC toolchain (rv32imc-none-elf).
2. Compile C → ELF.
3. Write a Go helper to extract `.text/.data` into `program.hex`/`data.hex`.

Pros: leverages mature compiler; immediate C support. Cons: generates instructions that QAR might not yet implement (e.g., CSR differences); dependent on RV GCC packaging.

## Option 3 — LLVM Backend

Longer-term goal:
1. Fork LLVM’s RV32 backend, adjust for QAR CSR/peripheral conventions.
2. Upstream a new “target QAR”.
3. Use Clang front-end to produce object files/ELFs.

Pros: future-proof; upstream-friendly. Cons: higher initial cost.

## Prototype Decision

We will start with **Option 2** for speed:
1. Document RV GCC installation (see future doc).
2. Build a Go CLI `devkit/tools/elf2qar` that reads ELF, emits `program.hex`/`data.hex`.
3. Extend `qarsim` with `--c` flag:
   - `qarsim build --c <file.c>` → calls RV GCC → `elf2qar`.
   - `qarsim run --c <file.c>` → same + simulation script.

Parallel work on Option 1 can proceed (for tighter control) but Option 2 gives immediate C support.

## Next Actions

1. Add RV GCC install doc / script.
2. Implement `devkit/tools/elf2qar` (Go).
3. Teach `qarsim` about `--c` (choose priority order: `if cfg.cPath != "" { ... }`).
4. Keep adding HAL demos so we can test the C flow once toolchain is ready.

This file will track progress on the prototype.
