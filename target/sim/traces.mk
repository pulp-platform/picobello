# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Luca Colagrande <colluca@iis.ee.ethz.ch>

SIM_DIR = $(PB_ROOT)
LOGS_DIR = $(SIM_DIR)/logs
SN_SIM_DIR = $(SIM_DIR)
include $(SN_ROOT)/make/traces.mk

ifdef ROI_SPEC
	SN_ROI_SPEC = $(ROI_SPEC)
endif

CHS_ADDR2LINE      ?= $(CHS_SW_GCC_BINROOT)/riscv64-unknown-elf-addr2line
CHS_TXT_TRACE       = $(LOGS_DIR)/trace_hart_00000.txt
CHS_ANNOTATED_TRACE = $(LOGS_DIR)/trace_hart_00000.s
CHS_BINARY         ?= $(shell cat $(SIM_DIR)/.chsbinary)

# Cheshire trace generation
$(CHS_TXT_TRACE): $(SIM_DIR)/trace_hart_0.log
	cp $< $@
$(CHS_ANNOTATED_TRACE): $(CHS_TXT_TRACE) $(SN_ANNOTATE_PY)
	$(PYTHON) $(SN_ANNOTATE_PY) -f cva6 -q --keep-time --addr2line=$(CHS_ADDR2LINE) -o $@ $(CHS_BINARY) $<

traces: sn-traces chs-trace
annotate: sn-annotate chs-annotate
traces-clean: sn-clean-traces chs-trace-clean
annotate-clean: sn-clean-annotate chs-annotate-clean
visual-trace: sn-visual-trace
clean-visual-trace: sn-clean-visual-trace

chs-trace: $(CHS_TXT_TRACE)
chs-annotate: $(CHS_ANNOTATED_TRACE)

chs-trace-clean:
	rm -rf $(CHS_TXT_TRACE)

chs-annotate-clean:
	rm -rf $(CHS_ANNOTATED_TRACE)