# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

VSIM ?= vsim
VSIM_DIR = $(PB_ROOT)/target/sim/vsim
VSIM_WORK = $(VSIM_DIR)/work

VLOG_ARGS = -work $(VSIM_WORK)
VLOG_ARGS += -suppress vlog-2583
VLOG_ARGS += -suppress vlog-13314
VLOG_ARGS += -suppress vlog-13233

VSIM_FLAGS = -work $(VSIM_WORK)
VSIM_FLAGS += -suppress 3009
VSIM_FLAGS += -suppress 8386
VSIM_FLAGS += -suppress 13314
VSIM_FLAGS += -quiet
VSIM_FLAGS += -64

VSIM_FLAGS_GUI = -voptargs=+acc

ifdef CHS_BINARY
	VSIM_FLAGS += +BINARY=$(CHS_BINARY)
endif
ifdef SNITCH_BINARY
	VSIM_FLAGS += +SNITCH_BINARY=$(SNITCH_BINARY)
endif

.PHONY: vsim-compile vsim-clean vsim-run

vsim-clean:
	rm -rf $(VSIM_WORK)
	rm -f $(VSIM_DIR)/transcript
	rm -f $(VSIM_DIR)/compile.tcl

vsim-compile: $(VSIM_DIR)/compile.tcl $(PB_HW_ALL)
	$(VSIM) -c $(VSIM_FLAGS) -do "source $<; quit"

$(VSIM_DIR)/compile.tcl:
	bender script vsim --compilation-mode common $(COMMON_TARGS) $(SIM_TARGS) --vlog-arg="$(VLOG_ARGS)"> $@
	echo 'vlog -work $(VSIM_WORK) "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

vsim-run:
	$(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) $(TB_DUT)

vsim-run-batch:
	$(VSIM) -c $(VSIM_FLAGS) $(TB_DUT) -do "run -all; quit"
