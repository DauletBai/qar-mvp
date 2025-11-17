# SPI Master Controller (Draft Spec)

## Base Address
- SPI0: `0x4000_4000`

## Register Map

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | CTRL        | Bit0: enable, bit1: CPOL, bit2: CPHA, bit3: LSB-first, bits[7:4]: word length - 1. |
| 0x04   | STATUS      | Bit0: TX ready, bit1: RX valid, bit2: busy, bit3: fault (write-1-to-clear). |
| 0x08   | CLKDIV      | SPI clock divider (`f_sck = f_clk / (2 * (CLKDIV+1))`). |
| 0x0C   | TXDATA      | Writing pushes a byte/word into the TX FIFO. |
| 0x10   | RXDATA      | Reading pops the RX FIFO. |
| 0x14   | CS_SELECT   | Bitmask of asserted chip-select lines (up to 8). |
| 0x18   | IRQ_EN      | Interrupt enable bits (RX ready, TX empty, fault). |
| 0x1C   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |

## Behaviour
- The master shifts data MSB-first by default; firmware can toggle CPOL/CPHA to match slave requirements. A small TX/RX FIFO (planned depth = 4) decouples CPU servicing from the shifter.
- `CS_SELECT` lets firmware assert multiple chip-selects simultaneously for broadcast transactions. Writing zero deasserts all CS lines.
- Fault bit latches when the controller is enabled but no device is selected, or when firmware writes to TXDATA while the FIFO is full.
- Upcoming phases will add DMA triggers and optional double-buffered transfers.

## Development Plan
1. **Phase 0:** implement blocking master with 4-entry TX/RX FIFOs and memory-mapped CS lines. Provide HAL helpers for polled transfers.
2. **Phase 1:** add IRQ/DMA integration and optional automatic CS toggling per transfer descriptor.
3. **Phase 2:** extend to dual/quad-SPI and streaming flash access for bootloaders.

See `devkit/hal/spi.h` for the provisional HAL interface. RTL hooks (`qar_spi`) will be integrated into `qar_core` once the timer enhancements settle.
