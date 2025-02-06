# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PB_ROOT ?= $(shell pwd)

PYTHON ?= python

############
# Cheshire #
############

# Use bender from the picobello root directory
BENDER_ROOT ?= $(PB_ROOT)/.bender
BENDER ?= bender -d $(PB_ROOT)

COMMON_TARGS += -t rtl -t cva6 -t cv64a6_imafdcsclic_sv39 -t snitch_cluster
SIM_TARGS += -t simulation -t test -t idma_test

PB_GEN_DIR = $(PB_ROOT)/.generated

$(PB_GEN_DIR):
	mkdir -p $(PB_GEN_DIR)

############
# Cheshire #
############

CLINTCORES ?= 5
CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

$(CHS_ROOT)/hw/rv_plic.cfg.hjson: cfg/rv_plic.cfg.hjson
	flock -x $@ sh -c 'cp $< $@'

##################
# Snitch Cluster #
##################

.PHONY: sn-hw-clean sn-hw-all

SN_ROOT := $(shell $(BENDER) path snitch_cluster)
SN_CFG	:= $(PB_ROOT)/cfg/snitch_cluster.hjson

include $(SN_ROOT)/target/common/rtl.mk
sn-hw-all: sn-wrapper
sn-hw-clean: sn-clean-wrapper

.PHONY: sn-install-pkg
sn-install-pkg:
	$(PYTHON) -m pip install $(shell $(BENDER) path snitch_cluster)

###########
# FlooNoC #
###########

.PHONY: floo-hw-all floo-clean

FLOO_ROOT := $(shell $(BENDER) path floo_noc)
FLOO_GEN	?= floogen
FLOO_CFG := $(PB_ROOT)/cfg/picobello_noc.yml

floo-hw-all: $(PB_GEN_DIR)/floo_picobello_noc.sv
$(PB_GEN_DIR)/floo_picobello_noc.sv: $(FLOO_CFG) | $(PB_GEN_DIR)
	$(FLOO_GEN) -c $(FLOO_CFG) -o $(PB_GEN_DIR) $(FLOO_GEN_ARGS)

floo-clean:
	rm -rf $(PB_GEN_DIR)/floo_picobello_noc.sv

.PHONY: floo-install-floogen
floo-install-floogen:
	$(PYTHON) -m pip install $(shell $(BENDER) path floo_noc)

#########################
# General Phony targets #
#########################

PB_HW_ALL += $(CHS_HW_ALL)
PB_HW_ALL += $(CHS_SIM_ALL)
PB_HW_ALL += $(SN_GEN_DIR)/snitch_cluster_wrapper.sv
PB_HW_ALL += $(PB_GEN_DIR)/floo_picobello_noc.sv

.PHONY: picobello-hw-all picobello-clean clean

picobello-hw-all all: $(PICOBELLO_HW_ALL)

picobello-clean clean: sn-clean-wrapper floo-clean
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

########
# Misc #
########

include $(SN_ROOT)/target/common/common.mk

.PHONY dvt-flist:

dvt-flist:
	$(BENDER) script flist-plus $(COMMON_TARGS) $(SIM_TARGS) > .dvt/default.build

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
	@echo -e "${Green}clean                ${Black}Alias for picobello-clean."
	@echo -e ""
	@echo -e "Source generation targets:"
	@echo -e "${Green}picobello-hw-all     ${Black}Build all RTL."
	@echo -e "${Green}picobello-clean      ${Black}Clean everything."
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
	@echo -e "${Green}snrt-tests           ${Black}Compile Snitch runtime software tests."
	@echo -e "${Green}snrt-clean-tests     ${Black}Clean Snitch runtime software tests."
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
