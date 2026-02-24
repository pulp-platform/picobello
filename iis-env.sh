#!/bin/bash
# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

export VSIM="questa-2025.3 vsim"
export VOPT="questa-2025.3 vopt"
export VLIB="questa-2025.3 vlib"
export CHS_SW_GCC_BINROOT=/usr/pack/riscv-1.0-kgf/riscv64-gcc-12.2.0/bin
export VERIBLE_FMT="oseda -2025.03 verible-verilog-format"
export SN_LLVM_BINROOT=/usr/scratch2/vulcano/colluca/tools/riscv32-snitch-llvm-almalinux8-15.0.0-snitch-0.5.0/bin

export UV_LINK_MODE=copy

/usr/local/uv/uv sync --locked
source .venv/bin/activate
