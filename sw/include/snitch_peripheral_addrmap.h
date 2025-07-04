// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

#ifndef _PICOBELLO_MEMORY_MAP
#define _PICOBELLO_MEMORY_MAP

#include "snitch_cluster_addrmap.h"
#include "snitch_cluster_cfg.h"
#include "snitch_cluster_peripheral.h"

#define PB_SNITCH_BASE_ADDR CLUSTER_TCDM_BASE_ADDR
#define PB_SNITCH_END_ADDR 0x30000000
#define PB_SNITCH_CL_BASE_ADDR(idx) (CLUSTER_TCDM_BASE_ADDR + idx * SNRT_CLUSTER_OFFSET)
#define PB_SNITCH_CL_END_ADDR(idx) (PB_SNITCH_BASE_ADDR(idx) + SNRT_TCDM_SIZE)

#define PB_SNITCH_CL_TCDM_SIZE SNRT_TCDM_SIZE
#define PB_SNITCH_CL_BOOTROM_SIZE (CLUSTER_PERIPH_BASE_ADDR - CLUSTER_BOOTROM_BASE_ADDR)
#define PB_SNITCH_CL_PERIPH_SIZE (CLUSTER_ZERO_MEM_START_ADDR - CLUSTER_PERIPH_BASE_ADDR)
#define PB_SNITCH_CL_ZERO_MEM_SIZE (CLUSTER_ZERO_MEM_END_ADDR - CLUSTER_ZERO_MEM_START_ADDR)

#define PB_SNITCH_CL_TCDM_BASE_ADDR(idx) (CLUSTER_TCDM_BASE_ADDR + idx * SNRT_CLUSTER_OFFSET)
#define PB_SNITCH_CL_TCDM_END_ADDR(idx) (PB_SNITCH_CL_TCDM_BASE_ADDR(idx) + PB_SNITCH_CL_TCDM_SIZE)
#define PB_SNITCH_CL_BOOTROM_BASE_ADDR(idx) (CLUSTER_BOOTROM_BASE_ADDR + idx * SNRT_CLUSTER_OFFSET)
#define PB_SNITCH_CL_BOOTROM_END_ADDR(idx) (PB_SNITCH_CL_BOOTROM_BASE_ADDR(idx) + PB_SNITCH_CL_PERIPH_SIZE)
#define PB_SNITCH_CL_PERIPH_BASE_ADDR(idx) (CLUSTER_PERIPH_BASE_ADDR + idx * SNRT_CLUSTER_OFFSET)
#define PB_SNITCH_CL_PERIPH_END_ADDR(idx) (PB_SNITCH_CL_PERIPH_BASE_ADDR(idx) + PB_SNITCH_CL_PERIPH_SIZE)
#define PB_SNITCH_CL_ZERO_MEM_START_ADDR(idx) (CLUSTER_ZERO_MEM_START_ADDR + idx * SNRT_CLUSTER_OFFSET)
#define PB_SNITCH_CL_ZERO_MEM_END_ADDR(idx) (PB_SNITCH_CL_ZERO_MEM_START_ADDR(idx) + PB_SNITCH_CL_ZERO_MEM_SIZE)

#define SNITCH_CLUSTER_PERIPHERAL_SCRATCH_REG_OFFSET (SNITCH_CLUSTER_PERIPHERAL_SCRATCH_1_REG_OFFSET - SNITCH_CLUSTER_PERIPHERAL_SCRATCH_0_REG_OFFSET)
#define PB_SNITCH_CL_SCRATCH_ADDR(idx, scratch) (PB_SNITCH_CL_PERIPH_BASE_ADDR(idx) + SNITCH_CLUSTER_PERIPHERAL_SCRATCH_0_REG_OFFSET + scratch * SNITCH_CLUSTER_PERIPHERAL_SCRATCH_REG_OFFSET)
#define PB_SNITCH_CL_CLINT_SET_ADDR(idx) (PB_SNITCH_CL_PERIPH_BASE_ADDR(idx) + SNITCH_CLUSTER_PERIPHERAL_CL_CLINT_SET_REG_OFFSET)
#define PB_SNITCH_CL_CLINT_CLEAR_ADDR(idx) (PB_SNITCH_CL_PERIPH_BASE_ADDR(idx) + SNITCH_CLUSTER_PERIPHERAL_CL_CLINT_CLEAR_REG_OFFSET)

#endif // _PICOBELLO_MEMORY_MAP
