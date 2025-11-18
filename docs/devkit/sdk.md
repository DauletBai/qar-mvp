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
  We need a path from C sources to QAR machine code. Near-term options under evaluation:
  1. **LLVM/Clang backend** — leverage Clang to emit RV32I code, then adapt the backend for QAR-specific CSR/peripheral conventions; convert ELF → `.hex` via a new Go tool or `qhex`.
  2. **C-to-assembly transpiler** — build a minimal translator that emits `.qar` (assembly) for a constrained subset of C, which can then pass through the existing `qarsim` assembler.
  3. **Bootstrapping with RV GCC** — since QAR currently matches RV32I semantics, use an upstream RISC-V GCC/Newlib toolchain as an interim solution until a native backend is ready.

  Initial experiments will focus on option 2 (faster to prototype) while we scope effort for a proper LLVM backend. Once any path can emit `.hex`, we will extend `devkit/cli` with `--c` support to compile, assemble, and (optionally) `qhex --bin` the result.

- Add more C samples (CAN loopback, LIN master, timer PWM) so HAL coverage is complete.
- Prototype the translation flow described above to validate code-gen.
- Build startup/runtime scaffolding (`crt0`, vector tables) and integrate with `devkit/cli`.
