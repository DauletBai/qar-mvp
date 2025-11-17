# QAR-Core Memory Hierarchy Upgrade Plan (v0.7 → v1.0)

The goal of the v0.7/v1.0 CPU milestone is to move beyond the current streaming IMEM/DMEM interfaces and optional direct-mapped instruction cache stub so that the core can sustain industrial workloads with deterministic latency, burst-friendly bus protocols, and hooks for future coherency/caching features.

This document captures the planned stages and requirements. It is intended to guide RTL work, verification, and DevKit integration.

---

## 1. Instruction-Side Roadmap

### 1.1 L0 Prefetch Queue (already implemented)
- Two-entry queue keeps IF fed while EX stalls.
- No burst support; one outstanding request at a time.

### 1.2 L1I Direct-Mapped Cache (v0.7 target)
- Convert the current stub (`ICACHE_ENTRIES`) into a real cache:
  - `line_size_bytes` parameter (4, 8, 16 bytes).
  - Tag RAM + valid bits, optional parity/ECC.
  - Hit-under-miss support for single outstanding miss.
  - Miss refill FSM that issues burst reads (AXI4-lite or custom multi-beat handshake) to fetch complete cache line.
  - Early `if_valid` launch when hit is detected before refill completes.
  - `flush` control from CSR (e.g., `icachectl`).
- Bus adapter requirements:
  - Convert core requests into burst transactions (address alignment, wrapping).
  - Accept `ready` responses per beat; provide `last` signal.
  - Parameter to bypass cache entirely (for deterministic timing, tests).

### 1.3 L1I Enhancements (v1.0 target)
- Set-associative option (2-way) with pseudo-LRU.
- Optional branch predictor/BTB hook that uses the same tag match path.
- Prefetcher that detects sequential bursts and preloads next line.

---

## 2. Data-Side Roadmap

### 2.1 D-Buffer / Store Queue (v0.7 target)
- Introduce a one-entry load buffer and a small store queue (1–2 entries) to absorb DMEM latency.
- Support single outstanding load miss with replay (stall pipeline until data arrives).
- Store queue writes asynchronously to DMEM when `mem_ready` asserts; RAW hazards handled via forwarding.

### 2.2 AXI/AHB Data Adapter
- Define adapter module that maps the simple valid/ready interface to AXI4-lite or AHB-Lite:
  - Burst length parameter.
  - Byte strobes, size encoding, alignment.
  - Error reporting (SLVERR/DECERR) routed to exception logic.

### 2.3 Future L1D Cache (v1.0+)
- Write-through, no-write-allocate policy initially.
- Optional ECC/parity on data RAM.
- Coherency considerations deferred until multi-core roadmap.

---

## 3. CSR / Software Interface

To expose the new memory features to firmware:
- Add `icachecfg`, `icachectl`, `dcachecfg`, `dcachectl` CSRs (R/W):
  - Configure enable/disable bits, line size, associativity (where applicable).
  - Initiate cache flush/invalidate.
- Provide performance counters: `mcacheimiss`, `mcachedmiss`, `mburstcnt`.
- Document programming model in DevKit (how to enable caches, flush on boot, handle exceptions).

---

## 4. Verification Strategy

1. **Unit-level benches**:
   - Instruction cache bench similar to `qar_core_cache_tb` but expanded for multi-line, flush, and burst behavior.
   - Data buffer bench with randomized `mem_ready` latency.
2. **Formal**:
   - Cache controller properties (no stale hits, eventual refill).
   - Store queue ensures ordering.
3. **CI regression**:
   - Include cache-enabled configs in nightly builds.
   - Measure IMEM/DMEM request counts to ensure performance regression alerts.

---

## 5. Implementation Phases

1. **Phase A (v0.7)**:
   - Flesh out current `ICACHE_ENTRIES` stub to real line-based cache with miss refill FSM.
   - Add load buffer/store queue for DMEM.
   - Provide AXI-lite bridge module skeleton (even if top-level still uses simple handshake).
2. **Phase B (v0.8)**:
   - Introduce AXI/AHB top-level wrappers for FPGA/SoC integration.
   - Add cache control CSRs and DevKit hooks.
3. **Phase C (v1.0)**:
   - Optional 2-way associative I-cache, performance counters, and D-cache foundation.
   - Tighten verification/formal coverage.

Each phase should land together with documentation updates, testbenches, and DevKit scripts so that end users can immediately validate the new configuration.

---

## 6. Open Questions

- Exact bus protocol for bursts (AXI4-lite vs. custom). Proposed: start with AXI4-lite style (address + `len`, `last`).
- Minimum viable cache line size (4 vs. 8/16 bytes) given FPGA BRAM width.
- Whether to add DMA/coherency hooks now or wait for the “CPU+peripherals” roadmap stage.

These will be refined as we prototype Phase A.

---

_Last updated: 2024-02-14_
