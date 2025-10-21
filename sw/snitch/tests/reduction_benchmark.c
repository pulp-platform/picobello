// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

#include "snrt.h"
#include "blas.h"

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
#define N_ELEMS (SIZE / sizeof(double))

#ifndef LOG2_N_ROWS
#define LOG2_N_ROWS 0
#endif

#define N_ROWS (1 << LOG2_N_ROWS)

// Replace `1` literals with this thread-local variable to prevent it from
// being allocated by the compiler in L2.
__thread double one = 1;

static inline void dma_reduction_seq(uintptr_t src, uintptr_t dst,
    snrt_comm_t comm) {
    return;
}

static inline void dma_reduction_hw(uintptr_t src, uintptr_t dst,
    snrt_comm_t comm) {
    if (snrt_is_dm_core() && comm->is_participant) {
        uintptr_t remote_dst = (uintptr_t)snrt_remote_l1_ptr(
            (void *)dst, snrt_cluster_idx(), 0);
        snrt_collective_opcode_t op = SNRT_REDUCTION_FADD;
        snrt_dma_start_1d_reduction(remote_dst, src, SIZE, comm, op);
        snrt_dma_wait_all();
    }
}

static inline void dma_reduction_tree_transfer_left_phase(char is_sender, char dist,
    uintptr_t src, uintptr_t dst) {

    // Every sending cluster sends the data to a cluster on the left
    if (is_sender && snrt_is_dm_core()) {

        // Calculate destination
        uintptr_t dst_cluster = pb_calculate_cluster_idx(
            pb_cluster_row_idx(), pb_cluster_col_idx() - dist);
        uintptr_t remote_dst = (uintptr_t)snrt_remote_l1_ptr((void *)dst,
            snrt_cluster_idx(), dst_cluster);

        snrt_mcycle();

        // Start DMA
        snrt_dma_start_1d(remote_dst, src, BATCH);

        // Wait for DMA to complete
        snrt_dma_wait_all();
        snrt_mcycle();
    }
}

static inline void dma_reduction_tree_transfer_south_phase(char is_sender, char dist,
    uintptr_t src, uintptr_t dst) {

    // Every sending cluster sends the data to a cluster on the left
    if (is_sender && snrt_is_dm_core()) {

        // Calculate destination
        uintptr_t dst_cluster = pb_calculate_cluster_idx(
            pb_cluster_row_idx() - dist, pb_cluster_col_idx());
        uintptr_t remote_dst = (uintptr_t)snrt_remote_l1_ptr((void *)dst,
            snrt_cluster_idx(), dst_cluster);

        snrt_mcycle();

        // Start DMA
        snrt_dma_start_1d(remote_dst, src, BATCH);

        // Wait for DMA to complete
        snrt_dma_wait_all();
        snrt_mcycle();
    }
}

static inline void dma_reduction_tree_compute_phase(char is_receiver,
    uintptr_t src, uintptr_t dst, uintptr_t result) {

    // Every receiving cluster reduces the data from the sender
    if (is_receiver && snrt_is_compute_core()) {
        snrt_mcycle();
        uint32_t n_elems_per_batch = N_ELEMS / N_BATCHES;
        axpy_opt(n_elems_per_batch, one, (double *)src, (double *)dst,
            (double *)result);
        snrt_mcycle();
    }
    snrt_cluster_hw_barrier();
}

static inline void global_hw_barrier(volatile uint32_t *barrier_ptr,
    uint32_t user) {

    // Perform inter-cluster barrier. Disable reduction before the fence
    // so it overlaps with the latency of the ongoing reduction operation.
    if (snrt_is_dm_core()) {
        snrt_set_awuser_low(user);
        *barrier_ptr = 1;
        snrt_set_awuser_low(0);
        snrt_fence();
    }
    snrt_cluster_hw_barrier();
}

static inline void swap_buffers(uintptr_t *a, uintptr_t *b) {
    uintptr_t temp = *a;
    *a = *b;
    *b = temp;
}

// We need four buffers. Upon function invocation, the data must be in a.
static inline void dma_reduction_tree(uintptr_t a, uintptr_t b, uintptr_t c,
    uintptr_t d, snrt_comm_t comm) {

    // Only clusters in the communicator continue from here
    if (!comm->is_participant) return;

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Initially a is the source buffer and c is the result buffer
    uintptr_t src = a;
    uintptr_t dst[2] = {b, d};
    uintptr_t result = c;

    // Iterations to cover all reductions in a row
    uint32_t n_levels_in_row = pb_log2_cluster_num_in_row();
    for (uint32_t i = 0; i < n_levels_in_row; i++) {

        // Determine which clusters are senders at every level of the tree
        char dist = 1 << i;  // Distance between clusters in a pair
        char is_sender = (pb_cluster_col_idx() % (2*dist)) == dist;
        char is_receiver = (pb_cluster_col_idx() % (2*dist)) == 0;

        // Transfer phase for first batch
        dma_reduction_tree_transfer_left_phase(is_sender, dist, src, dst[0]);
        global_hw_barrier(barrier_ptr, user);

        // If more than one batch is present, there will be N_BATCHES - 1
        // iterations in which we perform both transfer and compute phases
        uint32_t j = 0;
        for (; j < N_BATCHES - 1; j++) {
            // Alternate destination buffers for every batch
            uintptr_t dma_dst = dst[(j+1)%2];
            uintptr_t comp_dst = dst[j%2];

            // Calculate pointers for current batch
            uintptr_t batch_dma_src = src + (j+1) * BATCH;
            uintptr_t batch_comp_src = src + j * BATCH;
            uintptr_t batch_result = result + j * BATCH;

            dma_reduction_tree_transfer_left_phase(is_sender, dist, batch_dma_src,
                dma_dst);
            dma_reduction_tree_compute_phase(is_receiver, batch_comp_src,
                comp_dst, batch_result);
            global_hw_barrier(barrier_ptr, user);
        }

        // Compute phase for last batch
        dma_reduction_tree_compute_phase(is_receiver, src + j * BATCH,
            dst[j%2], result + j * BATCH);

        // Swap source and result buffers for next iteration
        swap_buffers(&src, &result);
    }

    // Iterations to cover all reductions in the first column
    uint32_t n_levels_in_col = LOG2_N_ROWS;
    for (uint32_t i = 0; i < n_levels_in_col; i++) {

        // Determine which clusters are senders at every level of the tree
        char dist = 1 << i;  // Distance between clusters in a pair
        char is_sender = (pb_cluster_row_idx() % (2*dist)) == dist && pb_cluster_in_col(0);
        char is_receiver = (pb_cluster_row_idx() % (2*dist)) == 0 && pb_cluster_in_col(0);

        // Transfer phase for first batch
        dma_reduction_tree_transfer_south_phase(is_sender, dist, src, dst[0]);
        global_hw_barrier(barrier_ptr, user);

        // If more than one batch is present, there will be N_BATCHES - 1
        // iterations in which we perform both transfer and compute phases
        uint32_t j = 0;
        for (; j < N_BATCHES - 1; j++) {
            // Alternate destination buffers for every batch
            uintptr_t dma_dst = dst[(j+1)%2];
            uintptr_t comp_dst = dst[j%2];

            // Calculate pointers for current batch
            uintptr_t batch_dma_src = src + (j+1) * BATCH;
            uintptr_t batch_comp_src = src + j * BATCH;
            uintptr_t batch_result = result + j * BATCH;

            dma_reduction_tree_transfer_south_phase(is_sender, dist, batch_dma_src,
                dma_dst);
            dma_reduction_tree_compute_phase(is_receiver, batch_comp_src,
                comp_dst, batch_result);
            global_hw_barrier(barrier_ptr, user);
        }

        // Compute phase for last batch
        dma_reduction_tree_compute_phase(is_receiver, src + j * BATCH,
            dst[j%2], result + j * BATCH);

        // Swap source and result buffers for next iteration
        swap_buffers(&src, &result);
    }
}

// L1 buffer of every cluster invoking this function should be
// at the same offset in the TCDM
static inline void dma_reduction(uintptr_t a, uintptr_t b, uintptr_t c,
    uintptr_t d, snrt_comm_t comm) {
    if (IMPL == SEQ)
        dma_reduction_seq(a, c, comm);
    else if (IMPL == TREE)
        dma_reduction_tree(a, b, c, d, comm);
    else if (IMPL == HW)
        dma_reduction_hw(a, c, comm);
}

// Global variables for verification script
double output[N_ELEMS];
extern const uint32_t n_clusters = N_ROWS * pb_cluster_num_in_row();
extern const uint32_t length = N_ELEMS;

int main (void){

    // Allocate 4KiB-aligned buffers in every cluster
    uintptr_t a_buffer = (uintptr_t)snrt_l1_alloc_cluster_local(SIZE, 4096);
    uintptr_t c_buffer = (uintptr_t)snrt_l1_alloc_cluster_local(SIZE, 4096);
    uintptr_t b_buffer = (uintptr_t)snrt_l1_alloc_cluster_local(BATCH, 4096);
    uintptr_t d_buffer = (uintptr_t)snrt_l1_alloc_cluster_local(BATCH, 4096);

    // Create communicator for first N rows (all other clusters are inactive)
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, N_ROWS, pb_cluster_num_in_row());

    // Only clusters in the first N rows continue from here
    if (!comm->is_participant) return 0;

    // Two iterations to to preheat the cache
    for (volatile int i = 0; i < 2; i++){

        // Initialize source buffer
        if (snrt_is_dm_core()) {
            for (uint32_t i = 0; i < N_ELEMS; i++) {
                uint32_t row_major_cluster_idx = pb_cluster_col_idx() +
                    pb_cluster_row_idx() * pb_cluster_num_in_row();
                ((double *)a_buffer)[i] = row_major_cluster_idx + i;
            }
        }
        snrt_global_barrier(comm);

        // Perform reduction
        snrt_mcycle();
        dma_reduction(a_buffer, b_buffer, c_buffer, d_buffer, comm);
        snrt_mcycle();
        snrt_global_barrier(comm);
    }

    // Writeback to L3
    uintptr_t result_buffer = c_buffer;
    uint32_t total_tree_levels = pb_log2_cluster_num_in_row() + LOG2_N_ROWS;
    if (IMPL == TREE && (total_tree_levels % 2) == 0)
        result_buffer = a_buffer;
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        snrt_dma_start_1d((uintptr_t)output, result_buffer, SIZE);
        snrt_dma_wait_all();
    }
}
