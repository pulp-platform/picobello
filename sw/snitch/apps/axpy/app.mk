# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

APP              := axpy
$(APP)_BUILD_DIR ?= $(PB_SNITCH_SW_DIR)/apps/$(APP)/build
$(APP)_DATA_CFG  := $(PB_SNITCH_SW_DIR)/apps/$(APP)/data/params.json
SRC_DIR          := $(SN_ROOT)/sw/kernels/blas/$(APP)/src
SRCS             := $(SRC_DIR)/main.c
$(APP)_INCDIRS   := $(SN_ROOT)/sw/kernels/blas

include $(SN_ROOT)/sw/kernels/datagen.mk
include $(SN_ROOT)/sw/kernels/common.mk
