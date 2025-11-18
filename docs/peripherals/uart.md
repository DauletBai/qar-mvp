# UART / RS-485 Peripheral

## Base Addresses
- UART0 (`/dev/uart0`): `0x4000_1000`
- UART1 (`/dev/uart1`): `0x4000_2000`

## Register Map (offsets from base)

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | DATA        | TX/RX data register (write pushes to TX FIFO, read pops from RX FIFO). |
| 0x04   | STATUS      | Bit0: RX ready, bit1: TX space, bit2: framing error, bit3: RX overrun, bit4: TX busy, bit5: parity error, bit6: idle gap latched, bit7: LIN break detected, bit8: LIN header captured, bit9: LIN sync mismatch. |
| 0x08   | CTRL        | Bit0: enable, bit1: parity enable, bit2: odd parity (0 = even), bit3: two stop bits (0 = 1 stop), bit5: LIN mode enable. |
| 0x0C   | BAUD        | Clock divider `N` (bit period = `N` cycles). |
| 0x10   | IRQ_EN      | Interrupt enable mask (bit0 = RX ready, bit1 = TX empty, bit2 = errors, bit3 = idle gap, bit4 = LIN break, bit5 = LIN header ready). |
| 0x14   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |
| 0x18   | RS485_CTRL  | Bit0: auto-direction, bit1: DE polarity invert, bit2: RE polarity invert, bit3: manual DE, bit4: manual RE. |
| 0x1C   | IDLE_CFG    | Idle gap detector in core clock cycles (0 disables detection). |
| 0x20   | LIN_CTRL    | Programmable break length (in bit periods) for LIN mode. |
| 0x24   | LIN_CMD     | Bit0: request break, bit1: clear LIN break status/interrupt, bit2: manually arm header capture (flushes RX FIFO and waits for break delimiter). |
| 0x28   | LIN_HEADER  | Read-only: {ID[15:8], Sync[7:0]} captured from the most recent LIN header. |

## Behaviour
- TX/RX FIFOs buffer up to 8 bytes. The TX path now inserts parity (even/odd selectable) and one or two stop bits based on `CTRL`. `IRQ_STATUS[1]` asserts when the TX FIFO drains.  
- RX logic samples start/data/parity/stop bits, performs parity comparison, detects framing errors and overruns, and raises the consolidated error interrupt (`IRQ_STATUS[2]`). `STATUS[5:2]` latch the specific cause until firmware clears the interrupt.  
- `IDLE_CFG` programs a cycle-count threshold that approximates the Modbus “3.5 characters” gap. When no RX activity occurs for that duration the idle interrupt (`IRQ_STATUS[3]`) fires and `STATUS[6]` latches until cleared.  
- When auto-direction is enabled (`RS485_CTRL[0]=1`), `rs485_de` mirrors TX activity and `rs485_re` deasserts during transmit to protect the half-duplex bus. Manual mode exposes DE/RE bits directly, plus optional polarity inversion.  
- The aggregated UART interrupt is OR-ed into the core’s external interrupt path; clear conditions by writing `IRQ_STATUS`.  
- CTRL[5] switches the peripheral into LIN mode: `LIN_CMD[0]` emits a programmable break (`LIN_CTRL` bit periods) and latches `STATUS[7]`/`IRQ_STATUS[4]`, while the receiver flags the same bits when it observes a long-low pulse on RX. Firmware clears the condition via `LIN_CMD[1]`. Whenever a break is detected, the RX FIFO is flushed to guarantee the next bytes belong to the new header.
- In LIN mode, firmware can arm header capture via `LIN_CMD[2]` (or rely on automatic arm on detected breaks). Arming also clears the RX FIFO and forces the receiver to wait for the mandatory break delimiter before accepting the next start bit. The subsequent Sync/ID bytes are latched into `LIN_HEADER`, `STATUS[8]` indicates validity, `STATUS[9]` reports a sync mismatch, and `IRQ_STATUS[5]` can wake the CPU to supply or consume payload data.

## HAL
See `devkit/hal/uart.h` for the updated HAL which exposes configuration helpers for baud, parity, idle detection, interrupts, and RS-485 direction control. The `devkit/examples/uart_rs485.qar` firmware (run via `scripts/run_uart.sh`) demonstrates a full Modbus-friendly loopback: it enables parity, transmits two bytes, waits for auto-looped RX data, and stores an idle-gap interrupt snapshot in DMEM for the regression testbench.
