# I²C / SMBus Master (Draft Spec)

## Base Address
- I2C0: `0x4000_4400`

## Register Map

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | CTRL        | Bit0: enable, bit1: start, bit2: stop, bit3: ACK-on-read, bit4: 10-bit addressing. |
| 0x04   | STATUS      | Bit0: busy, bit1: NACK received, bit2: arbitration lost, bit3: RX valid, bit4: TX ready (write-1-to-clear for error bits). |
| 0x08   | CLKDIV      | Divider for SCL (supports Standard/Fast up to 1 MHz). |
| 0x0C   | ADDR        | Target address (bits[6:0] or [9:0]). |
| 0x10   | DATA        | TX/RX data register (write to queue a byte, read to dequeue). |
| 0x14   | CMD         | Bit0: write byte, bit1: read byte, bit2: repeated-start, bit3: clear FIFOs. |
| 0x18   | IRQ_EN      | Interrupt enables (RX ready, TX ready, errors). |
| 0x1C   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |
| 0x20   | TIMEOUT     | Optional clock-stretch timeout counter. |

## Behaviour
- Firmware programs `ADDR`, writes CMD bits to issue START/STOP sequences, and queues bytes in `DATA`. The controller handles ACK/NACK insertion automatically and raises error bits if the slave NACKs the address or data.
- RX/TX FIFOs (depth TBD) decouple CPU response time; reading `DATA` pops the RX FIFO while writing to `DATA` pushes the TX FIFO.
- `TIMEOUT` optionally aborts transactions if clock stretching exceeds a programmable threshold, setting the arbitration-lost bit.
- Future revisions may expose slave mode or SMBus PEC generation.

## Development Plan
1. **Phase 0:** blocking master with IRQ-driven completion, compatible with Standard (100 kHz) and Fast (400 kHz) modes.
2. **Phase 1:** add repeated-start sequences, clock-stretch timeout, and HAL helpers for combined transactions (write-then-read).
3. **Phase 2:** optional slave mode and DMA hooks for high-throughput sensors.

The HAL skeleton in `devkit/hal/i2c.h` documents the intended firmware API. RTL integration (`qar_i2c`) will follow once the SPI block is in place.
