# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PB_CHS_SW_DIR = $(PB_ROOT)/sw/cheshire
PB_LINK_MODE = spm

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
