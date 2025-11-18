# Analog-to-Digital Converter (ADC)

The ADC block provides up to four 12-bit single-ended measurement channels that can be sampled on-demand or via a simple continuous round-robin sequencer. Values are captured digitally (looped in from simulation stimuli) so firmware can validate data paths before real analog front-ends are added.

## Base Address
- ADC0: `0x4000_6000`

## Register Map

| Offset | Name        | Description |
|--------|-------------|-------------|
| 0x00   | CTRL        | Bit0: enable, bit1: continuous sequencer enable, bit2: start single conversion (auto-clear), bits[5:4]: manual channel select for single-shot mode. |
| 0x04   | STATUS      | Bit0: conversion busy, bit1: data ready (clears on `RESULT` read), bit2: overrun (sticky, set when new data arrives before previous sample is read), bit3: sequencer active (mirrors continuous enable & non-zero mask). |
| 0x08   | RESULT      | Read-only `{channel[19:16], 4'b0, sample[11:0]}`; reading clears the ready bit and the corresponding interrupt. |
| 0x0C   | IRQ_EN      | Interrupt enables (bit0 = data ready, bit1 = overrun). |
| 0x10   | IRQ_STATUS  | Interrupt status (write-1-to-clear). |
| 0x14   | SEQ_MASK    | Bitmask of channels included in round-robin continuous mode (bit0 = CH0, bit1 = CH1, etc.). |
| 0x18   | SAMPLE_DIV  | Inter-conversion delay for continuous mode in core clock cycles (0 → 1 cycle). |

## Behaviour
- Writing `CTRL` with `ENABLE` and `CONTINUOUS` bits set allows the sequencer to iterate over the channels marked in `SEQ_MASK`. The controller waits `SAMPLE_DIV` cycles between conversions and latches the analog input at the start of each conversion, asserting the data-ready interrupt upon completion.
- Single-shot conversions ignore `SEQ_MASK` and use the manual channel field in `CTRL`. Set the enable bit, write `SEQ_MASK` as needed (optional), then write `CTRL` with `START` asserted and the desired channel value to initiate a conversion.
- Overruns are detected when firmware fails to read `RESULT` before the next conversion completes. When this happens, `STATUS[2]` and `IRQ_STATUS[1]` assert and remain high until firmware writes the corresponding bit to `IRQ_STATUS`.
- Reading `RESULT` clears the ready bit/interrupt but preserves the last sampled value for software inspection. Firmware can parse the channel ID via `bits[19:16]` and the 12-bit sample via `bits[11:0]`.

## Firmware Support
Use `devkit/hal/adc.h` for helper routines:
- `qar_adc_enable_continuous(base, mask, div)` configures mask/divider and enables the sequencer.
- `qar_adc_start_single(base, channel)` kicks off one conversion and latches the result.
- `QAR_ADC_RESULT_CHANNEL(val)` and `QAR_ADC_RESULT_VALUE(val)` extract fields from the composite result word.

See `devkit/examples/adc_demo.qar` and `scripts/run_adc.sh` for a regression that exercises both continuous sequencing (channels 0/1) and manual sampling (channel 2). The `qar_core_adc_tb` test bench feeds deterministic 12-bit values onto the ADC ports so we can verify firmware-observed results.
