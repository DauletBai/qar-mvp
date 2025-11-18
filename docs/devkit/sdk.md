# QAR DevKit — Firmware SDK Roadmap

Now that HAL headers exist for all major peripherals (GPIO, UART/LIN, CAN, SPI, I²C, timers, etc.) and we introduced a portable C tool (`qhex`), the next milestone is a firmware SDK that lets integrators author QAR applications in C instead of hand-written `.qar` assembly.

This document tracks the plan and seeds the first C sample.

## Near-Term Goals

1. **C Examples Using HALs**  
   Start shipping small firmware snippets written in C that exercise the existing HALs. These will serve as references for automotive teams and will eventually be compiled by a QAR-aware toolchain. The new `devkit/examples/c/gpio_irq_demo.c` is the inaugural sample.

2. **Toolchain Evaluation**  
   Evaluate pathways for compiling C to QAR machine code. Options include:
   - Adapting LLVM/Clang with a custom backend.
   - Building a minimalist C-to-assembly translator that emits `.qar` source.
   - Leveraging existing RISC-V GCC as a bootstrap (while QAR ISA remains a strict RV32I subset).

3. **Build Integration**  
   Once a compiler path exists, integrate it into `devkit/cli` so `qarsim` can accept `--c src.c` and emit `program.hex`, optionally invoking `qhex --bin`.

4. **Firmware Libraries**  
   Provide basic runtime support (startup code, interrupt vector table, simple scheduler, drivers).

## C Examples

- `devkit/examples/c/gpio_irq_demo.c` shows how to configure GPIO outputs, enable debounced interrupts on bit 8, and blink LEDs via the GPIO/TIMER HALs.
- `devkit/examples/c/can_loopback.c` configures CAN loopback with filter bypass/quiet mode to demonstrate how firmware can exercise the CAN HAL, poll RX FIFO entries, and toggle diagnostics modes entirely from C.
- `devkit/examples/c/lin_auto_header.c` drives the UART HAL’s LIN auto-break/auto-header path so firmware can issue LIN master headers without manual byte-by-byte assembly.
- `devkit/examples/c/timer_pwm_demo.c` routes timer PWM outputs onto GPIO pins 0/1, sweeps duty cycles, and samples capture registers for diagnostics.
- `devkit/examples/c/i2c_loopback.c` mirrors the assembly loopback test by issuing START/WRITE/STOP sequences entirely via the I²C HAL.
- `devkit/examples/c/spi_loopback.c` performs two byte exchanges using the SPI HAL’s loopback mode.

Example snippet from the GPIO demo:

```c
#include "hal/gpio.h"
#include "hal/timer.h"

int main(void) {
    qar_gpio_config_dir(QAR_GPIO0_BASE, 0x00FFu);
    const uint32_t button_mask = 1u << 8;
    qar_gpio_config_irq(QAR_GPIO0_BASE, button_mask, button_mask, button_mask);
    qar_gpio_config_debounce(QAR_GPIO0_BASE, button_mask, 64);
    qar_timer_init(QAR_TIMER0_BASE, 0, QAR_TIMER_CTRL_ENABLE);

    while (1) {
        if (QAR_GPIO_IRQ_STATUS(QAR_GPIO0_BASE) & button_mask) {
            qar_gpio_set(QAR_GPIO0_BASE, 0x1u);  // blink LED
            qar_gpio_clear_irq(QAR_GPIO0_BASE, button_mask);
        }
    }
}
```

Today this compiles with any host compiler (`clang -c devkit/examples/c/gpio_irq_demo.c -Idevkit`), but executing it would obviously require the QAR hardware. The goal is to swap the host compiler for the future QAR toolchain, producing `.hex` images automatically.

## Next Steps

- **Prototype C→HEX Flow**  
  The detailed plan lives in `docs/devkit/c_to_hex.md`. Summary:
  1. Start with a RISC-V GCC bootstrap path (QAR currently mirrors RV32I), compile C into ELF, then convert to `.hex` via a new Go helper (`elf2qar`).
  2. In parallel, explore a minimalist C→`.qar` transpiler for tighter control.
  3. Longer-term, evaluate a dedicated LLVM backend.

  Once the bootstrap path works, we will extend `devkit/cli` with a `--c` option (compiler + `elf2qar`, optionally `qhex --bin`).

- Prototype the translation flow described above to validate code-gen.
- Build startup/runtime scaffolding (`crt0`, vector tables) and integrate with `devkit/cli`.
