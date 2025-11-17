#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f alu_tb.out
}
trap cleanup EXIT

iverilog -o alu_tb.out \
    qar-core/rtl/alu.v \
    qar-core/sim/alu_tb.v

vvp alu_tb.out
