// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>

#include "pb_addrmap.h"

#include "snrt.h"
#include "data/redmule_tensors.h"

#ifndef N_CLUSTERS_TO_USE
#define N_CLUSTERS_TO_USE snrt_cluster_num()
#endif

// TODO(lleone): Check if is okay to shift by 18. Probably you need to adapt it to picobello
#define BCAST_MASK_ACTIVE ((N_CLUSTERS_TO_USE - 1) << 18)
// #define BCAST_MASK_ALL ((snrt_cluster_num() - 1) << 18)


static inline void dma_broadcast_to_clusters(void* dst, void* src, size_t size) {
    // snrt_enable_multicast(BCAST_MASK_ACTIVE);
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        snrt_dma_start_1d_mcast(snrt_remote_l1_ptr((void *) dst, 0, 1), src, size, BCAST_MASK_ACTIVE);
        snrt_dma_wait_all();
    }
    // snrt_disable_multicast();
}

static inline int cluster_participates_in_bcast(int i) {
    return (i < N_CLUSTERS_TO_USE);
}

static inline void broadcast_wrapper(void* dst, void* src, size_t size) {
    snrt_global_barrier();
    dma_broadcast_to_clusters(dst, src, size);
    // Put clusters who don't participate in the broadcast to sleep, as if
    // they proceed directly to the global barrier, they will interfere with
    // the other clusters, by sending their atomics on the narrow interconnect.
    if (!cluster_participates_in_bcast(snrt_cluster_idx())) {
        snrt_wfi();
        snrt_int_clr_mcip();
    }
    // Wake these up when cluster 0 is done
    else if ((snrt_cluster_idx() == 0) && snrt_is_dm_core()) {
        for (int i = 0; i < snrt_cluster_num(); i++) {
            if (!cluster_participates_in_bcast(i))
                snrt_cluster()->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }
    }
}

int main() {
  //if (snrt_cluster_idx() > 1) return 0;

  uint16_t *local_x;
  uint16_t *local_w;
  uint16_t *local_y;
  uint32_t *local_z;

  uint32_t errors = 0;
  int offload_id_tmp;

  uint32_t core_idx = snrt_cluster_core_idx();

  uint16_t x_size = M_SIZE * N_SIZE * sizeof(uint16_t);
  uint16_t w_size = N_SIZE * K_SIZE * sizeof(uint16_t);
  uint16_t y_size = M_SIZE * K_SIZE * sizeof(uint16_t);

  // Allocate space in TCDM and copy inputs to TCDM
  if (snrt_is_dm_core()) {
    local_x = (uint16_t *) snrt_l1_alloc_cluster_local(x_size, 64);
    local_w = (uint16_t *) snrt_l1_alloc_cluster_local(w_size, 64);
    local_y = (uint16_t *) snrt_l1_alloc_cluster_local(y_size, 64);
    local_z = (uint32_t *) snrt_l1_alloc_cluster_local(y_size, 64);

    // Cluster zero loads the matrices from L2
    if (snrt_cluster_idx() == 0) {
      snrt_dma_start_1d(local_x, x_inp, x_size);
      snrt_dma_start_1d(local_w, w_inp, w_size);
      snrt_dma_start_1d(local_y, y_inp, y_size);
      snrt_dma_start_1d(local_z, golden, y_size);
      snrt_dma_wait_all();
    }
  }

  broadcast_wrapper(local_x, local_x, x_size);
  broadcast_wrapper(local_w, local_w, w_size);
  broadcast_wrapper(local_y, local_y, y_size);
  broadcast_wrapper(local_z, local_z, y_size);
  snrt_global_barrier();

  if (snrt_is_dm_core()) {
    // Enable RedMulE
    redmule_cg_enable();

    redmule_soft_clear();

    while( ( offload_id_tmp = redmule_acquire_job() ) < 0);

    redmule_cfg ((unsigned int) local_x,
                (unsigned int) local_w,
                (unsigned int) local_y,
                M_SIZE, N_SIZE, K_SIZE,
                (uint8_t) REDMULE_GEMM,
                (uint8_t) REDMULE_Float16);
    // Start RedMulE operation
    redmule_trigger_job();
  }

  snrt_cluster_hw_barrier();

  if (core_idx == 0) {
    int status;
    snrt_interrupt_enable(IRQ_M_ACC);
    while ((status = redmule_get_status()) != 0) snrt_wfi();
    redmule_evt_clear(1 << core_idx);
    snrt_interrupt_disable(IRQ_M_ACC);

    // Disable RedMulE
    redmule_cg_disable();
  }

  snrt_cluster_hw_barrier();

  if (snrt_is_dm_core()) {
    // Check computation is correct
    errors = redmule16_compare_int((uint32_t*)local_y, local_z, M_SIZE*K_SIZE/2);
  }

  return errors;
}