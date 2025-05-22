// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>
//
// This code tests the multicast feature of the wide interconnect.
// It uses the DMA to broadcast chunks of data to different clusters
// in the Picobello system.

#include <stdint.h>
#include "picobello_addrmap.h"
#include "snrt.h"

#define INITIALIZER 0xAAAAAAAA

#ifndef LENGTH
#define LENGTH 32
#endif

#define LENGTH_TO_CHECK 32

#ifndef N_CLUSTERS_TO_USE
#define N_CLUSTERS_TO_USE snrt_cluster_num()
#endif

// TODO(lleone): Check if is okay to shift by 18. Probably you need to adapt it to picobello
#define BCAST_MASK_ACTIVE ((N_CLUSTERS_TO_USE - 1) << 18)
// #define BCAST_MASK_ALL ((snrt_cluster_num() - 1) << 18)


static inline void dma_broadcast_to_clusters(void* dst, void* src, size_t size) {
    // snrt_enable_multicast(BCAST_MASK_ACTIVE);
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        snrt_dma_start_1d_mcast(snrt_remote_l1_ptr(dst, 0, 1), src, size, BCAST_MASK_ACTIVE);
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
                *(uint32_t*)(CLUSTER_CLINT_SET_ADDR + SNRT_CLUSTER_OFFSET * i) = 0x1ff;
        }
    }
}

int main() {
    snrt_interrupt_enable(IRQ_M_CLUSTER);
    // snrt_int_clr_mcip();

    // Allocate destination buffer
    uint32_t *buffer_dst = snrt_l1_next_v2();
    uint32_t *buffer_src = buffer_dst + LENGTH;

    // First cluster initializes the source buffer and multicast-
    // copies it to the destination buffer in every cluster's TCDM.
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        for (uint32_t i = 0; i < LENGTH; i++) {
            buffer_src[i] = INITIALIZER;
        }
    }

    // Initiate DMA transfer (twice to preheat the cache)
    for (volatile int i = 0; i < 2; i++) {
        broadcast_wrapper(buffer_dst, buffer_src, LENGTH * sizeof(uint32_t));
    }

    // All other clusters wait on a global barrier to signal the transfer
    // completion.
    snrt_global_barrier();

    // Every cluster except cluster 0 checks that the data in the destination
    // buffer is correct. To speed this up we only check the first 32 elements.
    if (snrt_is_dm_core() && (snrt_cluster_idx() < N_CLUSTERS_TO_USE) && (snrt_cluster_idx() != 0)) {
        uint32_t n_errs = LENGTH_TO_CHECK;
        for (uint32_t i = 0; i < LENGTH_TO_CHECK; i++) {
            if (buffer_dst[i] == INITIALIZER) n_errs--;
        }
        return n_errs;
    } else
        return 0;
  }
