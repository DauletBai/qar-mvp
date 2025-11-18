# I²C / SMBus Master

## Base Address
- I2C0: `0x4000_4400`

## Register Map

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | CTRL        | Bit0: enable, bit4: loopback ACK/self-test (forces ACK low). |
| 0x04   | CLKDIV      | Divider to derive SCL; actual SCL toggles every `(CLKDIV+1)` core cycles. |
| 0x08   | STATUS      | Bit0: busy, bit1: RX FIFO non-empty, bit2: TX FIFO empty, bit3: fault/NACK. |
| 0x0C   | IRQ_EN      | Interrupt enable bits (bit0 RX ready, bit1 TX empty, bit2 fault). |
| 0x10   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |
| 0x14   | TXDATA      | Write pushes a byte into the TX FIFO. |
| 0x18   | RXDATA      | Read pops a byte from the RX FIFO. |
| 0x1C   | CMD         | Bit0: START, bit1: STOP, bit2: WRITE byte (consumes TX FIFO), bit3: READ byte (pushes RX FIFO). Auto-cleared on acceptance. |

## Behaviour
- Firmware sequences transactions by loading bytes into `TXDATA` and toggling `CMD` bits for START/STOP/WRITE/READ. Ack/Nack handling is implicit; a missing ACK raises the fault bit which firmware clears via `STATUS`/`IRQ_STATUS`.
- TX/RX FIFOs (depth = 4 bytes) absorb CPU latency so START/STOP can be issued back-to-back. `STATUS[1:2]` and the IRQ bits allow polled or interrupt-driven servicing.
- The current implementation assumes a single master environment and focuses on generating basic START → address → data → STOP flows suitable for EEPROMs and sensors; future work will add repeated-start and clock-stretch tolerance.

## Example
`devkit/examples/i2c_loopback.qar` configures the controller for a simple self-loop (CTRL[4] enables an internal ACK), issues a START + two writes + STOP, and stores the resulting STATUS word in DMEM. Run it via `./scripts/run_i2c.sh`. The HAL (`devkit/hal/i2c.h`) offers helper functions for initializing the controller, staging bytes, issuing commands, and checking status.
