# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

BENDER ?= bender
CHS_ROOT ?= $(shell $(BENDER) path cheshire)
SN_ROOT ?= $(shell $(BENDER) path snitch_cluster)

PB_SW_DIR = $(PB_ROOT)/sw
PB_CHS_SW_DIR = $(PB_SW_DIR)/cheshire
PB_SNITCH_SW_DIR = $(PB_SW_DIR)/snitch

PB_INCDIR = $(PB_SW_DIR)/include
PB_GEN_DIR = $(PB_ROOT)/.generated

-include $(PD_DIR)/sw/sw.mk
-include $(SPU_DIR)/sw/sw.mk

####################
## Snitch Cluster ##
####################

SN_RUNTIME_SRCDIR    = $(PB_SNITCH_SW_DIR)/runtime/impl
SN_RUNTIME_BUILDDIR  = $(PB_SNITCH_SW_DIR)/runtime/build
SN_TESTS_BUILDDIR    = $(PB_SNITCH_SW_DIR)/tests/build
SN_RVTESTS_BUILDDIR  = $(PB_SNITCH_SW_DIR)/riscv-tests/build
SN_RUNTIME_INCDIRS   = $(PB_INCDIR)
SN_RUNTIME_INCDIRS  += $(PB_GEN_DIR)
SN_RUNTIME_INCDIRS  += $(PB_SNITCH_SW_DIR)/runtime/src
SN_RUNTIME_HAL_HDRS  = $(PB_GEN_DIR)/pb_addrmap.h
SN_RUNTIME_HAL_HDRS += $(PB_GEN_DIR)/pb_raw_addrmap.h
SN_BUILD_APPS        = OFF

SN_APPS  = $(PB_SNITCH_SW_DIR)/apps/gemm_2d
SN_APPS += $(PB_SNITCH_SW_DIR)/apps/gemm
SN_APPS += $(PB_SNITCH_SW_DIR)/apps/axpy
SN_APPS += $(SN_ROOT)/sw/kernels/dnn/flashattention_2
SN_APPS += $(PB_SNITCH_SW_DIR)/apps/fused_concat_linear
SN_APPS += $(PB_SNITCH_SW_DIR)/apps/mha
SN_APPS += $(PB_SNITCH_SW_DIR)/apps/summa_gemm

SN_TESTS = $(wildcard $(PB_SNITCH_SW_DIR)/tests/*.c)

include $(SN_ROOT)/make/sw.mk

$(PB_GEN_DIR)/pb_raw_addrmap.h: $(PB_RDL_ALL)
	$(PEAKRDL) raw-header $< -o $@ $(PEAKRDL_INCLUDES) $(PEAKRDL_DEFINES) --base_name $(notdir $(basename $@)) --format c

##############
## Cheshire ##
##############

PB_LINK_MODE ?= spm

# We need to include the address map and snitch cluster includes
CHS_SW_INCLUDES += -I$(PB_INCDIR)
CHS_SW_INCLUDES += -I$(SN_RUNTIME_SRCDIR)
CHS_SW_INCLUDES += -I$(PB_GEN_DIR)

# Collect tests, which should be build for all modes, and their .dump targets
PB_CHS_SW_TEST_SRC += $(wildcard $(PB_CHS_SW_DIR)/tests/*.c)
PB_CHS_SW_TEST_DUMP += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).dump)
PB_CHS_SW_TEST_ELF += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).elf)

PB_CHS_SW_TEST = $(PB_CHS_SW_TEST_DUMP)

$(PB_CHS_SW_TEST_DUMP): $(PB_CHS_SW_TEST_ELF)
$(PB_CHS_SW_TEST_ELF): $(PB_GEN_DIR)/pb_addrmap.h $(SN_RUNTIME_HAL_HDRS)

.PHONY: chs-sw-tests chs-sw-tests-clean

chs-sw-tests: $(PB_CHS_SW_TEST)

chs-sw-tests-clean:
	rm -f $(PB_CHS_SW_TEST_DUMP)
	rm -f $(PB_CHS_SW_TEST_ELF)

#########################
# General Phony targets #
#########################

# Alias targets to align them with Picobello naming convention
sn-tests-clean: sn-clean-tests
sn-runtime-clean: sn-clean-runtime
sn-apps-clean: sn-clean-apps

.PHONY: sw sw-tests sw-clean sw-tests-clean
sw sw-tests: chs-sw-tests sn-tests sn-apps

sw-clean sw-tests-clean: chs-sw-tests-clean sn-tests-clean sn-runtime-clean sn-apps-clean
