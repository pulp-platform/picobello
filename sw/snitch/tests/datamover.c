// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>

#include "snrt.h"
#include "pb_addrmap.h"

#include "data/datamover_data.h"

uint8_t *local_in;
uint8_t *local_out;
uint8_t *local_out2;
uint8_t *local_out3bis;
uint8_t *local_out3;
uint8_t *local_gold;
uint8_t *local_gold2;
uint8_t *local_gold3;

int main() {

  if (snrt_cluster_idx() > 0) return 0;

  uint32_t errors = 0;
  int offload_id_tmp;

  uint32_t core_idx = snrt_global_core_idx();

  uint16_t in_size  = SIZE * SIZE * sizeof(uint8_t);
  uint16_t out_size = SIZE * SIZE * sizeof(uint8_t);

  // Allocate space in TCDM and copy inputs to TCDM
  if (snrt_is_dm_core()) {
    local_in    = (uint8_t *) snrt_l1_alloc_cluster_local(in_size, 64);
    local_out   = (uint8_t *) snrt_l1_alloc_cluster_local(out_size, 64);
    local_gold  = (uint8_t *) snrt_l1_alloc_cluster_local(out_size, 64);
    local_out2  = (uint8_t *) snrt_l1_alloc_cluster_local(in_size/2, 64);
    local_gold2 = (uint8_t *) snrt_l1_alloc_cluster_local(in_size/2, 64);
    local_out3  = (uint8_t *) snrt_l1_alloc_cluster_local(in_size/4, 64);
    local_out3bis = (uint8_t *) snrt_l1_alloc_cluster_local(in_size/4, 64);
    local_gold3 = (uint8_t *) snrt_l1_alloc_cluster_local(in_size/4, 64);
    snrt_dma_start_1d(local_in, golden_in, in_size);
    snrt_dma_start_1d(local_gold, golden_out, in_size);
    snrt_dma_start_1d(local_gold2, golden_out2, in_size/2);
    snrt_dma_start_1d(local_gold3, golden_out3, in_size/4);
    snrt_dma_wait_all();
  }

  snrt_cluster_hw_barrier();

  if (core_idx == 0) {
    // Enable Datamover
    datamover_cg_enable();
    datamover_mux_enable();

    datamover_soft_clear();

    // First job: 8b transpose, 64x64 matrix
    while( ( offload_id_tmp = datamover_acquire_job() ) < 0);

    datamover_in_set((unsigned int) local_in);
    datamover_out_set((unsigned int) local_out);
    datamover_len0_set(
      ((64 & 0x00000fff) << 12) | // in_d0_len
      (64 & 0x00000fff)           // tot_len
    );
    datamover_len1_set(
      (64 & 0x00000fff)           // out_d0_len
    );
    datamover_in_d0_stride_set(64);
    datamover_out_d0_stride_set(64);
    datamover_transp_mode_set(DATAMOVER_TRANSP_8B);

    // Start Datamover operation
    datamover_trigger_job();

    // Second job: 16b transpose, 32x32 matrix
    while( ( offload_id_tmp = datamover_acquire_job() ) < 0);

    datamover_in_set((unsigned int) local_out);
    datamover_out_set((unsigned int) local_out2);
    datamover_len0_set(
      ((32 & 0x00000fff) << 12) | // in_d0_len
      (32 & 0x00000fff)           // tot_len
    );
    datamover_len1_set(
      (32 & 0x00000fff)           // out_d0_len
    );
    datamover_in_d0_stride_set(64);
    datamover_out_d0_stride_set(64);
    datamover_transp_mode_set(DATAMOVER_TRANSP_16B);

    // Start Datamover operation
    datamover_trigger_job();

    // Third job: 32b transpose, 16x16 matrix
    while( ( offload_id_tmp = datamover_acquire_job() ) < 0);

    datamover_in_set((unsigned int) local_out2);
    datamover_out_set((unsigned int) local_out3bis);
    datamover_len0_set(
      ((16 & 0x00000fff) << 12) | // in_d0_len
      (16 & 0x00000fff)           // tot_len
    );
    datamover_len1_set(
      (16 & 0x00000fff)           // out_d0_len
    );
    datamover_in_d0_stride_set(64);
    datamover_out_d0_stride_set(64);
    datamover_transp_mode_set(DATAMOVER_TRANSP_32B);

    // Start Datamover operation
    datamover_trigger_job();

    // Fourth job: no transpose, 16x16 matrix
    while( ( offload_id_tmp = datamover_acquire_job() ) < 0);

    datamover_in_set((unsigned int) local_out3bis);
    datamover_out_set((unsigned int) local_out3);
    datamover_len0_set(
      ((16 & 0x00000fff) << 12) | // in_d0_len
      (16 & 0x00000fff)           // tot_len
    );
    datamover_len1_set(
      (16 & 0x00000fff)           // out_d0_len
    );
    datamover_in_d0_stride_set(64);
    datamover_out_d0_stride_set(64);
    datamover_transp_mode_set(DATAMOVER_TRANSP_NONE);

    // Start Datamover operation
    datamover_trigger_job();

  }

  snrt_cluster_hw_barrier();

  if (core_idx == 0) {

    int status;
    snrt_interrupt_enable(IRQ_M_ACC);
    while ((status = datamover_get_status()) != 0) snrt_wfi();
    datamover_evt_clear(1 << core_idx);
    snrt_interrupt_disable(IRQ_M_ACC);

    // Disable Datamover
    datamover_cg_disable();

    // Check computation is correct
    errors  = datamover_compare_int((uint64_t*)local_out,  (uint64_t*) local_gold,  SIZE*SIZE/8);
    errors += datamover_compare_int((uint64_t*)local_out2, (uint64_t*) local_gold2, SIZE*SIZE/16);
    errors += datamover_compare_int((uint64_t*)local_out3, (uint64_t*) local_gold3, SIZE*SIZE/32);
  }

  return errors;
}