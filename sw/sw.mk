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

SNRT_TARGET_DIR     = $(PB_SNITCH_SW_DIR)/runtime
SNRT_TESTS_BUILDDIR = $(PB_SNITCH_SW_DIR)/tests/build
SN_RVTESTS_BUILDDIR = $(PB_SNITCH_SW_DIR)/riscv-tests/build
SNRT_INCDIRS        = $(PB_INCDIR) $(PB_GEN_DIR)
SNRT_BUILD_APPS     = OFF
SNRT_MEMORY_LD      = $(PB_SNITCH_SW_DIR)/memory.ld
SNRT_HAL_HDRS       = $(PB_GEN_DIR)/pb_addrmap.h

ifneq (,$(filter chs-bootrom% chs-sw% sn% pb-sn-tests% sw%,$(MAKECMDGOALS)))
include $(SN_ROOT)/target/snitch_cluster/sw.mk
endif

# SNITCH APPLICATIONS
$(eval include $(PB_SNITCH_SW_DIR)/apps/blas/gemm/app.mk)


# Collect Snitch tests which should be built
PB_SNRT_TESTS_DIR      = $(PB_SNITCH_SW_DIR)/tests
PB_SNRT_TESTS_BUILDDIR = $(PB_SNITCH_SW_DIR)/tests/build
PB_SNRT_TEST_NAMES = $(basename $(notdir $(wildcard $(PB_SNRT_TESTS_DIR)/*.c)))
PB_SNRT_TEST_ELFS = $(abspath $(addprefix $(PB_SNRT_TESTS_BUILDDIR)/,$(addsuffix .elf,$(PB_SNRT_TEST_NAMES))))
PB_SNRT_TEST_DUMP = $(abspath $(addprefix $(PB_SNRT_TESTS_BUILDDIR)/,$(addsuffix .dump,$(PB_SNRT_TEST_NAMES))))

.PHONY: pb-snrt-tests clean-pb-snrt-tests

pb-sn-tests: $(PB_SNRT_TEST_ELFS) $(PB_SNRT_TEST_DUMP)

clean-pb-sn-tests:
	rm -rf $(PB_SNRT_TEST_ELFS)

$(PB_SNRT_TEST_ELFS): $(PB_GEN_DIR)/pb_addrmap.h

$(PB_SNRT_TESTS_BUILDDIR)/%.d: $(PB_SNRT_TESTS_DIR)/%.c | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_CXX) $(SNRT_TESTS_RISCV_CFLAGS) -MM -MT '$(@:.d=.elf)' -x c++ $< > $@

$(PB_SNRT_TESTS_BUILDDIR)/%.elf: $(PB_SNRT_TESTS_DIR)/%.c $(SNRT_LIB) | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_CXX) $(SNRT_TESTS_RISCV_CFLAGS) $(SNRT_TESTS_RISCV_LDFLAGS) -x c++ $< -o $@

$(PB_SNRT_TESTS_BUILDDIR)/%.dump: $(PB_SNRT_TESTS_BUILDDIR)/%.elf | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_OBJDUMP) $(RISCV_OBJDUMP_FLAGS) $< > $@

##############
## Cheshire ##
##############

PB_LINK_MODE ?= spm

# We need to include the address map and snitch cluster includes
CHS_SW_INCLUDES += -I$(PB_INCDIR)
CHS_SW_INCLUDES += -I$(SNRT_HAL_HDRS_DIR)
CHS_SW_INCLUDES += -I$(PB_GEN_DIR)

# Collect tests, which should be build for all modes, and their .dump targets
PB_CHS_SW_TEST_SRC += $(wildcard $(PB_CHS_SW_DIR)/tests/*.c)
PB_CHS_SW_TEST_DUMP += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).dump)
PB_CHS_SW_TEST_ELF += $(PB_CHS_SW_TEST_SRC:.c=.$(PB_LINK_MODE).elf)

PB_CHS_SW_TEST = $(PB_CHS_SW_TEST_DUMP)

$(PB_CHS_SW_TEST_SRC): $(PB_GEN_DIR)/pb_addrmap.h
$(PB_CHS_SW_TEST_DUMP): $(PB_CHS_SW_TEST_ELF)

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
sw sw-tests: chs-sw-tests sn-tests pb-sn-tests sn-apps

sw-clean sw-tests-clean: chs-sw-tests-clean sn-tests-clean sn-runtime-clean clean-pb-sn-tests sn-apps-clean
