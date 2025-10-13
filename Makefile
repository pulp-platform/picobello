# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PB_ROOT ?= $(shell pwd)
PB_GEN_DIR = $(PB_ROOT)/.generated
BENDER_ROOT ?= $(PB_ROOT)/.bender

# Configuration files
FLOO_CFG  ?= $(PB_ROOT)/cfg/picobello_noc.yml
SN_CFG	  ?= $(PB_ROOT)/cfg/snitch_cluster.json
PLIC_CFG  ?= $(PB_ROOT)/cfg/rv_plic.cfg.hjson
SLINK_CFG ?= $(PB_ROOT)/cfg/serial_link.hjson

# Root directories of dependencies
CHS_ROOT  = $(shell $(BENDER) path cheshire)
SN_ROOT   = $(shell $(BENDER) path snitch_cluster)
FLOO_ROOT = $(shell $(BENDER) path floo_noc)

# Executables
BENDER           ?= bender -d $(PB_ROOT)
FLOO_GEN         ?= floogen
VERIBLE_FMT      ?= verible-verilog-format
VERIBLE_FMT_ARGS ?= --flagfile .verilog_format --inplace --verbose
PEAKRDL          ?= peakrdl

# Tiles configuration
SN_CLUSTERS = $(shell $(FLOO_GEN) -c $(FLOO_CFG) --query endpoints.cluster.num 2>/dev/null)
L2_TILES = $(shell $(FLOO_GEN) -c $(FLOO_CFG) --query endpoints.l2_spm.num 2>/dev/null)

# Bender prerequisites
BENDER_YML = $(PB_ROOT)/Bender.yml
BENDER_LOCK = $(PB_ROOT)/Bender.lock

################
# Bender flags #
################

COMMON_TARGS += -t rtl -t cva6 -t cv64a6_imafdcsclic_sv39 -t snitch_cluster -t pb_gen_rtl
SIM_TARGS += -t simulation -t test -t idma_test

#############
# systemRDL #
#############

PB_RDL_ALL += $(PB_GEN_DIR)/picobello.rdl
PB_RDL_ALL += $(PB_GEN_DIR)/fll.rdl $(PB_GEN_DIR)/pb_chip_regs.rdl
PB_RDL_ALL += $(PB_GEN_DIR)/snitch_cluster.rdl
PB_RDL_ALL += $(wildcard $(PB_ROOT)/cfg/rdl/*.rdl)

PEAKRDL_INCLUDES += -I $(PB_ROOT)/cfg/rdl
PEAKRDL_INCLUDES += -I $(SN_ROOT)/hw/snitch_cluster/src/snitch_cluster_peripheral
PEAKRDL_INCLUDES += -I $(PB_GEN_DIR)

$(PB_GEN_DIR)/pb_soc_regs.sv: $(PB_GEN_DIR)/pb_soc_regs_pkg.sv
$(PB_GEN_DIR)/pb_soc_regs_pkg.sv: $(PB_ROOT)/cfg/rdl/pb_soc_regs.rdl
	$(PEAKRDL) regblock $< -o $(PB_GEN_DIR) --cpuif apb4-flat --default-reset arst_n -P Num_Clusters=$(SN_CLUSTERS) -P Num_Mem_Tiles=$(L2_TILES)

$(PB_GEN_DIR)/picobello.rdl: $(FLOO_CFG)
	$(FLOO_GEN) -c $(FLOO_CFG) -o $(PB_GEN_DIR) --rdl --rdl-as-mem --rdl-memwidth=32

# Those are dummy RDL files, for generation without access to the PD repository.
$(PB_GEN_DIR)/fll.rdl $(PB_GEN_DIR)/pb_chip_regs.rdl:
	@touch $@

$(PB_GEN_DIR)/pb_addrmap.h: $(PB_GEN_DIR)/picobello.rdl $(PB_RDL_ALL)
	$(PEAKRDL) c-header $< $(PEAKRDL_INCLUDES) $(PEAKRDL_DEFINES) -o $@ -i -b ltoh

$(PB_GEN_DIR)/pb_addrmap.svh: $(PB_RDL_ALL)
	$(PEAKRDL) raw-header $< -o $@ $(PEAKRDL_INCLUDES) $(PEAKRDL_DEFINES) --format svh

PB_RDL_HW_ALL += $(PB_GEN_DIR)/pb_soc_regs.sv
PB_RDL_HW_ALL += $(PB_GEN_DIR)/pb_soc_regs_pkg.sv
PB_RDL_HW_ALL += $(PB_GEN_DIR)/pb_addrmap.svh

.PHONY: pb-soc-regs pb-soc-regs-clean
pb-soc-regs: $(PB_GEN_DIR)/pb_soc_regs.sv $(PB_GEN_DIR)/pb_soc_regs_pkg.sv

pb-soc-regs-clean:
	rm -rf $(PB_GEN_DIR)/pb_soc_regs.sv $(PB_GEN_DIR)/pb_soc_regs_pkg.sv

.PHONY: pb-addrmap
pb-addrmap: $(PB_GEN_DIR)/pb_addrmap.h $(PB_GEN_DIR)/pb_addrmap.svh

############
# Cheshire #
############

CLINTCORES ?= 17
include $(CHS_ROOT)/cheshire.mk

$(CHS_ROOT)/hw/rv_plic.cfg.hjson: $(OTPROOT)/.generated2
$(OTPROOT)/.generated2: $(PLIC_CFG)
	flock -x $@ sh -c "cp $< $(CHS_ROOT)/hw/" && touch $@

$(CHS_ROOT)/hw/serial_link.hjson: $(CHS_SLINK_DIR)/.generated2
$(CHS_SLINK_DIR)/.generated2:	$(SLINK_CFG)
	flock -x $@ sh -c "cp $< $(CHS_ROOT)/hw/" && touch $@

##################
# Snitch Cluster #
##################

SN_GEN_DIR = $(PB_GEN_DIR)
include $(SN_ROOT)/make/common.mk
include $(SN_ROOT)/make/rtl.mk

.PHONY: sn-hw-clean sn-hw-all

sn-hw-all: $(SN_CLUSTER_WRAPPER) $(SN_CLUSTER_PKG)
sn-hw-clean:
	rm -rf $(SN_CLUSTER_WRAPPER) $(SN_CLUSTER_PKG)

###########
# FlooNoC #
###########
.PHONY: update-sn-cfg
update-sn-cfg: $(SN_CFG)
	@sed -i 's/nr_clusters: .*/nr_clusters: $(SN_CLUSTERS),/' $<

.PHONY: floo-hw-all floo-clean

# Check if `VERIBLE_FMT` executable is valid, otherwise don't format FlooGen output
FLOO_GEN_FLAGS = --no-format
ifeq ($(shell $(VERIBLE_FMT) --version >/dev/null 2>&1 && echo OK),OK)
	FLOO_GEN_FLAGS = --verible-fmt-bin="$(VERIBLE_FMT)" --verible-fmt-args="$(VERIBLE_FMT_ARGS)"
endif

floo-hw-all: $(PB_GEN_DIR)/floo_picobello_noc_pkg.sv
$(PB_GEN_DIR)/floo_picobello_noc_pkg.sv: $(FLOO_CFG) | $(PB_GEN_DIR)
	$(FLOO_GEN) -c $(FLOO_CFG) -o $(PB_GEN_DIR) --only-pkg $(FLOO_GEN_FLAGS)


floo-clean:
	rm -f $(PB_GEN_DIR)/floo_picobello_noc_pkg.sv
	rm -f $(PB_GEN_DIR)/picobello.rdl

###################
# Physical Design #
###################

PD_REMOTE ?= git@iis-git.ee.ethz.ch:picobello/picobello-pd.git
PD_COMMIT ?= main
PD_DIR = $(PB_ROOT)/pd
SPU_REMOTE ?= git@iis-git.ee.ethz.ch:picobello/fhg_spu_cluster.git
SPU_COMMIT ?= main
SPU_DIR = $(PB_ROOT)/.deps/fhg_spu_cluster

.PHONY: init-pd clean-pd

init-pd: $(PD_DIR) $(SPU_DIR)
$(PD_DIR):
	git clone $(PD_REMOTE) $(PD_DIR)
	cd $(PD_DIR) && git checkout $(PD_COMMIT)

$(SPU_DIR):
	-git clone $(SPU_REMOTE) $(SPU_DIR)
	-cd $(SPU_DIR) && git checkout $(SPU_COMMIT)

clean-pd:
	rm -rf $(PD_DIR)
	rm -rf $(SPU_DIR)

-include $(PD_DIR)/pd.mk


#########################
# General Phony targets #
#########################

PB_HW_ALL += $(CHS_HW_ALL)
PB_HW_ALL += $(CHS_SIM_ALL)
PB_HW_ALL += $(PB_GEN_DIR)/floo_picobello_noc_pkg.sv
PB_HW_ALL += $(PB_RDL_HW_ALL)
PB_HW_ALL += update-sn-cfg

.PHONY: picobello-hw-all picobello-clean clean

picobello-hw-all all: $(PB_HW_ALL) sn-hw-all
	$(MAKE) $(PB_HW_ALL)

picobello-hw-clean clean: sn-hw-clean floo-clean
	rm -rf $(BENDER_ROOT)

############
# Software #
############

include $(PB_ROOT)/sw/sw.mk

##############
# Simulation #
##############

TB_DUT = tb_picobello_top

include $(PB_ROOT)/target/sim/vsim/vsim.mk
include $(PB_ROOT)/target/sim/traces.mk

##################
# Snitch cluster #
##################

$(call sn_include_deps)

########
# Misc #
########

.PHONY: dvt-flist verible-fmt

dvt-flist:
	$(BENDER) script flist-plus $(COMMON_TARGS) $(SIM_TARGS) > .dvt/default.build

verible-fmt:
	$(VERIBLE_FMT) $(VERIBLE_FMT_ARGS) $(shell $(BENDER) script flist $(SIM_TARGS) --no-deps)

#################
# Documentation #
#################

.PHONY: help

Black=\033[0m
Green=\033[1;32m
help:
	@echo -e "Makefile ${Green}targets${Black} for picobello"
	@echo -e "Use 'make <target>' where <target> is one of:"
	@echo -e ""
	@echo -e "${Green}help           	     ${Black}Show an overview of all Makefile targets."
	@echo -e ""
	@echo -e "General targets:"
	@echo -e "${Green}all                  ${Black}Alias for picobello-hw-all."
	@echo -e "${Green}clean                ${Black}Alias for picobello-hw-clean."
	@echo -e ""
	@echo -e "Source generation targets:"
	@echo -e "${Green}picobello-hw-all     ${Black}Build all RTL."
	@echo -e "${Green}picobello-hw-clean   ${Black}Clean everything."
	@echo -e "${Green}floo-hw-all          ${Black}Generate FlooNoC RTL."
	@echo -e "${Green}floo-clean           ${Black}Clean FlooNoC RTL."
	@echo -e "${Green}sn-hw-all            ${Black}Generate Snitch Cluster wrapper RTL."
	@echo -e "${Green}sn-hw-clean          ${Black}Clean Snitch Cluster wrapper RTL."
	@echo -e "${Green}chs-hw-all           ${Black}Generate Cheshire RTL."
	@echo -e ""
	@echo -e "Software:"
	@echo -e "${Green}sw                   ${Black}Compile all software tests."
	@echo -e "${Green}sw-clean             ${Black}Clean all software tests."
	@echo -e "${Green}chs-sw-tests         ${Black}Compile Cheshire software tests."
	@echo -e "${Green}chs-sw-tests-clean   ${Black}Clean Cheshire software tests."
	@echo -e "${Green}sn-tests             ${Black}Compile Snitch software tests."
	@echo -e "${Green}sn-clean-tests       ${Black}Clean Snitch software tests."
	@echo -e ""
	@echo -e "Simulation targets:"
	@echo -e "${Green}vsim-compile         ${Black}Compile with Questasim."
	@echo -e "${Green}vsim-run             ${Black}Run QuestaSim simulation in GUI mode w/o optimization."
	@echo -e "${Green}vsim-run-batch       ${Black}Run QuestaSim simulation in batch mode w/ optimization."
	@echo -e "${Green}vsim-clean           ${Black}Clean QuestaSim simulation files."
	@echo -e ""
	@echo -e "Additional miscellaneous targets:"
	@echo -e "${Green}traces               ${Black}Generate the better readable traces in .logs/trace_hart_<hart_id>.txt."
	@echo -e "${Green}annotate             ${Black}Annotate the better readable traces in .logs/trace_hart_<hart_id>.s with the source code related with the retired instructions."
	@echo -e "${Green}dvt-flist            ${Black}Generate a file list for the VSCode DVT plugin."
	@echo -e "${Green}python-venv          ${Black}Create a Python virtual environment and install the required packages."
	@echo -e "${Green}python-venv-clean    ${Black}Remove the Python virtual environment."
	@echo -e "${Green}verible-fmt          ${Black}Format SystemVerilog files using Verible."
