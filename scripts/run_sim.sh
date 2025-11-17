#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f qar_core_tb.out
}
trap cleanup EXIT

iverilog -o qar_core_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/gpio.v \
    qar-core/rtl/uart.v \
    qar-core/rtl/can.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_tb.v

vvp qar_core_tb.out
