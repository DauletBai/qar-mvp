#!/bin/bash

set -euo pipefail

# Build cache-focused program without clobbering default program.hex
go run ./devkit/cli build \
    --asm devkit/examples/cache_loop.qar \
    --data devkit/examples/cache_loop.data \
    --imem 64 \
    --dmem 64 \
    --program program_cache.hex \
    --data-out data_cache.hex

iverilog -o qar_core_cache_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/can.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_cache_tb.v

vvp qar_core_cache_tb.out
