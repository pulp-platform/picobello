# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

FPGA_SRC = $(PB_ROOT)/target/fpga/src
FPGA_TPL = $(PB_ROOT)/target/fpga/tpl

VIVADO ?= vitis-2019.2 vivado
VIVADO_DIR = $(PB_ROOT)/target/fpga/vivado
VIVADO_UTILS = $(VIVADO_DIR)/utils
VIVADO_BUILD = $(VIVADO_DIR)/build

VIVADO_GEN = $(VIVADO_UTILS)/vivado-gen.py
VIVADO_FLAGS = -mode batch

fpga-all: fpga-gen fpga-bender fpga-ip fpga-build fpga-reports

fpga-reports:
	mkdir -p $(VIVADO_BUILD)/reports
	cd $(VIVADO_BUILD) && $(VIVADO) $(VIVADO_FLAGS) \
		-source $(VIVADO_UTILS)/area/area_report.tcl \
		-tclargs $(VIVADO_BUILD) $(VIVADO_UTILS)/area

fpga-build:
	mkdir -p $(VIVADO_BUILD)/vivado_prj
	cd $(VIVADO_BUILD) && $(VIVADO) $(VIVADO_FLAGS) \
		-source $(VIVADO_BUILD)/picobello_build.tcl \
		-tclargs $(VIVADO_BUILD)

fpga-ip:
	cp $(VIVADO_UTILS)/xdc/*.xdc $(VIVADO_BUILD)
	cd $(VIVADO_BUILD) && $(VIVADO) $(VIVADO_FLAGS) \
		-source picobello_ip_xact.tcl \
		-tclargs $(VIVADO_BUILD)

fpga-bender:
	bender script vivado --only-defines --only-includes $(COMMON_TARGS) $(FPGA_TARGS) > \
		$(VIVADO_BUILD)/define_defines_includes.tcl
	bender script vivado --only-defines --only-includes --no-simset $(COMMON_TARGS) $(FPGA_TARGS) > \
		$(VIVADO_BUILD)/define_defines_includes_no_simset.tcl
	bender script vivado --only-sources $(COMMON_TARGS) $(FPGA_TARGS) > \
		$(VIVADO_BUILD)/define_sources.tcl

fpga-gen:
	mkdir -p $(VIVADO_BUILD)
	$(VIVADO_GEN) $(FPGA_TPL)/picobello_ip.v.mako > $(VIVADO_BUILD)/picobello_ip.v
	$(VIVADO_GEN) $(FPGA_TPL)/picobello_cfg.tcl.mako > $(VIVADO_BUILD)/picobello_cfg.tcl
	$(VIVADO_GEN) $(FPGA_TPL)/picobello_ip_xact.tcl.mako > $(VIVADO_BUILD)/picobello_ip_xact.tcl
	$(VIVADO_GEN) $(FPGA_TPL)/picobello_build.tcl.mako > $(VIVADO_BUILD)/picobello_build.tcl

fpga-clean:
	rm -rf $(VIVADO_BUILD)