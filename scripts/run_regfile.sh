#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f regfile_tb.out
}
trap cleanup EXIT

iverilog -o regfile_tb.out \
    qar-core/rtl/regfile.v \
    qar-core/sim/regfile_tb.v

vvp regfile_tb.out
