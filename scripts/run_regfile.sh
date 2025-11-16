#!/bin/bash

iverilog -o regfile_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/sim/regfile_tb.v

vvp regfile_tb.out
