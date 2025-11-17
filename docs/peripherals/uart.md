# UART / RS-485 Peripheral

## Base Addresses
- UART0 (`/dev/uart0`): `0x4000_1000`
- UART1 (`/dev/uart1`): `0x4000_2000`

## Register Map (offsets from base)

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | DATA        | TX/RX data register (write pushes to TX FIFO, read pops from RX FIFO). |
| 0x04   | STATUS      | Bit 0: RX ready, Bit 1: TX space, Bit 2: framing error, Bit 3: overrun, Bit 4: TX busy. |
| 0x08   | CTRL        | Bit 0: enable (1 = enabled). Remaining bits reserved for future parity/stop options. |
| 0x0C   | BAUD        | Clock divider `N` (bit period = `N` cycles). |
| 0x10   | IRQ_EN      | Interrupt enable mask (bit 0 = RX ready, bit 1 = TX empty, bit 2 = errors). |
| 0x14   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |
| 0x18   | RS485_CTRL  | Bit 0: auto-direction, bit1: DE polarity, bit2: RE polarity, bit3: manual DE, bit4: manual RE. |

## Behaviour
- TX/RX FIFOs buffer up to 8 bytes. TX raises `IRQ_STATUS[1]` when FIFO empties; RX raises `IRQ_STATUS[0]` when data arrives. Errors latch in `IRQ_STATUS[2]`.  
- When auto-direction is enabled, `rs485_de` asserts while TX is shifting or FIFO non-empty; `rs485_re` deasserts (receive disabled) during transmit. In manual mode the firmware drives DE/RE explicitly via bits [3:4].  
- The aggregated UART interrupt is OR-ed into the external interrupt path; clear conditions by writing `IRQ_STATUS`.

## HAL
See `devkit/hal/uart.h` for C helpers:
```c
#include "hal/uart.h"

void app(void) {
    qar_uart_init(QAR_UART0_BASE, 115200);
    qar_uart_write(QAR_UART0_BASE, 'H');
    int ch = qar_uart_read(QAR_UART0_BASE);
}
```

An upcoming Modbus/RS-485 example will demonstrate full-duplex transaction handling.
