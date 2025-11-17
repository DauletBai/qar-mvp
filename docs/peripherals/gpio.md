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

All registers are 32-bit. Writing to reserved addresses has no effect.

## Usage Example (Assembly)

```
.include "common.inc"

    LUI  x5, GPIO_BASE_HI
    ADDI x5, x5, GPIO_BASE_LO

    # Configure pins 0-7 as outputs
    ADDI x6, x0, 0x00FF
    SW   x6, GPIO_DIR(x5)

toggle_loop:
    SW   x6, GPIO_OUT(x5)
    JAL  x1, short_delay
    SW   x0, GPIO_OUT(x5)   # clear outputs
    JAL  x1, short_delay
    JAL  x0, toggle_loop
```

See `devkit/examples/gpio_demo.qar` and `scripts/run_gpio.sh` for a runnable regression that blinks the outputs inside simulation.
