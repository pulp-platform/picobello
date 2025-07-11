# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo leone <lleone@iis.ee.ethz.ch>

APP              := gemm
$(APP)_BUILD_DIR ?= $(PB_SNITCH_SW_DIR)/apps/blas/$(APP)/build
SRC_DIR          := $(PB_SNITCH_SW_DIR)/apps/blas/$(APP)/src
SRCS             := $(SRC_DIR)/gemm_picobello.c
$(APP)_INCDIRS   := $(SN_ROOT)/sw/blas $(SN_ROOT)/sw/blas/$(APP)/src

# Refer to snitch utiulities
$(APP)_SCRIPT_DIR :=  $(SN_ROOT)/sw/blas/$(APP)/scripts

include $(SN_ROOT)/sw/apps/common.mk
include $(SN_ROOT)/target/snitch_cluster/sw/apps/common.mk
