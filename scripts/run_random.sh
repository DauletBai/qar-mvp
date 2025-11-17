#!/bin/bash

go run ./devkit/cli build \
    --asm devkit/examples/sum_positive.qar \
    --data devkit/examples/sum_positive.data \
    --imem 128 \
    --dmem 256 \
    --program program.hex \
    --data-out data.hex

iverilog -o qar_core_random_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_random_tb.v

vvp qar_core_random_tb.out
