#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f qar_core_uart_tb.out
}
trap cleanup EXIT

go run ./devkit/cli build \
    --asm devkit/examples/uart_rs485.qar \
    --data devkit/examples/uart_rs485.data \
    --imem 64 \
    --dmem 64 \
    --program program_uart.hex \
    --data-out data_uart.hex

iverilog -o qar_core_uart_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/can.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_uart_tb.v

vvp qar_core_uart_tb.out
