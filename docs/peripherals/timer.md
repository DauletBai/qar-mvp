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

## Behaviour
- The prescaled counter increments while `CTRL[0]` is set. When `COUNTER == CMPx`, the corresponding status bit latches and, if auto-reload is enabled, the compare register is incremented by `CMPx_PERIOD`, allowing periodic interrupts without CPU intervention.
- STATUS bits are level-sensitive; firmware must write 1 to clear each event. `IRQ_EN` gates the consolidated timer interrupt that is OR-ed into the core’s `irq_timer` line (alongside the CSR `mtime` comparator).
- The watchdog down-counter decrements on each prescaled tick while enabled. Writing `WDT_CTRL` with bit1 set reloads from `WDT_LOAD` and clears the latched expire status. When it reaches zero, `STATUS[2]` asserts and the timer IRQ line toggles if enabled.
- Writing `WDT_LOAD` while the watchdog is enabled immediately reloads the counter and clears the expire flag. Setting `CTRL[0]=0` freezes both the main counter and watchdog logic.

## HAL and Example
Use `devkit/hal/timer.h` for helper functions (configure prescaler, enable auto-reload compares, kick the watchdog). The regression `scripts/run_timer.sh` assembles `devkit/examples/timer_demo.qar`, which enables CMP0 auto-reload, allows the watchdog to expire, and stores the resulting CMP0/STATUS values in DMEM for the `qar_core_timer_tb` testbench.
