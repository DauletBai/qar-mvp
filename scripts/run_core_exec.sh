#!/bin/bash

go run ./devkit/cli build \
    --asm devkit/examples/irq_demo.qar \
    --data devkit/examples/irq_demo.data \
    --imem 128 \
    --dmem 256 \
    --program program.hex \
    --data-out data.hex

iverilog -o qar_core_exec_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/can.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_exec_tb.v

vvp qar_core_exec_tb.out
