#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f qar_core_gpio_tb.out
}
trap cleanup EXIT

go run ./devkit/cli build \
    --asm devkit/examples/gpio_demo.qar \
    --data devkit/examples/gpio_demo.data \
    --imem 64 \
    --dmem 64 \
    --program program_gpio.hex \
    --data-out data_gpio.hex

iverilog -o qar_core_gpio_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/can.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_gpio_tb.v

vvp qar_core_gpio_tb.out
