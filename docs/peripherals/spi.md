# SPI Master Controller

## Base Address
- SPI0: `0x4000_4000`

## Register Map

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | CTRL        | Bit0: enable, bit1: CPOL, bit2: CPHA, bit3: LSB-first, bit4: internal loopback (route MOSI back to RX for self-test). |
| 0x04   | STATUS      | Bit0: TX FIFO has space, bit1: RX FIFO non-empty, bit2: busy, bit3: fault (write-1-to-clear via `IRQ_STATUS`). |
| 0x08   | CLKDIV      | SPI clock divider (`f_sck = f_clk / (2 * (CLKDIV+1))`). |
| 0x0C   | TXDATA      | Writing pushes an 8-bit word into the TX FIFO. |
| 0x10   | RXDATA      | Reading pops the RX FIFO. |
| 0x14   | CS_SELECT   | Bitmask of asserted chip-select lines (four CS pins, active low). |
| 0x18   | IRQ_EN      | Interrupt enables (bit0 RX ready, bit1 TX empty, bit2 fault). |
| 0x1C   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |

## Behaviour
- Up to four chip-select lines can be asserted simultaneously; the controller keeps them low for the duration of an 8-bit transfer and releases them when the byte completes.  
- TX/RX FIFOs (depth = 4 bytes) decouple the CPU from shift timing. While the FIFO is empty, the TX-empty interrupt (bit1) can be used to queue more data.  
- RX FIFO pushes raise `IRQ_STATUS[0]`; firmware must read `RXDATA` until the FIFO empties to clear the bit.  
- Faults (bit3) latch when firmware writes to TXDATA while the FIFO is full or when a transfer is requested with `CS_SELECT=0`.  
- Current implementation supports polled transfers; future work will add automatic per-transfer CS toggling and DMA hooks.

## Example
`devkit/examples/spi_loopback.qar` initializes the controller, transmits two bytes, polls the RX-ready bit, and stores the received values into DMEM. Run it via:

```sh
./scripts/run_spi.sh
```

During simulation the `qar_core_spi_tb` harness loops MOSI back to MISO, so the received bytes must match the transmitted ones. See `devkit/hal/spi.h` for helper functions that higher-level firmware can call instead of direct register pokes.
