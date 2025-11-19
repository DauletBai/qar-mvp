# QAR Industrial Brick (FPGA DevKit Plan)

This document captures the actionable hardware plan derived from the latest readiness review:

- Build a DIN-rail reference controller around the existing QAR Industrial Core RTL.
- Use an accessible FPGA (Lattice ECP5-45K or Gowin GW2A) so we can ship firmware today.
- Package the CPU, CAN/LIN/RS-485 PHYs, isolated GPIO, and PWM power stages into a single "brick" that automotive and industrial customers can plug in immediately.

## Goals

1. **Demonstrator** – prove QAR firmware can toggle real loads (relays, lamps, motors) and speak CAN/LIN on an actual wiring harness.
2. **Evaluation kit** – give Allur, Kia Qazaqstan, UzAuto, ERG etc. a box they can bench-test without building their own board first.
3. **Bridge to ASIC** – freeze the pinout/peripheral mix so the eventual silicon layout is straightforward.

## Architecture Overview

| Block | Implementation | Notes |
|-------|----------------|-------|
| Compute | Lattice ECP5-45K (or Gowin GW2A-18) | 85k LUT class gives headroom for QAR core + peripherals. Use onboard SRAM as tightly-coupled IMEM/DMEM (deterministic latency). |
| Memory | 512 KB SRAM (TCM) inside FPGA, optional QSPI Flash | Prefers deterministic access instead of caches, satisfying hard real-time needs. |
| CAN | TJA1050 (or SN65HVD1040) transceiver + RJ45/automotive connector | Digital `can.v` feeds TX/RX; transceiver handles analog layer. |
| LIN/RS-485 | SN65HVD1474 (LIN) + MAX3485 (RS-485) | Connect to UART DE/RE pins already exposed in RTL. |
| GPIO | 8x isolated inputs via optocouplers, 8x high-side outputs via IPS2031 or MOSFETs | Supports automotive 12 V loads. |
| Power | 9–36 V DC input, buck to 5 V/3.3 V/1.2 V | Accepts vehicle/industrial supply range. |
| Mechanical | 6-module DIN-rail housing (Phoenix/Weidmüller compatible) | Ensures quick adoption in factory panels. |

## Interfaces & Connectors

- **CAN**: 5-pin automotive header (CANH/CANL + power) and DB9 for lab use.
- **LIN**: 3-pin keyed connector.
- **RS-485**: 2-wire + shield terminal block.
- **GPIO**: 2×8 pluggable terminal blocks (inputs isolated, outputs high-side).
- **Programming**: USB-C (FTDI) for JTAG/UART plus dedicated pogo pads for production flashing.
- **Debug UART**: shared with RS-485 using auto-direction logic already present in RTL.

## Firmware / SDK alignment

- Ship the new C-SDK (`crt0`, `hal_init`, HAL drivers) pre-built with each kit.
- Provide reference binaries (`gpio_irq_demo`, `can_loopback`, `lin_auto_header`, `timer_pwm_demo`).
- Extend `qarsim` release process to output ready-to-flash `.bin` files for the FPGA.

## Manufacturing Phases

1. **Prototype PCB (4 layers)** – route FPGA, PHYs, GPIO protection, power tree. Target < 100 × 80 mm board.
2. **Bring-up** – load current RTL bitstream, run regression firmware, verify CAN/LIN loopback on actual cables, drive relays at 12/24 V.
3. **Pilot Batch** – assemble 20–30 units for internal + customer demos.
4. **EMC Testing** – CISPR 25 / EN 61000-6-2 pre-compliance once enclosure is finalized.
5. **Customer Trials** – deploy to Allur/Kia/Astana Motors test labs and ERG/SSGPO plants.

## Open Actions

- [ ] Choose exact FPGA family & toolchain (ECP5 + open-toolflow vs Gowin + vendor tools).
- [ ] Finalize transceiver BOM (TJA1050/SN65HVD1050 for CAN, SN65HVD1474 for LIN, MAX3485 for RS-485).
- [ ] Draft schematic capturing RTL pinout (CAN_TX/RX, UART_DE/RE, PWM pins etc.).
- [ ] Integrate on-board temperature/voltage monitors for automotive diagnostics.
- [ ] Publish flashing instructions (OpenOCD or vendor JTAG) alongside `qarsim` release assets.

This plan follows Gemini's recommendation: focus on delivering a tangible controller before chasing ASIC production. EOF
