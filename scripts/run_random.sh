#!/bin/bash

iverilog -o qar_core_random_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/rtl/alu.v \
    qar-core/rtl/qar_core.v \
    qar-core/sim/qar_core_random_tb.v

vvp qar_core_random_tb.out
