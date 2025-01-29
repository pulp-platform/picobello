# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PICOBELLO_ROOT ?= $(shell pwd)

############
# Cheshire #
############

# Use bender from the picobello root directory
BENDER_ROOT ?= $(PICOBELLO_ROOT)/.bender
BENDER = bender -d $(PICOBELLO_ROOT)

COMMON_TARGS += -t rtl -t cva6 -t cv64a6_imafdcsclic_sv39 -t snitch_cluster
SIM_TARGS += -t simulation -t test -t idma_test

PICOBELLO_GENDIR = $(PICOBELLO_ROOT)/.generated

$(PICOBELLO_GENDIR):
	mkdir -p $(PICOBELLO_GENDIR)

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
SN_CFG	:= $(PICOBELLO_ROOT)/cfg/snitch_cluster.hjson
SN_GENDIR = $(SN_ROOT)/target/snitch_cluster/generated
SN_CLUSTER_GEN  = $(SN_ROOT)/util/clustergen.py

SNITCH_ROOT = $(SN_ROOT)
include $(SN_ROOT)/target/common/common.mk

$(SN_GENDIR):
	mkdir -p $(SN_GENDIR)

sn-hw-all: $(SN_GENDIR)/snitch_cluster_wrapper.sv
$(SN_GENDIR)/snitch_cluster_wrapper.sv: $(SN_CFG) $(SN_CLUSTER_GEN) | $(SN_GENDIR)
	$(SN_CLUSTER_GEN) -c $< -o $(SN_GENDIR) --wrapper

sn-hw-clean:
	rm -rf $(PICOBELLO_GENDIR)/snitch_cluster_wrapper.sv

###########
# FlooNoC #
###########

.PHONY: floo-hw-all floo-clean

FLOO_ROOT := $(shell $(BENDER) path floo_noc)
FLOO_GEN	?= floogen
FLOO_CFG := $(PICOBELLO_ROOT)/cfg/picobello_noc.yml

floo-hw-all: $(PICOBELLO_GENDIR)/floo_picobello_noc.sv
$(PICOBELLO_GENDIR)/floo_picobello_noc.sv: $(FLOO_CFG) | $(PICOBELLO_GENDIR)
	$(FLOO_GEN) -c $(FLOO_CFG) -o $(PICOBELLO_GENDIR)

floo-clean:
	rm -rf $(PICOBELLO_GENDIR)/floo_picobello_noc.sv

#########################
# General Phony targets #
#########################

PICOBELLO_HW_ALL += $(CHS_HW_ALL)
PICOBELLO_HW_ALL += $(CHS_SIM_ALL)
PICOBELLO_HW_ALL += $(SN_GENDIR)/snitch_cluster_wrapper.sv
PICOBELLO_HW_ALL += $(PICOBELLO_GENDIR)/floo_picobello_noc.sv

.PHONY: picobello-hw-all picobello-clean clean

picobello-hw-all all: $(PICOBELLO_HW_ALL)

picobello-clean clean: sn-hw-clean floo-clean
	rm -rf $(BENDER_ROOT)

##############
# Simulation #
##############

TB_DUT = tb_picobello_top
CHS_BINARY ?= $(CHS_ROOT)/sw/tests/helloworld.spm.elf

include $(PICOBELLO_ROOT)/target/sim/vsim/vsim.mk

########
# Misc #
########

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
