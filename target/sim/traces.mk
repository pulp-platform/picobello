# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Luca Colagrande <colluca@iis.ee.ethz.ch>

CHS_ADDR2LINE      ?= $(CHS_SW_GCC_BINROOT)/riscv64-unknown-elf-addr2line
CHS_TXT_TRACE       = $(LOGS_DIR)/trace_hart_00000.txt
CHS_ANNOTATED_TRACE = $(LOGS_DIR)/trace_hart_00000.s
CHS_BINARY         ?= $(shell cat $(SIM_DIR)/.chsbinary)

# Cheshire trace generation
$(CHS_TXT_TRACE): $(SIM_DIR)/trace_hart_0.log
	cp $< $@
$(CHS_ANNOTATED_TRACE): $(CHS_TXT_TRACE) $(ANNOTATE_PY)
	$(PYTHON) $(ANNOTATE_PY) -f cva6 -q --keep-time --addr2line=$(CHS_ADDR2LINE) -o $@ $(CHS_BINARY) $<

traces: chs-trace
annotate: chs-annotate

chs-trace: $(CHS_TXT_TRACE)
chs-annotate: $(CHS_ANNOTATED_TRACE)

chs-trace-clean:
	rm -rf $(CHS_TXT_TRACE)

chs-annotate-clean:
	rm -rf $(CHS_ANNOTATED_TRACE)