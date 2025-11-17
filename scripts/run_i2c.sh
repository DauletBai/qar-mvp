#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f qar_core_i2c_tb.out program_i2c.hex data_i2c.hex
}
trap cleanup EXIT

go run ./devkit/cli build \
    --asm devkit/examples/i2c_loopback.qar \
    --data devkit/examples/i2c_loopback.data \
    --imem 64 \
    --dmem 64 \
    --program program_i2c.hex \
    --data-out data_i2c.hex

iverilog -o qar_core_i2c_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/spi.v \
    qar-core/rtl/i2c.v \
    qar-core/rtl/can.v \
    qar-core/rtl/timer.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_i2c_tb.v

vvp qar_core_i2c_tb.out
