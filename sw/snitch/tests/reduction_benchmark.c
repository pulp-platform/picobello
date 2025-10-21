// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>
// Chen Wu <chenwu@iis.ee.ethz.ch>

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
    HW_GENERIC,
    HW_SIMPLE,
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

static inline void dma_reduction_hw_generic(uintptr_t src, uintptr_t dst,
    snrt_comm_t comm) {
    if (snrt_is_dm_core() && comm->is_participant) {
        uintptr_t remote_dst = (uintptr_t)snrt_remote_l1_ptr(
            (void *)dst, snrt_cluster_idx(), 0);
        snrt_collective_opcode_t op = SNRT_REDUCTION_FADD;
        snrt_dma_start_1d_reduction(remote_dst, src, SIZE, comm, op);
        snrt_dma_wait_all();
    }
}

static inline void dma_reduction_hw_simple(uintptr_t src, uintptr_t dst,
    snrt_comm_t comm) {

    // Create a communicator per row
    snrt_comm_t row_comm[N_ROWS];
    for (int i = 0; i < N_ROWS; i++)
        pb_create_mesh_comm(&row_comm[i], 1, pb_cluster_num_in_row(), i, 0,
            comm);

    // Create a communicator for the first column
    snrt_comm_t col_comm;
    pb_create_mesh_comm(&col_comm, N_ROWS, 1, 0, 0, comm);

    if (snrt_is_dm_core() && comm->is_participant) {
        uint32_t remote_cluster;
        uintptr_t remote_dst;
        snrt_collective_opcode_t op = SNRT_REDUCTION_FADD;

        // Reduction across rows (destination: first cluster in row)
        snrt_mcycle();
        remote_cluster = pb_calculate_cluster_idx(pb_cluster_row_idx(), 0);
        remote_dst = (uintptr_t)snrt_remote_l1_ptr(
            (void *)dst, snrt_cluster_idx(), remote_cluster);
        snrt_dma_start_1d_reduction(
            remote_dst, src, SIZE, row_comm[pb_cluster_row_idx()], op);
        snrt_dma_wait_all();
        snrt_mcycle();

        // Barrier to ensure there is only one outstanding reduction in every
        // router
        snrt_inter_cluster_barrier(comm);

        // Reduction across first column (destination: cluster 0)
        snrt_mcycle();
        if (N_ROWS > 1 && col_comm->is_participant) {
            // Switch source and destination buffer
            remote_dst = (uintptr_t)snrt_remote_l1_ptr(
                (void *)src, snrt_cluster_idx(), 0);
            snrt_dma_start_1d_reduction(remote_dst, dst, SIZE, col_comm, op);
            snrt_dma_wait_all();
        }
        snrt_mcycle();
    }
}

// We need four buffers. Upon function invocation, the data must be in a.
static inline void dma_reduction_seq(uintptr_t a, uintptr_t b, uintptr_t c,
    uintptr_t d, snrt_comm_t comm) {
    if (!comm->is_participant) return;

    uint32_t col_idx = pb_cluster_col_idx();
    uint32_t row_idx = pb_cluster_row_idx();
    uintptr_t is_northernmost = pb_cluster_in_row(N_ROWS - 1);

    // Group to simplify rotating buffers
    uintptr_t dst[2] = {b, d};

    if (snrt_cluster_idx() == 0 && snrt_cluster_core_idx() == 0) {
        DUMP(a);
        DUMP(b);
        DUMP(c);
        DUMP(d);
    }

    // Compute addresses of source and destination data for DMA cores.
    // All clusters in col > 0 participate in the row reduction. For this
    // reduction the source is in `a` and the result in `c`.
    // Only the easternmost clusters send their input data (in `a`) to their
    // west neighbours, all other clusters send the data they reduced in the
    // previous step (in `c`).
    // Clusters in col == 0 participate in the column reduction. For this
    // reduction the source is in `c` and the result in `a`.
    // Only the northernmost cluster sends the source data (in `c`) to its
    // south neighbour, all other clusters send the data they reduced in the
    // previous step (in `a`).
    uintptr_t dma_src, dma_dst;
    if (pb_cluster_is_easternmost() || (col_idx == 0 && !is_northernmost)) {
        dma_src = a;
    } else {
        dma_src = c;
    }
    // Clusters in col > 0, participating in row reduction, send to west
    // neighbours. Clusters in col == 0, participating in column reduction,
    // send to south neighbours.
    uint32_t dst_cluster = col_idx > 0 ? pb_cluster_west_neighbour() :
        pb_cluster_south_neighbour();
    dma_dst = (uintptr_t)snrt_remote_l1_ptr((void *)dst[0],
        snrt_cluster_idx(), dst_cluster);

    // Compute addresses of source and result data for compute cores
    uintptr_t comp_src1, comp_src2, comp_result;
    comp_src1 = a;
    comp_src2 = dst[0];
    comp_result = c;

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iterations to cover all reductions in a row
    uint32_t n_iters = 1 + 2 * (pb_cluster_num_in_row() - 2) + N_BATCHES;
    for (uint32_t i = 0; i < n_iters; i++) {

        uint32_t col_idx_inv, base_iter;
        char dma_active, compute_active;

        // Determine which clusters need to send data at every iteration
        col_idx_inv = pb_cluster_num_in_row() - col_idx - 1;
        base_iter = 2 * col_idx_inv;
        dma_active = (i >= base_iter) && (i < (base_iter + N_BATCHES));
        dma_active &= !pb_cluster_in_col(0);

        // Determine which clusters need to reduce data at every iteration
        base_iter = 1 + 2 * (col_idx_inv - 1);
        compute_active = (i >= base_iter) && (i < (base_iter + N_BATCHES));
        compute_active &= !pb_cluster_is_easternmost();

        if (compute_active && snrt_is_compute_core()) {
            snrt_mcycle();
            axpy_opt(N_ELEMS / N_BATCHES, one, (double *)comp_src1,
                (double *)comp_src2, (double *)comp_result);
            comp_src1 += BATCH;
            swap_buffers(&dst[0], &dst[1]);
            comp_src2 = dst[0];
            comp_result += BATCH;
            snrt_mcycle();
        }

        if (dma_active && snrt_is_dm_core()) {

            // Start DMA
            snrt_mcycle();
            snrt_dma_start_1d(dma_dst, dma_src, BATCH);

            // Update pointers for next iteration while transfer completes,
            // preventing instructions from being reordered after the DMA wait
            dma_src += BATCH;
            swap_buffers(&dst[0], &dst[1]);
            dma_dst = (uintptr_t)snrt_remote_l1_ptr((void *)dst[0],
                snrt_cluster_idx(), pb_cluster_west_neighbour());
            asm volatile ("" : "+r"(dma_src), "+r"(dma_dst) ::);

            // Wait for DMA to complete
            snrt_dma_wait_all();
            snrt_mcycle();
        }

        global_hw_barrier(barrier_ptr, user);
    }

    // Final column reduction is performed only if there is more than one row
    if (N_ROWS > 1) {

        dst[0] = b;
        dst[1] = d;
        comp_src1 = c;
        comp_src2 = dst[0];
        comp_result = a;
        
        // Iterations to cover all reductions in the first column
        n_iters = 1 + 2 * (N_ROWS - 2) + N_BATCHES;
        for (uint32_t i = 0; i < n_iters; i++) {

            uint32_t row_idx_inv, base_iter;
            char dma_active, compute_active;
    
            // Determine which clusters need to send data at every iteration
            row_idx_inv = N_ROWS - row_idx - 1;
            base_iter = 2 * row_idx_inv;
            dma_active = (i >= base_iter) && (i < (base_iter + N_BATCHES));
            dma_active &= pb_cluster_in_col(0);
            dma_active &= snrt_cluster_idx() != 0;

            // Determine which clusters need to reduce data at every iteration
            base_iter = 1 + 2 * (row_idx_inv - 1);
            compute_active = (i >= base_iter) && (i < (base_iter + N_BATCHES));
            compute_active &= pb_cluster_in_col(0);
            compute_active &= !is_northernmost;

            if (compute_active && snrt_is_compute_core()) {
                snrt_mcycle();
                axpy_opt(N_ELEMS / N_BATCHES, one, (double *)comp_src1,
                    (double *)comp_src2, (double *)comp_result);
                comp_src1 += BATCH;
                swap_buffers(&dst[0], &dst[1]);
                comp_src2 = dst[0];
                comp_result += BATCH;
                snrt_mcycle();
            }

            if (dma_active && snrt_is_dm_core()) {
                // Start DMA
                snrt_mcycle();
                snrt_dma_start_1d(dma_dst, dma_src, BATCH);

                // Update pointers for next iteration while transfer completes,
                // preventing instructions from being reordered after the DMA wait
                dma_src += BATCH;
                swap_buffers(&dst[0], &dst[1]);
                dma_dst = (uintptr_t)snrt_remote_l1_ptr((void *)dst[0],
                    snrt_cluster_idx(), pb_cluster_south_neighbour());
                asm volatile ("" : "+r"(dma_src), "+r"(dma_dst) ::);

                // Wait for DMA to complete
                snrt_dma_wait_all();
                snrt_mcycle();
            }

            global_hw_barrier(barrier_ptr, user);
        }
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
        axpy_opt(N_ELEMS / N_BATCHES, one, (double *)src, (double *)dst,
            (double *)result);
        snrt_mcycle();
    }
    snrt_cluster_hw_barrier();
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

        // Determine which clusters are senders and receivers at every level
        // of the tree
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
        dma_reduction_seq(a, b, c, d, comm);
    else if (IMPL == TREE)
        dma_reduction_tree(a, b, c, d, comm);
    else if (IMPL == HW_GENERIC)
        dma_reduction_hw_generic(a, c, comm);
    else if (IMPL == HW_SIMPLE)
        dma_reduction_hw_simple(a, c, comm);
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
    if ((IMPL == HW_SIMPLE && N_ROWS > 1) ||
        (IMPL == SEQ && N_ROWS > 1) ||
        (IMPL == TREE && (total_tree_levels % 2) == 0))
        result_buffer = a_buffer;
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        snrt_dma_start_1d((uintptr_t)output, result_buffer, SIZE);
        snrt_dma_wait_all();
    }
}
