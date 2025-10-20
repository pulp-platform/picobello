// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chen Wu <chenwu@iis.ee.ethz.ch>
// Raphael Roth <raroth@student.ethz.ch>
// Luca Colagrande <colluca@iis.ee.ethz.ch>

#define SNRT_ENABLE_NARROW_REDUCTION
#define SNRT_ENABLE_NARROW_MULTICAST

#include <stdint.h>
#include "snrt.h"

// Transfer size in bytes
#ifndef SIZE
#define SIZE 512
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
// Number of elements (type double) that each core needs to reduce for each batch
#define DATA_PER_SSR (BATCH / snrt_cluster_compute_core_num() / sizeof(double))

#ifndef LOG2_N_ROWS
#define LOG2_N_ROWS 0
#endif

#define N_ROWS (1 << LOG2_N_ROWS)

static inline uint32_t pb_cluster_is_easternmost(uint32_t cluster_idx) {
    return pb_cluster_col_idx(cluster_idx) == (pb_cluster_num_in_row() - 1);
}

/**
 * @brief Reduces one chunk of data with all 8 cores in the target cluster
 * @param ptrDataSrc1 ptr to the first source location
 * @param ptrDataSrc2 ptr to the second source location
 * @param ptrDataDst  ptr to the destination
 */
static inline void cluster_reduce_array_slice(double * ptrDataSrc1, double * ptrDataSrc2, double * ptrDataDst) {
    // We want that core 0 works on the 0, 8, 16, 24, ... element
    int offset = snrt_cluster_core_idx();

    // Configure the SSR
    snrt_ssr_loop_1d(SNRT_SSR_DM_ALL, DATA_PER_SSR, snrt_cluster_compute_core_num() * sizeof(double));
    snrt_ssr_read(SNRT_SSR_DM0, SNRT_SSR_1D, ptrDataSrc1 + offset);
    snrt_ssr_read(SNRT_SSR_DM1, SNRT_SSR_1D, ptrDataSrc2 + offset);
    snrt_ssr_write(SNRT_SSR_DM2, SNRT_SSR_1D, ptrDataDst + offset);
    snrt_ssr_enable();

    asm volatile(
        "frep.o %[n_frep], 1, 0, 0 \n"
        "fadd.d ft2, ft0, ft1\n"
        :
        : [ n_frep ] "r"(DATA_PER_SSR - 1)
        : "ft0", "ft1", "ft2", "memory");

    snrt_fpu_fence();
    snrt_ssr_disable();
}


/**
 * @brief Perform a sequential DMA-based reduction across clusters in a mesh
 * @param buffer_src: buffer containing local data batch to be reduced
 * @param buffer_res: buffer to store the reduced data batch
 * @param buffer_tmp: temporary storage for reduction intermidiate result
 * @param buffer_coming: buffer to receive data from other clusters
 */
static inline void dma_reduction_sequential(uintptr_t buffer_src, uintptr_t buffer_res, uintptr_t buffer_tmp, uintptr_t buffer_coming, snrt_comm_t comm) {
    if (!comm->is_participant) return;

    uint32_t cluster_idx = snrt_cluster_idx();
    uint32_t col_idx = pb_cluster_col_idx(cluster_idx);

    uintptr_t coming[2] = {
        buffer_coming,
        buffer_coming + 2 * BATCH
    };

    // Compute destination address of the dma transfer
    // - TODO: clusters with col idx 0 send reduced data to coming[1] in its south neighbour
    // - others send reduced data to coming[0] in its west neighbour
    uintptr_t dma_dst_base, dma_dst;
    dma_dst_base = (uintptr_t)snrt_remote_l1_ptr((void *)coming[0], cluster_idx, pb_cluster_west_neighbour());
    dma_dst = dma_dst_base;

    // Compute source address of the dma transfer
    // - easternmost clusters send data in buffer_src to the dst
    // - other clusters send data in buffer_res to the src (reduced data from previous step)
    uintptr_t dma_src;
    if (pb_cluster_is_easternmost(cluster_idx)) {
        dma_src = buffer_src;
    } else {
        dma_src = buffer_res;
    }

    // Pointer of local data to be reduced
    uintptr_t compute_src = buffer_src;
    // Pointer of reduced data
    uintptr_t compute_res = buffer_res;
    uintptr_t compute_src2_base, compute_src2;
    uintptr_t compute_src3_base, compute_src3;
    compute_src2_base = coming[0];
    compute_src3_base = coming[1];
    compute_src2 = compute_src2_base;
    compute_src3 = compute_src3_base;

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iterations to cover all reductions in a row
    uint32_t n_iters = N_BATCHES + 1 + pb_cluster_num_in_row();
    for (uint32_t i = 0; i < n_iters; i++) {
        char dma_active = i >= (2 * pb_cluster_num_in_row() - 2 - 2 * col_idx);
        dma_active &= i < (2 * pb_cluster_num_in_row() - 2 - 2 * col_idx + N_BATCHES);
        dma_active &= !pb_cluster_in_col(0);

        char compute_active = i >= (2 * pb_cluster_num_in_row() - 3 - 2 * col_idx);
        compute_active &= i < (2 * pb_cluster_num_in_row() - 3 - 2 * col_idx + N_BATCHES);
        compute_active &= !pb_cluster_is_easternmost(cluster_idx);

        if (compute_active && snrt_is_compute_core()) {
            // if(snrt_cluster_core_idx()==0) {DUMP(2222);DUMP(compute_src); DUMP(compute_src2); DUMP(compute_res);}
            snrt_mcycle();
            cluster_reduce_array_slice(
                (double *)compute_src, // source 1
                (double *)compute_src2, // source 2
                (double *)compute_res  // destination
            );
            compute_src += BATCH;
            compute_src2 = compute_src2_base + ((i & 1) ? BATCH : 0);
            compute_res += BATCH;
            asm volatile ("" : "+r"(compute_src), "+r"(compute_src2), "+r"(compute_res) ::);
            snrt_mcycle();
        }

        if (dma_active && snrt_is_dm_core()) {
            // Start DMA
            // {DUMP(3333); DUMP(dma_src); DUMP(dma_dst);DUMP(i);}
            snrt_mcycle();
            snrt_dma_start_1d(dma_dst, dma_src, BATCH);

            // Update pointers for next iteration while transfer completes,
            // preventing instructions from being reordered after the DMA wait
            dma_src += BATCH;
            dma_dst = dma_dst_base + ((i & 1) ? 0 : BATCH);
            asm volatile ("" : "+r"(dma_src), "+r"(dma_dst) ::);

            // Wait for DMA to complete
            snrt_dma_wait_all();
            snrt_mcycle();
        }

        // Perform inter-cluster barrier. Disable reduction before the fence
        // so it overlaps with the latency of the ongoing reduction operation.
        // snrt_set_awuser_low(user);
        // *barrier_ptr = 1;
        // snrt_set_awuser_low(0);
        // snrt_fence();
        snrt_global_barrier(comm);
    }

}

// Global variables for verification script
double output[N_ELEMS];
extern const uint32_t length = N_ELEMS;
extern const uint32_t n_rows = N_ROWS;
extern const uint32_t n_clusters_per_row = pb_cluster_num_in_row();
extern const uint32_t n_clusters_per_col = pb_cluster_num_in_col();

int main() {
    double *buffer_src = (double*) snrt_l1_alloc_cluster_local(SIZE, 4096);
    double *buffer_dst = (double*) snrt_l1_alloc_cluster_local(SIZE, 4096);
    // Temporary storage for reduction intermidiate result, at most 1 batch of intermediate result
    double *buffer_tmp = (double*) snrt_l1_alloc_cluster_local(BATCH, sizeof(double));
    // Buffer to receive data from other clusters, at most 2 batches coming from other clusters
    double *buffer_coming = (double*) snrt_l1_alloc_cluster_local(2*BATCH, sizeof(double));

    // Initialize source buffer containing data to be reduced in each cluster
    uint32_t cluster_id = snrt_cluster_idx();
    double init_data = 15.0 + (double) cluster_id;

    if (snrt_is_dm_core()) {
        for (uint32_t i = 0; i < N_ELEMS; i++) {
            buffer_src[i] = init_data + (double) i;
        }
    }

    // Initialize destination buffer to zero
    if (snrt_is_dm_core()) {
        snrt_dma_start_1d(
            (uintptr_t)buffer_dst, (uintptr_t)(snrt_cluster()->zeromem.mem), SIZE);
        snrt_dma_wait_all();
    }

    // Create communicator for first N rows (all other clusters are inactive)
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, N_ROWS, pb_cluster_num_in_row());

    // Only DMA cores of clusters in the first N rows continue from here
    if (!comm->is_participant) return 0;

    // Print participating clusters
    if (snrt_is_dm_core() && snrt_cluster_idx() == 0) {
        uint32_t mask = comm->mask;
        uint32_t fixed = comm->base & ~mask;
        uint32_t submask = 0;
        do {
            uint32_t i = fixed | submask;
            // DUMP(i);
            submask = (submask - 1) & mask;
        } while (submask != 0);
    }

    // Synchronize all clusters.
    snrt_inter_cluster_barrier(comm);

    // Initiate reduction (twice to preheat the cache)
    for (volatile int i = 0; i < 2; i++) {
        snrt_mcycle();
        // TODO: dma_reduction
        dma_reduction_sequential(
            (uintptr_t)buffer_src,
            (uintptr_t)buffer_dst,
            (uintptr_t)buffer_tmp,
            (uintptr_t)buffer_coming,
            comm);
        snrt_mcycle();
        snrt_inter_cluster_barrier(comm);
    }

    // Writeback to L3
    if (snrt_is_dm_core() && cluster_id == 0) {
        snrt_dma_start_1d(
            (uintptr_t)output, (uintptr_t)buffer_dst, SIZE);
        snrt_dma_wait_all();
    }
}