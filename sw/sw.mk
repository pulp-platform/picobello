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

####################
## Snitch Cluster ##
####################

SNRT_TARGET_DIR     = $(PB_SNITCH_SW_DIR)/runtime
SNRT_TESTS_BUILDDIR = $(PB_SNITCH_SW_DIR)/tests/build
SN_RVTESTS_BUILDDIR = $(PB_SNITCH_SW_DIR)/riscv-tests/build
SNRT_INCDIRS        = $(PB_INCDIR)
SNRT_BUILD_APPS     = OFF
SNRT_MEMORY_LD      = $(PB_SNITCH_SW_DIR)/memory.ld

ifneq (,$(filter chs-bootrom% chs-sw% sn% pb-sn-tests% sw%,$(MAKECMDGOALS)))
include $(SN_ROOT)/target/snitch_cluster/sw.mk
endif

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

$(PB_SNRT_TESTS_BUILDDIR)/%.d: $(PB_SNRT_TESTS_DIR)/%.c | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_CXX) $(SNRT_TESTS_RISCV_CFLAGS) -MM -MT '$(@:.d=.elf)' -x c++ $< > $@

$(PB_SNRT_TESTS_BUILDDIR)/%.elf: $(PB_SNRT_TESTS_DIR)/%.c $(SNRT_LIB) | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_CXX) $(SNRT_TESTS_RISCV_CFLAGS) $(SNRT_TESTS_RISCV_LDFLAGS) -x c++ $< -o $@

$(PB_SNRT_TESTS_BUILDDIR)/%.dump: $(PB_SNRT_TESTS_BUILDDIR)/%.elf | $(PB_SNRT_TESTS_BUILDDIR)
	$(RISCV_OBJDUMP) $(RISCV_OBJDUMP_FLAGS) $< > $@

######################
## Picobello Global ##
######################

PB_ADDRMAP = $(PB_SW_DIR)/include/picobello_addrmap.h

$(PB_ADDRMAP): $(SNRT_TARGET_C_HDRS)

##############
## Cheshire ##
##############

PB_LINK_MODE ?= spm

# We need to include the address map and snitch cluster includes
CHS_SW_INCLUDES += -I$(PB_INCDIR)
CHS_SW_INCLUDES += -I$(SNRT_HAL_HDRS_DIR)

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
	rm -f $(PB_SN_SW_TEST_ELF)

#########################
# General Phony targets #
#########################

# Alias sn-clean-tests to align target with Picobello naming convention
sn-tests-clean: sn-clean-tests

.PHONY: sw sw-tests sw-clean sw-tests-clean
sw sw-tests: chs-sw-tests sn-tests pb-sn-tests

sw-clean sw-tests-clean: chs-sw-tests-clean sn-tests-clean clean-pb-sn-tests
