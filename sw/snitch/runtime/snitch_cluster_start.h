// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

#pragma once

#define SNRT_INIT_TLS
#define SNRT_INIT_BSS
#define SNRT_INIT_CLS
#define SNRT_INIT_LIBS
#define SNRT_CRT0_PRE_BARRIER
#define SNRT_INVOKE_MAIN
#define SNRT_CRT0_POST_BARRIER
#define SNRT_CRT0_EXIT
#define SNRT_CRT0_ALTERNATE_EXIT


static inline volatile uint32_t* snrt_exit_code_destination() {
    volatile uint32_t* scratch0_addr = (volatile uint32_t*)(ALIAS_PERIPH_BASE_ADDR + SNITCH_CLUSTER_PERIPHERAL_SCRATCH_0_REG_OFFSET);
    return (uint32_t*)(*scratch0_addr);
}

inline void snrt_exit(int exit_code) {
    *(snrt_exit_code_destination() + snrt_cluster_core_idx()) = (exit_code << 1) | 1;
}

#include "start.h"
