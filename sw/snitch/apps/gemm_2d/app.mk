# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

APP              := gemm_2d
$(APP)_BUILD_DIR ?= $(PB_SNITCH_SW_DIR)/apps/$(APP)/build
SRC_DIR          := $(PB_SNITCH_SW_DIR)/apps/$(APP)/src
SRCS             := $(SRC_DIR)/gemm_2d.c
$(APP)_INCDIRS   := $(SN_ROOT)/sw/kernels/blas $(SN_ROOT)/sw/kernels/blas/gemm/src

# Refer to Snitch scripts
$(APP)_SCRIPT_DIR :=  $(SN_ROOT)/sw/kernels/blas/gemm/scripts

include $(SN_ROOT)/sw/kernels/datagen.mk
include $(SN_ROOT)/sw/kernels/common.mk
