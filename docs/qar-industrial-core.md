# QAR-Industrial Core Specification (Phase 1)

This document captures the definition of the “universal industrial computer” we plan to implement on top of QAR-Core. It describes the minimum viable product (MVP) for a small, easy-to-program industrial controller module that can be deployed across automotive, mining, energy, and manufacturing verticals.

---

## 1. Product Identity

**Name:** QAR-Industrial Core (QIC)  
**Form factor:** DIN-rail friendly module (initial FPGA-based reference board)  
**Goal:** Provide a single programmable “brick” that can be tailored via firmware to perform diverse PLC/MCU roles (sensor polling, relay control, CAN gateway, etc.).

---

## 2. Functional Requirements

### 2.1 CPU Subsystem
- RV32IM core (QAR-Core v0.7 baseline): three-stage pipeline, forwarding, load-use interlocks.
- Optional instruction cache (line size configurable) + data buffer with single outstanding miss.
- Full interrupt system (timer + external sources, priority controller, nested support).
- Memory protection hooks (initially PMP-like regions to guard IO vs. program space).

### 2.2 Peripherals (Phase 1)
| Peripheral | Quantity | Notes |
|------------|----------|-------|
| GPIO       | 32 lines | Configurable direction, interrupt-on-change, debouncing. |
| UART/RS-485| 2 ports  | One supports half-duplex RS-485 with automatic DE/RE control for Modbus. Baud up to 1 Mbps. |
| CAN 2.0B   | 1 port   | Optional CAN-FD roadmap. Includes filtering, RX/TX mailboxes. |
| SPI/I2C    | 1 each   | For external sensors/ADC if needed. |
| Timers/PWM | 4 timers | 16-bit timers, capture/compare, PWM modes for motor drives/actuators. |
| Watchdog   | 1        | Windowed watchdog with reset output. |
| RTC        | Optional | Basic counter for timestamping events. |

### 2.3 Memory & Storage
- On-chip SRAM (init 64 KB) for program/data.  
- External QSPI Flash (at least 2 MB) for firmware storage.  
- Optionally attach SDRAM via AXI-lite adapter (future phase).

### 2.4 Power & IO
- Input: 9–36 V DC (industrial supply).  
- Built-in regulators for core/IO rails.  
- Digital IO protection (optocouplers or TVS at board level).  
- Connectors for sensor inputs, relay outputs, and communication buses.

---

## 3. Software & Programmability

### 3.1 HAL and SDK
- Provide C HAL covering GPIO, UART/RS-485, CAN, timers, watchdog.  
- Provide TinyGo/TinyRTOS binding for high-level logic (ease of use).  
- Supply macro-based DSL or YAML-driven generator for ladder-like programs.

### 3.2 Tooling Integration
- Extend DevKit CLI to build for both bare-metal C and TinyGo targets.  
- QAR Programmer utility to flash firmware via UART/CAN/USB bootloader.  
- Reference projects:  
  - **PLC template:** sensor + relay control using GPIO/RS-485.  
  - **Automotive template:** CAN gateway with diagnostic frames.  
  - **Mining safety template:** watchdog + sensor logging.

---

## 4. Hardware Implementation Plan

### Phase 1 (FPGA-based reference)
1. RTL integration:
   - Adopt a two-layer bus: a lightweight AXI-lite bridge for memory (Flash/SRAM) and a peripheral APB window mapped to 0x4000_0000+.  
   - Implement the following blocks with initial address map:  
     | Block | Base Address | Notes |  
     |-------|--------------|-------|  
     | GPIO  | 0x4000_0000  | DIR, OUT, IN, INT_EN/STATUS |  
     | UART0 (RS-232) | 0x4000_1000 | TX/RX, baud config |  
     | UART1 (RS-485) | 0x4000_2000 | Includes DE/RE control |  
     | CAN0  | 0x4000_3000  | Mailboxes, filters |  
     | I2C/SPI shared | 0x4000_4000 | Simple master mode |  
     | Timer/PWM block | 0x4000_5000 | 4 timers with compare/PWM |  
     | Watchdog | 0x4000_6000 | Window + reset control |  
   - Hook up to QAR-Core via memory-mapped registers and IRQ lines (GPIO, UART, CAN, timers).
2. Board:
   - Use affordable FPGA (e.g., Lattice ECP5 or Intel MAX10).  
   - Provide connectors/breakout for IO and comm ports.  
   - Include DC/DC converter and protection circuits.
3. Firmware:
   - Boot ROM + Flash loader.  
   - HAL examples and documentation.

### Phase 2 (Pilot ASIC / hardened module)
1. Replace FPGA with ASIC or hardened SoM.  
2. Add enclosure (DIN rail).  
3. Pursue industrial certification (EMC, temperature, safety).

---

## 6. SoC Block Diagram (Conceptual)

```
                +-------------------+
                |   QAR-Core v0.7   |
                |  RV32IM + caches  |
                +---------+---------+
                          |
        AXI-lite (memory) | APB-lite (peripherals)
                          |
    +---------------------+----------------------+
    |                                            |
+---------+   +---------+   +---------+   +-------------+
| SRAM/   |   | QSPI    |   | GPIO    |   | UART0 (RS232)|
| SDRAM   |   | Flash   |   | 32-bit  |   +-------------+
+---------+   +---------+   +---------+   +-------------+
                                            | UART1 (RS485)
+---------+   +---------+   +---------+   +-------------+
| Cache/  |   | DMA (f) |   | CAN0    |   | SPI/I2C     |
| Buffer  |   |         |   +---------+   +-------------+
                                             |
+---------+   +---------+   +---------+   +-------------+
| Timers/ |   | Watchdog|   | RTC     |   | Future PWM  |
| PWM     |   +---------+   +---------+   +-------------+
```

Legend:  
- AXI-lite handles instruction/data fetch to external Flash/SRAM.  
- APB-lite window hosts low-speed peripherals.  
- Future DMA (f) optional once we add high-speed peripherals.

---

## 5. Next Steps

1. **Finalize SoC block diagram** (bus topology, addresses, interrupts).  
2. **Implement GPIO + UART/RS-485** in RTL, update DevKit.  
3. **Extend SDK** with HAL + TinyGo support.  
4. **Prototype board** (FPGA + connectors).  
5. **Run pilot with launch customers** (automotive, mining, utilities).

This document will evolve as we refine requirements with stakeholders and as RTL/software milestones land.
