# Timer / Watchdog Peripheral

## Base Address
- TIMER0: `0x4000_5000`

## Register Map

| Offset | Name              | Description |
|--------|-------------------|-------------|
| 0x00   | CTRL              | Bit0: counter enable, bit1: CMP0 auto-reload, bit2: CMP1 auto-reload. |
| 0x04   | PRESCALE          | Divider value (number of core clocks before incrementing `COUNTER`). |
| 0x08   | COUNTER           | Free-running 32-bit counter (write to set). |
| 0x0C   | STATUS            | Bit0: CMP0 event latched, bit1: CMP1 event, bit2: watchdog expired (write-1-to-clear). |
| 0x10   | IRQ_EN            | Interrupt enables corresponding to STATUS bits. |
| 0x14   | CMP0              | Compare threshold for channel 0. |
| 0x18   | CMP0_PERIOD       | Optional increment added to CMP0 after each match when auto-reload enabled. |
| 0x1C   | CMP1              | Compare threshold for channel 1. |
| 0x20   | CMP1_PERIOD       | Increment added to CMP1 when auto-reload bit is set. |
| 0x24   | WDT_LOAD          | Watchdog reload value (number of prescaled ticks). |
| 0x28   | WDT_CTRL          | Bit0: watchdog enable, bit1: kick/reload (writing `0b11` enables + reloads). |
| 0x2C   | WDT_COUNT         | Read-only snapshot of the watchdog down-counter. |
| 0x30   | PWM0_PERIOD       | Period register for PWM channel 0 (write resets channel counter). |
| 0x34   | PWM0_DUTY         | Duty threshold for PWM channel 0. |
| 0x38   | PWM1_PERIOD       | Period register for PWM channel 1. |
| 0x3C   | PWM1_DUTY         | Duty threshold for PWM channel 1. |
| 0x40   | PWM_STATUS        | Bit0: PWM0 output level, bit1: PWM1 output level. |
| 0x44   | CAPTURE_CTRL      | Bit0: manual capture 0 trigger, bit1: manual capture 1 trigger (write-1 starts capture and latches status). |
| 0x48   | CAPTURE0_VALUE    | Latched timestamp for capture channel 0. |
| 0x4C   | CAPTURE1_VALUE    | Latched timestamp for capture channel 1. |

## Behaviour
- The prescaled counter increments while `CTRL[0]` is set. When `COUNTER == CMPx`, the corresponding status bit latches and, if auto-reload is enabled, the compare register is incremented by `CMPx_PERIOD`, allowing periodic interrupts without CPU intervention.
- STATUS bits are level-sensitive; firmware must write 1 to clear each event. `IRQ_EN` gates the consolidated timer interrupt that is OR-ed into the core’s `irq_timer` line (alongside the CSR `mtime` comparator). Bits 3 and 4 correspond to capture channels 0 and 1.
- The watchdog down-counter decrements on each prescaled tick while enabled. Writing `WDT_CTRL` with bit1 set reloads from `WDT_LOAD` and clears the latched expire status. When it reaches zero, `STATUS[2]` asserts and the timer IRQ line toggles if enabled.
- Writing `WDT_LOAD` while the watchdog is enabled immediately reloads the counter and clears the expire flag. Setting `CTRL[0]=0` freezes both the main counter and watchdog logic.
- PWM channels free-run alongside the main counter. Each channel asserts its output (`PWM_STATUS` bit) when `pwm_counter < duty`, wrapping back to zero after `PERIOD`. Writing a new period register resets the channel’s phase.
- PWM0/PWM1 can be routed to GPIO pins 0 and 1 respectively by setting the corresponding bits in `GPIO_ALT_PWM`, letting firmware hand off pins to the timer without software bit-banging.
- Manual captures take a snapshot of the main counter when firmware writes `CAPTURE_CTRL` with bit0/bit1 set. Future hardware revisions can wire `capture_ctrl` bits to external edges; for now the manual path enables deterministic testing.

## HAL and Example
Use `devkit/hal/timer.h` for helper functions (configure prescaler, enable auto-reload compares, kick the watchdog, drive PWM, and trigger captures). See `devkit/examples/timer_hal_example.c` for a C-level demonstration, and `scripts/run_timer.sh` (which assembles `devkit/examples/timer_demo.qar`) for the regression harness that verifies compare, watchdog, capture, and PWM behavior via `qar_core_timer_tb`.
