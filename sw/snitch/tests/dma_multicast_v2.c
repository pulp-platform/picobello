// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>
// Lorenzo Leone   <lleone@iis.ee.ethz.ch>
//
// This code implements a function to multicast data from one memory tile
// to all clusters in the same row.

#define SNRT_ENABLE_NARROW_REDUCTION
#define SNRT_ENABLE_NARROW_MULTICAST

#include <stdint.h>
#include "snrt.h"

// Transfer size in bytes
#ifndef SIZE
#define SIZE 1024
#endif

// Batch size in bytes
#ifndef BATCH
#define BATCH 64
#endif

#define N_BATCHES (SIZE / BATCH)
#define N_ELEMS (SIZE / sizeof(uint32_t))

#define ELEMS_TO_CHECK 32

#ifndef N_CLUSTERS_TO_USE
#define N_CLUSTERS_TO_USE 4
#endif

// TODO(colluca): calculate from non-log2 function
static inline uint32_t pb_log2_cluster_num_in_col() {
    return 2;
}

static inline uint32_t pb_cluster_num_in_row() {
    return 4;
}

static inline uint32_t pb_cluster_row_idx() {
    return snrt_cluster_idx() % pb_cluster_num_in_row();
}

static inline uint32_t pb_cluster_in_row(uint32_t row_idx) {
    return pb_cluster_row_idx() == row_idx;
}

static inline uint32_t pb_cluster_idx_in_row() {
    return snrt_cluster_idx() / pb_cluster_num_in_row();
}

static inline uint32_t pb_cluster_left_neighbour() {
    return snrt_cluster_idx() - pb_cluster_num_in_row();
}

static inline void pb_create_row_comm(uint32_t row, snrt_comm_t *comm) {
    // Allocate communicator struct in L1 and point to it.
    *comm =
        (snrt_comm_t)snrt_l1_alloc_cluster_local(sizeof(snrt_comm_info_t));

    // Allocate barrier counter in L1. Only the zero-th cluster's is actually
    // used, but we want to keep all clusters' L1 allocators aligned. Thus, 
    // only cluster 0 initializes its barrier counter. A global barrier is
    // then used to ensure all cores "see" the initialized value.
    void *barrier_ptr = snrt_l1_alloc_cluster_local(sizeof(uint32_t));
    barrier_ptr = snrt_remote_l1_ptr(barrier_ptr, snrt_cluster_idx(), 0);
    if (snrt_global_core_idx() == 0) *(uint32_t *)barrier_ptr = 0;
    snrt_global_barrier();

    // Initialize communicator, pointing to the newly-allocated barrier
    // counter in L3.
    (*comm)->size = pb_cluster_num_in_row();
    (*comm)->mask = row |
        ((pb_cluster_num_in_row() - 1) << pb_log2_cluster_num_in_col());
    (*comm)->base = row;
    (*comm)->barrier_ptr = (uint32_t *)barrier_ptr;
    (*comm)->is_participant = pb_cluster_in_row(row);
}

// L1 buffer of every cluster invoking this function should be
// at the same offset in the TCDM
static inline void dma_multicast(uintptr_t l1_buffer, uintptr_t l3_buffer,
    snrt_comm_t comm) {
        
#ifdef ENABLE_WIDE_MULTICAST
    // Only DMA core of cluster 0 continues past this point
    if (!snrt_is_dm_core() || !(snrt_cluster_idx() == 0)) return;

    // Hardware multicast transfer
    uint64_t mask = snrt_get_collective_mask(comm);
    snrt_dma_enable_multicast(mask);
    snrt_mcycle();
    snrt_dma_start_1d(l1_buffer, l3_buffer, SIZE);
    snrt_dma_disable_multicast();
    snrt_dma_wait_all();
#else
    // Only DMA cores of clusters in the first row participate
    if (!snrt_is_dm_core() || !comm->is_participant) return;
        
    // Compute address of source buffer (in left tile)
    uintptr_t src;
    if (snrt_cluster_idx() == 0) {
        src = l3_buffer;
    } else {
        src = (uintptr_t)snrt_remote_l1_ptr((void *)l1_buffer,
            snrt_cluster_idx(), pb_cluster_left_neighbour());
    }

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iterations to cover all transfers
    uint32_t n_iters = N_BATCHES - 1 + N_CLUSTERS_TO_USE;
    for (uint32_t i = 0; i < n_iters; i++) {

        // Every cluster is active for N_BATCHES iterations
        // starting from the iteration with i == snrt_cluster_idx()
        // TODO(colluca): use communicator
        char cluster_active = i >= pb_cluster_idx_in_row();
        cluster_active &= i < (pb_cluster_idx_in_row() + N_BATCHES);

        // Every active cluster copies data from the left tile
        if (cluster_active) {
            snrt_mcycle();

            // Start DMA
            snrt_dma_start_1d(l1_buffer, src, BATCH);

            // Update pointers for next iteration while transfer completes,
            // preventing instructions from being reordered after the DMA wait
            l1_buffer += BATCH;
            src += BATCH;
            asm volatile ("" : "+r"(l1_buffer), "+r"(src) ::);

            // Wait for DMA to complete
            snrt_dma_wait_all();
            snrt_mcycle();
        }
        
        // Perform inter-cluster barrier. Disable reduction before the fence
        // so it overlaps with the latency of the ongoing reduction operation.
        snrt_set_awuser_low(user);
        *barrier_ptr = 1;
        snrt_set_awuser_low(0);
        snrt_fence();
    }
#endif
} 

// Global variables for verification script
uint32_t output[N_ELEMS * N_CLUSTERS_TO_USE];
uint32_t n_clusters = N_CLUSTERS_TO_USE;
uint32_t length = N_ELEMS * N_CLUSTERS_TO_USE;

int main() {
    // Enable interrupts and clear pending interrupt
    snrt_interrupt_enable(IRQ_M_CLUSTER);
    snrt_int_clr_mcip();

    // Allocate 4KiB-aligned buffer in every cluster
    uint32_t *buffer = (uint32_t *)snrt_l1_alloc_cluster_local(SIZE, 4096);

    // Allocate 4KiB-aligned buffer in memory tile
    uint32_t *l3_buffer = (uint32_t *)snrt_l3_alloc_v2(SIZE, 4096);

    // First cluster initializes the L3 buffer.
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        DUMP(l3_buffer);
        for (uint32_t i = 0; i < N_ELEMS; i++) {
            l3_buffer[i] = i + 1;
        }
    }

    // Every cluster in row 0 initializes its destination buffer
    if (snrt_is_dm_core() && pb_cluster_in_row(0)) {
        snrt_dma_start_1d(
            (uintptr_t)buffer, (uintptr_t)(snrt_cluster()->zeromem.mem), SIZE);
        snrt_dma_wait_all();
    }

    // Create communicator for row 0 (all other clusters are inactive)
    // TODO(colluca): extend to use N_CLUSTERS_TO_USE
    snrt_comm_t comm;
    pb_create_row_comm(0, &comm);

    // Only DMA cores of clusters in the first row continue from here
    if (!snrt_is_dm_core() || !comm->is_participant) return 0;

    // Print participating clusters
    if (snrt_is_dm_core() && snrt_cluster_idx() == 0) {
        uint32_t mask = comm->mask;
        uint32_t fixed = comm->base & ~mask;
        uint32_t submask = 0;
        do {
            uint32_t i = fixed | submask;
            DUMP(i);
            submask = (submask - 1) & mask;
        } while (submask != 0);
    }

    // Synchronize all clusters.
    snrt_inter_cluster_barrier(comm);

    // Initiate multicast transfer (twice to preheat the cache)
    for (volatile int i = 0; i < 2; i++) {
        snrt_mcycle();
        dma_multicast((uintptr_t)buffer, (uintptr_t)l3_buffer, comm);
        snrt_mcycle();
        snrt_inter_cluster_barrier(comm);
    }

    // Writeback to L3
    if (snrt_is_dm_core() && pb_cluster_in_row(0)) {
        uint32_t offset = pb_cluster_idx_in_row() * SIZE;
        snrt_dma_start_1d(
            (uintptr_t)output + offset, (uintptr_t)buffer, SIZE);
        snrt_dma_wait_all();
    }

    // Every cluster checks that the data in its buffer is correct
    if (snrt_is_dm_core() && pb_cluster_in_row(0)) {
        uint32_t n_errs = ELEMS_TO_CHECK;
        uint32_t stride = N_ELEMS / ELEMS_TO_CHECK;
        for (uint32_t i = 0; i < N_ELEMS; i += stride)
            if (buffer[i] == (i + 1)) n_errs--;
        return n_errs;
    } else
        return 0;
  }
