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

COMMON_TARGS += -t rtl -t test -t cva6 -t cv64a6_imafdcsclic_sv39 -t snitch_cluster
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

##################
# Snitch Cluster #
##################

.PHONY: sn-clean

SN_ROOT := $(shell $(BENDER) path snitch_cluster)
SN_CFG	:= $(PICOBELLO_ROOT)/cfg/snitch_cluster.hjson
SN_GENDIR = $(SN_ROOT)/target/snitch_cluster/generated
SN_CLUSTER_GEN  = $(SN_ROOT)/util/clustergen.py

include $(SN_ROOT)/target/common/common.mk

$(SN_GENDIR):
	mkdir -p $(SN_GENDIR)

$(SN_GENDIR)/snitch_cluster_wrapper.sv: $(SN_CFG) $(SN_CLUSTER_GEN) | $(SN_GENDIR)
	$(SN_CLUSTER_GEN) -c $< -o $(SN_GENDIR) --wrapper

sn-clean:
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
PICOBELLO_HW_ALL += $(SN_GENDIR)/snitch_cluster_wrapper.sv
PICOBELLO_HW_ALL += $(PICOBELLO_GENDIR)/floo_picobello_noc.sv

.PHONY: picobello-all picobello-clean clean
picobello-all all: $(PICOBELLO_HW_ALL)
picobello-clean clean: sn-clean chs-clean-deps floo-clean

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
