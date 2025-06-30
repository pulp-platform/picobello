// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>

#include "picobello_addrmap.h"

#include "snrt.h"
#include "data/data.h"

uint16_t *local_x;
uint16_t *local_w;
uint16_t *local_y;
uint32_t *local_z;

int main() {

  uint32_t errors = 0;
  int offload_id_tmp;

  uint32_t core_idx = snrt_global_core_idx();

  uint16_t x_size = M_SIZE * N_SIZE * sizeof(uint16_t);
  uint16_t w_size = N_SIZE * K_SIZE * sizeof(uint16_t);
  uint16_t y_size = M_SIZE * K_SIZE * sizeof(uint16_t);

  // Allocate space in TCDM and copy inputs to TCDM
  if (snrt_is_dm_core()) {
    local_x = (uint16_t *) PB_SNITCH_CL_TCDM_BASE_ADDR(0);
    local_w = (uint16_t *) (PB_SNITCH_CL_TCDM_BASE_ADDR(0) + 0x2000);
    local_y = (uint16_t *) (PB_SNITCH_CL_TCDM_BASE_ADDR(0) + 0x4000);
    local_z = (uint32_t *) (PB_SNITCH_CL_TCDM_BASE_ADDR(0) + 0x6000);
    snrt_dma_start_1d(local_x, x_inp, x_size);
    snrt_dma_start_1d(local_w, w_inp, w_size);
    snrt_dma_start_1d(local_y, y_inp, y_size);
    snrt_dma_start_1d(local_z, golden, y_size);
    snrt_dma_wait_all();
  }

  snrt_cluster_hw_barrier();

  if (core_idx == 0) {
    // Enable RedMulE
    hwpe_cg_enable();

    hwpe_soft_clear();

    while( ( offload_id_tmp = hwpe_acquire_job() ) < 0);

    redmule_cfg ((unsigned int) local_x,
                (unsigned int) local_w,
                (unsigned int) local_y,
                M_SIZE, N_SIZE, K_SIZE,
                (uint8_t) GEMM,
                (uint8_t) Float16);
    // Start RedMulE operation
    hwpe_trigger_job();
  }

  snrt_cluster_hw_barrier();

  if (core_idx == 0) {
    int status;
    snrt_interrupt_enable(IRQ_M_ACC);
    while ((status = hwpe_get_status()) != 0) snrt_wfi();
    hwpe_evt_clear(1 << core_idx);
    snrt_interrupt_disable(IRQ_M_ACC);

    // Disable RedMulE
    hwpe_cg_disable();

    // Check computation is correct
    errors = redmule16_compare_int((uint32_t*)local_y, local_z, M_SIZE*K_SIZE/2);
  }

  return errors;
}