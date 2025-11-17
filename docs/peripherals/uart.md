# UART / RS-485 Peripheral Specification

The UART block provides two instances:
1. UART0 — standard RS-232-style TX/RX for debugging or Modbus master.
2. UART1 — RS-485 capable (half-duplex) with DE/RE control for bus transceivers.

## Memory Map

Base addresses (see `docs/qar-industrial-core.md`):
- UART0: `0x4000_1000`
- UART1: `0x4000_2000`

Offsets:
| Offset | Reg        | Description |
|--------|------------|-------------|
| 0x00   | DATA       | TX/RX data register (write to transmit, read to receive). |
| 0x04   | STATUS     | Bit 0: RX ready, Bit 1: TX ready, Bit 2: framing error, Bit 3: overrun. |
| 0x08   | CTRL       | Bit 0: enable, Bit1: parity enable, Bit2: parity odd/even, Bit3: stop bits, Bit4: loopback. |
| 0x0C   | BAUD       | Clock divider value. |
| 0x10   | IRQ_EN     | Interrupt enable bits (RX ready, TX empty, errors). |
| 0x14   | IRQ_STATUS | Interrupt status (write-1-to-clear). |
| 0x18   | RS485      | (UART1) Bits for DE/RE polarity and auto-direction timing. |

## Integration Notes
- `DATA` register is backed by small TX/RX FIFOs (depth 4–8 words).  
- `STATUS.TX ready` asserts when FIFO has room; `RX ready` asserts when FIFO non-empty.  
- `IRQ_EN/STATUS` wire into the global interrupt controller (per-source lines).
- RS-485 control register toggles DE/RE outputs to drive external transceiver.

## DevKit Usage
- HAL provides `uart_init(port, baud)`, `uart_write(port, byte)`, `uart_read(port)` routines.  
- Example program will configure UART1 for Modbus RTU at 115200 bps and echo bytes.
