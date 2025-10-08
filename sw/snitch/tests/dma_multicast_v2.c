// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>
// Lorenzo Leone   <lleone@iis.ee.ethz.ch>
//
// This code implements a function to multicast data from one memory tile
// to all clusters in the same row, or multiple rows.

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

typedef enum {
    SEQ,
    TREE,
    HW
} impl_t;

#ifndef IMPL
#define IMPL SEQ
#endif

#define N_BATCHES (SIZE / BATCH)
#define N_ELEMS (SIZE / sizeof(uint32_t))

#ifndef LOG2_N_ROWS
#define LOG2_N_ROWS 2
#endif

#define N_ROWS (1 << LOG2_N_ROWS)

// TODO(colluca): calculate from non-log2 function
static inline constexpr uint32_t pb_log2_cluster_num_in_col() {
    return 2;
}

static inline constexpr uint32_t pb_log2_cluster_num_in_row() {
    return 2;
}

static inline void dma_multicast_sequential(uintptr_t l1_buffer,
    uintptr_t l3_buffer, snrt_comm_t comm) {
    // Only DMA cores of clusters in the first row participate
    if (!snrt_is_dm_core() || !comm->is_participant) return;
        
    // Compute address of source buffer:
    // - in memory tile for cluster 0
    // - in left neighbour for clusters in row 0
    // - in bottom neighbour for clusters in other rows
    uintptr_t src;
    if (snrt_cluster_idx() == 0) {
        src = l3_buffer;
    } else if (pb_cluster_in_row(0)) {
        src = (uintptr_t)snrt_remote_l1_ptr((void *)l1_buffer,
            snrt_cluster_idx(), pb_cluster_west_neighbour());
    } else {
        src = (uintptr_t)snrt_remote_l1_ptr((void *)l1_buffer,
            snrt_cluster_idx(), pb_cluster_south_neighbour());
    }

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iterations to cover all transfers in a row
    uint32_t n_iters = N_BATCHES - 1 + pb_cluster_num_in_row();
    for (uint32_t i = 0; i < n_iters; i++) {

        // Every cluster is active for N_BATCHES iterations
        // starting from the iteration with i == snrt_cluster_idx()
        char cluster_active = i >= pb_cluster_col_idx();
        cluster_active &= i < (pb_cluster_col_idx() + N_BATCHES);
        cluster_active &= pb_cluster_in_row(0);

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

    // Iterations to cover all transfers in each column
    n_iters = N_BATCHES - 1 + N_ROWS - 1;
    for (uint32_t i = 0; i < n_iters; i++) {

        // Every cluster is active for N_BATCHES iterations
        // starting from the iteration with (i + 1) == pb_cluster_row_idx()
        char cluster_active = (i + 1) >= pb_cluster_row_idx();
        cluster_active &= (i + 1) < (pb_cluster_row_idx() + N_BATCHES);
        cluster_active &= !pb_cluster_in_row(0);

        // Every active cluster copies data from the bottom tile
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
}

static inline void dma_multicast_tree(uintptr_t l1_buffer,
    uintptr_t l3_buffer, snrt_comm_t comm) {

    // Only DMA cores of clusters in the first row participate
    if (!snrt_is_dm_core() || !comm->is_participant) return;

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iteration 0: cluster 0 fetches data from memory tile
    if (snrt_cluster_idx() == 0) {
        snrt_mcycle();
        snrt_dma_start_1d(l1_buffer, l3_buffer, SIZE);
        snrt_dma_wait_all();
        snrt_mcycle();
    }

    // Iterations to cover all transfers in a row
    uint32_t n_levels_in_row = pb_log2_cluster_num_in_row();
    for (uint32_t i = 0; i < n_levels_in_row; i++) {

        // Determine which clusters are senders at every level of the tree
        char cluster_idx_inv = pb_cluster_num_in_row() - pb_cluster_col_idx();
        char num_active_clusters = 1 << i;
        char sender_stride = pb_cluster_num_in_row() / num_active_clusters;
        char is_sender = ((cluster_idx_inv % sender_stride) == 0)
            && pb_cluster_in_row(0);

        // Every active cluster sends the data to a cluster on the right
        if (is_sender) {

            // Calculate destination
            char receiver_offset = sender_stride / 2;
            uintptr_t dst_cluster = pb_calculate_cluster_idx(0,
                pb_cluster_col_idx() + receiver_offset);
            uintptr_t dst = (uintptr_t)snrt_remote_l1_ptr((void *)l1_buffer,
                snrt_cluster_idx(), dst_cluster);

            snrt_mcycle();

            // Start DMA
            snrt_dma_start_1d(dst, l1_buffer, SIZE);

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

    // Iterations to cover all transfers in each column
    uint32_t n_levels_in_col = LOG2_N_ROWS;
    for (uint32_t i = 0; i < n_levels_in_col; i++) {

        // Determine which clusters are senders at every level of the tree
        char row_idx_inv = N_ROWS - pb_cluster_row_idx();
        char num_active_rows = 1 << i;
        char sender_stride = N_ROWS / num_active_rows;
        char is_sender = (row_idx_inv % sender_stride) == 0;

        // Every active cluster sends the data to a cluster above it
        if (is_sender) {

            // Calculate destination 
            char receiver_offset = sender_stride / 2;
            uintptr_t dst_cluster = pb_calculate_cluster_idx(
                pb_cluster_row_idx() + receiver_offset, pb_cluster_col_idx());
            uintptr_t dst = (uintptr_t)snrt_remote_l1_ptr((void *)l1_buffer,
                snrt_cluster_idx(), dst_cluster);

            snrt_mcycle();

            // Start DMA
            snrt_dma_start_1d(dst, l1_buffer, SIZE);

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
}

static inline void dma_multicast_hw(uintptr_t l1_buffer,
    uintptr_t l3_buffer, snrt_comm_t comm) {
        // Only DMA core of cluster 0 continues past this point
    if (!snrt_is_dm_core() || !(snrt_cluster_idx() == 0)) return;

    // Hardware multicast transfer
    uint64_t mask = snrt_get_collective_mask(comm);
    snrt_dma_enable_multicast(mask);
    snrt_mcycle();
    snrt_dma_start_1d(l1_buffer, l3_buffer, SIZE);
    snrt_dma_disable_multicast();
    snrt_dma_wait_all();
}

// L1 buffer of every cluster invoking this function should be
// at the same offset in the TCDM
static inline void dma_multicast(uintptr_t l1_buffer, uintptr_t l3_buffer,
    snrt_comm_t comm) {
    if (IMPL == SEQ)
        dma_multicast_sequential(l1_buffer, l3_buffer, comm);
    else if (IMPL == TREE)
        dma_multicast_tree(l1_buffer, l3_buffer, comm);
    else if (IMPL == HW)
        dma_multicast_hw(l1_buffer, l3_buffer, comm);
} 

// Global variables for verification script
uint32_t output[N_ELEMS * N_ROWS * pb_cluster_num_in_row()];
extern const uint32_t n_clusters = N_ROWS * pb_cluster_num_in_row();
extern const uint32_t length = N_ELEMS * N_ROWS * pb_cluster_num_in_row();

int main() {

    // Allocate 4KiB-aligned buffer in every cluster
    uint32_t *buffer = (uint32_t *)snrt_l1_alloc_cluster_local(SIZE, 4096);

    // Allocate 4KiB-aligned buffer in memory tile
    uint32_t *l3_buffer = (uint32_t *)snrt_l3_alloc_v2(SIZE, 4096);

    // First cluster initializes the L3 buffer.
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
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

    // Create communicator for first N rows (all other clusters are inactive)
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, N_ROWS, pb_cluster_num_in_row());

    // Only DMA cores of clusters in the first N rows continue from here
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
    if (snrt_is_dm_core() && (pb_cluster_row_idx() < N_ROWS)) {
        uint32_t cluster_idx = pb_cluster_col_idx() +
            pb_cluster_row_idx() * pb_cluster_num_in_row();
        uint32_t offset = cluster_idx * SIZE;
        snrt_dma_start_1d(
            (uintptr_t)output + offset, (uintptr_t)buffer, SIZE);
        snrt_dma_wait_all();
    }

    return 0;
}
