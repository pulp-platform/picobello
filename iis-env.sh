#!/bin/bash
# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

export VSIM="questa-2023.4 vsim"
export BASE_PYTHON=/usr/local/anaconda3/bin/python3.11
export CHS_SW_GCC_BINROOT=/usr/pack/riscv-1.0-kgf/riscv64-gcc-12.2.0/bin
export LLVM_BINROOT=/usr/scratch2/vulcano/colluca/tools/riscv32-snitch-llvm-almalinux8-15.0.0-snitch-0.2.0/bin
export VERIBLE_FMT="oseda -2025.03 verible-verilog-format"

# Create the python venv
if [ ! -d ".venv" ]; then
  make python-venv
fi

# Activate the python venv only if not already active
if [ -z "$VIRTUAL_ENV" ] || [ "$VIRTUAL_ENV" != "$(realpath .venv)" ]; then
  source .venv/bin/activate
fi
