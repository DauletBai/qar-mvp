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
| 0x20   | IRQ_RISE     | Rising-edge detection mask (bit=1 latches low→high transitions). |
| 0x24   | IRQ_FALL     | Falling-edge detection mask (bit=1 latches high→low transitions). |
| 0x28   | DB_EN        | Debounce enable mask (bit=1 enables filtering for that input). |
| 0x2C   | DB_CYCLES    | Debounce window length in core cycles (0 selects 1 cycle). |

All registers are 32-bit. Inputs may be debounced in hardware before they appear in `GPIO_IN` (set `DB_EN` and `DB_CYCLES`), so firmware sees a glitch-free value while the edge latches monitor the same filtered signal. Configure `IRQ_RISE` / `IRQ_FALL` per pin to decide which transitions set `IRQ_STATUS`. `IRQ_EN` only gates whether the aggregate IRQ line fires—events are always captured, so software can poll the status register even with interrupts disabled. `ALT_PWM` overrides the corresponding outputs with timer PWM channels, allowing firmware to hand off pins 0–1 to the timer peripheral without losing the original `OUT` values (they revert once the bit is cleared).

## Usage Example (Assembly)

```
.include "common.inc"

    LUI  x5, GPIO_BASE_HI
    ADDI x5, x5, GPIO_BASE_LO

    # Configure pins 0-7 as outputs, bit 8 input
    ADDI x6, x0, 0x00FF
    SW   x6, GPIO_DIR(x5)

    # Enable interrupt + debounce for bit 8
    ADDI x7, x0, 1
    SLLI x7, x7, 8
    SW   x7, GPIO_IRQ_EN(x5)
    SW   x7, GPIO_IRQ_RISE(x5)
    SW   x7, GPIO_IRQ_FALL(x5)
    SW   x7, GPIO_DB_EN(x5)
    ADDI x10, x0, 64
    SW   x10, GPIO_DB_CYCLES(x5)

wait_irq:
    LW   x8, GPIO_IRQ_STATUS(x5)
    AND  x9, x8, x7
    BEQ  x9, x0, wait_irq

    SW   x8, 4(x0)           # store status to DMEM
    LW   x11, GPIO_IN(x5)
    SW   x11, 8(x0)          # snapshot filtered inputs (post-debounce level)
    SW   x7, GPIO_IRQ_STATUS(x5)
    JAL  x0, wait_irq
```

See `devkit/examples/gpio_demo.qar` and `scripts/run_gpio.sh` for a runnable regression that demonstrates interrupt-enabled GPIO inputs inside simulation. Firmware writers can also rely on `devkit/hal/gpio.h` for inline helpers that wrap the register interface (direction, set/clear, IRQ masks, and debounce configuration) instead of poking the offsets manually.
