#!/bin/bash

iverilog -o alu_tb.out \
    qar-core/rtl/alu.v \
    qar-core/sim/alu_tb.v

vvp alu_tb.out
