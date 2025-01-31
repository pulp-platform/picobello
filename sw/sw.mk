# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

BENDER ?= bender
CHS_ROOT ?= $(shell $(BENDER) path cheshire)
SNITCH_ROOT ?= $(shell $(BENDER) path snitch_cluster)

PB_SW_DIR = $(PB_ROOT)/sw
PB_CHS_SW_DIR = $(PB_SW_DIR)/cheshire
PB_SNITCH_SW_DIR = $(PB_SW_DIR)/snitch

PB_INCDIR = $(PB_SW_DIR)/include

####################
## Snitch Cluster ##
####################

SNRT_TARGET_DIR = $(PB_SNITCH_SW_DIR)/runtime
SNRT_SRCDIR 	  = $(SNRT_TARGET_DIR)
TESTS_BUILDDIR  = $(PB_SNITCH_SW_DIR)/tests/build
SNRT_INCDIRS    = $(PB_INCDIR)

include $(SNITCH_ROOT)/target/snitch_cluster/sw.mk

######################
## Picobello Global ##
######################

PB_ADDRMAP = $(PB_SW_DIR)/include/picobello_addrmap.h

$(PB_ADDRMAP): $(TARGET_C_HDRS)

##############
## Cheshire ##
##############

PB_LINK_MODE ?= spm

# We need to include the address map and snitch cluster includes
CHS_SW_INCLUDES += -I$(PB_INCDIR)
CHS_SW_INCLUDES += -I$(TARGET_C_HDRS_DIR)

# TODO(fischeti): This does not work yet for some reason
CHS_SW_GEN_HDRS += $(PB_ADDRMAP)

# Collect tests, which should be build for all modes, and their .dump targets
PB_CHS_SW_TEST_SRC = $(wildcard $(PB_CHS_SW_DIR)/tests/*.c)
PB_CHS_SW_TEST_DUMP += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).dump)
PB_CHS_SW_TEST_ELF += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).elf)

PB_CHS_SW_TEST = $(PB_CHS_SW_TEST_DUMP)

.PHONY: chs-sw-tests chs-sw-tests-clean

chs-sw-tests: $(PB_CHS_SW_TEST)

chs-sw-tests-clean:
	rm -f $(PB_CHS_SW_TEST_DUMP)
	rm -f $(PB_CHS_SW_TEST_ELF)
