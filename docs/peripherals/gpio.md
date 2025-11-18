# GPIO Peripheral (QAR-Industrial Core)

## Memory Map

The GPIO block is memory-mapped starting at `0x4000_0000` (see `devkit/examples/common.inc`). Offsets:

| Offset | Name         | Description                            |
|--------|--------------|----------------------------------------|
| 0x00   | DIR          | Direction register (1 = output).       |
| 0x04   | OUT          | Output value (write to drive pins).    |
| 0x08   | IN           | Input readback (read-only).            |
| 0x0C   | OUT_SET      | Writing 1 bits sets corresponding OUT bits. |
| 0x10   | OUT_CLR      | Writing 1 bits clears corresponding OUT bits. |
| 0x14   | IRQ_EN       | Interrupt enable mask (one bit per GPIO). |
| 0x18   | IRQ_STATUS   | Interrupt status (write-1-to-clear). |
| 0x1C   | ALT_PWM      | Bitmask to route timer PWM outputs to GPIO pins (bit0 → pin0 uses PWM0, bit1 → pin1 uses PWM1). |

All registers are 32-bit. When an input pin (DIR=0) transitions from low to high, its bit is set in `IRQ_STATUS`. If the same bit in `IRQ_EN` is 1, the GPIO block asserts its IRQ output (wired into the SoC external interrupt). Firmware clears latched bits by writing 1's to `IRQ_STATUS`. Bits in `ALT_PWM` override the corresponding outputs with timer PWM channels, allowing firmware to hand off pins 0–1 to the timer peripheral without losing the original `OUT` values (they revert once the bit is cleared).

## Usage Example (Assembly)

```
.include "common.inc"

    LUI  x5, GPIO_BASE_HI
    ADDI x5, x5, GPIO_BASE_LO

    # Configure pins 0-7 as outputs, bit 8 input
    ADDI x6, x0, 0x00FF
    SW   x6, GPIO_DIR(x5)

    # Enable interrupt for bit 8
    ADDI x7, x0, 1
    SLLI x7, x7, 8
    SW   x7, GPIO_IRQ_EN(x5)

wait_irq:
    LW   x8, GPIO_IRQ_STATUS(x5)
    AND  x9, x8, x7
    BEQ  x9, x0, wait_irq

    SW   x8, 4(x0)           # store status to DMEM
    SW   x7, GPIO_IRQ_STATUS(x5)
    JAL  x0, wait_irq
```

See `devkit/examples/gpio_demo.qar` and `scripts/run_gpio.sh` for a runnable regression that demonstrates interrupt-enabled GPIO inputs inside simulation.
