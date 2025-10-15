// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
//         Luca Bertaccini <lbertaccini@iis.ee.ethz.ch>
//         Luca Colagrande <colluca@iis.ee.ethz.ch>
//         Viviane Potocnik <vivianep@iis.ee.ethz.ch>
//         Lorenzo Leone <lleone@iis.ee.ethz.ch>

#include "snrt.h"

#include "blas.h"

typedef enum {
    SW_NAIVE,
    SW_TREE,
    HW
} mode_t;

#ifndef MODE
#define MODE SW_NAIVE
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreorder-init-list"
#include "data.h"
#pragma clang diagnostic pop

static inline void snrt_dma_load_2d_tile_mcast_sw(
    void *dst, void *src, size_t tile_x1_idx, size_t tile_x0_idx,
    size_t tile_x1_size, size_t tile_x0_size, size_t full_x0_size,
    uint32_t prec, snrt_comm_t comm) {

    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Iteration 0: cluster in row 0 fetches data from memory tile
    if (pb_cluster_row_idx() == 0) {
        snrt_dma_load_2d_tile(
            dst, src, tile_x1_idx, tile_x0_idx,
            tile_x1_size, tile_x0_size, full_x0_size,
            prec);
        snrt_dma_wait_all();
    }

    // Iterations to cover all transfers in each column
    uint32_t n_levels_in_col = PB_LOG2_CLUSTER_PER_COL;
    uint32_t size = tile_x1_size * tile_x0_size * prec;
    for (uint32_t i = 0; i < n_levels_in_col; i++) {

        // Determine which clusters are senders at every level of the tree
        char row_idx_inv = pb_cluster_num_in_col() - pb_cluster_row_idx();
        char num_active_rows = 1 << i;
        char sender_stride = pb_cluster_num_in_col() / num_active_rows;
        char is_sender = (row_idx_inv % sender_stride) == 0;

        // Every active cluster sends the data to a cluster above it
        if (is_sender) {

            // Calculate destination 
            char receiver_offset = sender_stride / 2;
            uintptr_t dst_cluster = pb_calculate_cluster_idx(
                pb_cluster_row_idx() + receiver_offset, pb_cluster_col_idx());
            void *remote_dst = snrt_remote_l1_ptr((void *)dst,
                snrt_cluster_idx(), dst_cluster);

            snrt_mcycle();

            // Start DMA
            snrt_dma_start_1d(remote_dst, dst, size);    

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

/**
 * @brief Performs a General Matrix Multiplication (GEMM) operation on a
 *        Snitch-based multiple-cluster architecture with a 2D mesh topology
 *        using the SUMMA dataflow.
 *
 * @param args Pointer to a `gemm_args_t` structure containing arguments
 *             for the GEMM operation.
 *
 * @details
 * The function performs the following steps:
 * 1. Copies the input arguments to local memory for faster access.
 * 2. Calculates tile sizes based on the input dimensions and number of tiles.
 * 3. Allocates space in TCDM for local copies of matrix tiles, unless
 *    matrix tiles are already stored in TCDM (see `load_* arguments`).
 * 4. Distributes tiles to clusters for parallel processing.
 * 5. Iterates over the tiles, performing the following:
 *    - Copies data for the current tile into local memory.
 *    - Performs the tile computation using the `sc_st_gemm` function.
 *    - Writes the result back to global memory.
 */
static inline int gemm_picobello(const gemm_args_t *args) {
#ifndef JOB_ARGS_PRELOADED
    // Copy the arguments to local memory
    gemm_args_t *largs = (gemm_args_t *)snrt_l1_alloc_cluster_local(
        sizeof(gemm_args_t), alignof(gemm_args_t));
    if (snrt_is_dm_core()) {
        snrt_dma_start_1d((void *)largs, (void *)args, sizeof(gemm_args_t));
        snrt_dma_wait_all();
    }
    snrt_cluster_hw_barrier();
#else
    const gemm_args_t *largs = args;
#endif

    // Create a communicator for each column to share the B tiles
    snrt_comm_t col_comm[pb_cluster_num_in_row()];
	for (uint32_t c = 0; c < pb_cluster_num_in_row(); c++)
		pb_create_mesh_comm(&col_comm[c], pb_cluster_num_in_col(), 1,
			0, c);

    // Calculate tile sizes
    uint32_t tile_m = largs->m / largs->m_tiles;
    uint32_t tile_n = largs->n / largs->n_tiles;
    uint32_t tile_k = largs->k / largs->k_tiles;
    uint32_t tile_a_size = tile_m * tile_k * largs->prec;
    uint32_t tile_b_size = tile_k * tile_n * largs->prec;
    uint32_t tile_c_size = tile_m * tile_n * largs->prec;

    // Allocate space for local tile buffers in TCDM, unless preloaded
    void *a0, *a1, *b0, *b1, *c0, *c1;
    void *la[2], *lb[2], *lc[2], *lcr;
    int banks_per_buffer = snrt_cluster_compute_core_num();
    allocate_buffers(tile_a_size, tile_b_size, tile_c_size, largs,
                     banks_per_buffer, la, lb, lc, &lcr);
    if (snrt_cluster_core_idx() == 0) {
        DUMP(la[0]);
        DUMP(la[1]);
        DUMP(lb[0]);
        DUMP(lb[1]);
        DUMP(lc[0]);
        DUMP(lc[1]);
    }
    snrt_cluster_hw_barrier();

    // NoC layout (6 columns x 4 rows)
    /*
    //
     |------|   |------|   |------|   |------|   |------|   |------|
     |  M3  |---|  C3  |---|  C7  |---| C11  |---| C15  |---|  M7  |
     |------|   |------|   |------|   |------|   |------|   |------|
        |           |          |          |          |          |
        |           |          |          |          |          |
     |------|   |------|   |------|   |------|   |------|   |------|
     |  M2  |---|  C2  |---|  C6  |---| C10  |---| C14  |---|  M6  |
     |------|   |------|   |------|   |------|   |------|   |------|
        |           |          |          |          |          |
        |           |          |          |          |          |
     |------|   |------|   |------|   |------|   |------|   |------|
     |  M1  |---|  C1  |---|  C5  |---|  C9  |---| C13  |---|  M5  |
     |------|   |------|   |------|   |------|   |------|   |------|
        |           |          |          |          |          |
        |           |          |          |          |          |
     |------|   |------|   |------|   |------|   |------|   |------|
     |  M0  |---|  C0  |---|  C4  |---|  C8  |---| C12  |---|  M4  |
     |------|   |------|   |------|   |------|   |------|   |------|
    //
    */

    // SUMMA dataflow:
    // - Clusters in the same row calculate different tiles of the same
    //   row block of C, reusing the same row block of A but different column
    //   blocks of B.
    // - Clusters in the same column calculate different tiles of the same
    //   column block of C, reusing the same column block of B but different
    //   row blocks of A.
    //
    // Notes:
    // - K tiling not supported.

    // Distribute m tiles to cluster rows and n tiles to cluster columns
    uint32_t cluster_m_tiles = largs->m_tiles / pb_cluster_num_in_col();
    uint32_t cluster_n_tiles = largs->n_tiles / pb_cluster_num_in_row();
    uint32_t cluster_k_tiles = 1;

    // Calculate number of iterations
    uint32_t num_tiles = cluster_m_tiles * cluster_n_tiles * cluster_k_tiles;
    uint32_t num_iters = num_tiles;
    if (largs->double_buffer)
        num_iters += 2;
    else
        num_iters += 1;

    // Iterate over all tiles
    for (uint32_t i = 0; i < num_iters; i++) {
        // Calculate tile indices (we iterate in n->m order)
        int dma_in_i = i;
        int comp_i = largs->double_buffer ? i - 1 : i;
        int dma_out_i = largs->double_buffer ? i - 2 : i - 1;
        int dma_in_k = dma_in_i % cluster_k_tiles;
        int dma_in_mn = dma_in_i / cluster_k_tiles;
        int dma_in_n = dma_in_mn % cluster_n_tiles;
        int dma_in_m = dma_in_mn / cluster_n_tiles;
        int comp_k = comp_i % cluster_k_tiles;
        int comp_mn = comp_i / cluster_k_tiles;
        int comp_n = comp_mn % cluster_n_tiles;
        int comp_m = comp_mn / cluster_n_tiles;
        int dma_out_k = dma_out_i % cluster_k_tiles;
        int dma_out_mn = dma_out_i / cluster_k_tiles;
        int dma_out_n = dma_out_mn % cluster_n_tiles;
        int dma_out_m = dma_out_mn / cluster_n_tiles;

        // Calculate the absolute m, n and k indices for each cluster
        int dma_in_m_abs = dma_in_m + pb_cluster_row_idx() * cluster_m_tiles;
        int comp_m_abs = comp_m + pb_cluster_row_idx() * cluster_m_tiles;
        int dma_out_m_abs = dma_out_m + pb_cluster_row_idx() * cluster_m_tiles;
        int dma_in_n_abs = dma_in_n + pb_cluster_col_idx() * cluster_n_tiles;
        int comp_n_abs = comp_n + pb_cluster_col_idx() * cluster_n_tiles;
        int dma_out_n_abs = dma_out_n + pb_cluster_col_idx() * cluster_n_tiles;
        int dma_in_k_abs = dma_in_k;
        int comp_k_abs = comp_k;
        int dma_out_k_abs = dma_out_k;

        // DMA out phase
        if (snrt_is_dm_core()) {
            if (dma_out_i >= 0) {
                snrt_mcycle();
                // Switch buffers
                int buff_idx = largs->double_buffer ? dma_out_mn % 2 : 0;

                // Store C
                // If parallelize_k, then only cluster 0 must writeback
                if ((snrt_cluster_idx() == 0) || !(largs->parallelize_k)) {
                    if (largs->partition_banks) {
                        snrt_dma_2d_to_1d(
                            (void *)((uintptr_t)largs->c +
                                     dma_out_m_abs * tile_c_size),
                            lc[buff_idx], tile_c_size,
                            banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                            SNRT_TCDM_HYPERBANK_WIDTH);
                    } else {
                        snrt_dma_store_2d_tile(largs->c, lc[buff_idx],
                                               dma_out_m_abs, dma_out_n_abs, tile_m,
                                               tile_n, largs->ldc, largs->prec);
                    }
                    snrt_dma_wait_all();
                }
                snrt_mcycle();
            }
        }

        // DMA in phase
        if (snrt_is_dm_core()) {
            if (dma_in_i < num_tiles) {
                snrt_mcycle();
                // Switch buffers
                // When tiling on N, a row block of A is reused with multiple
                // column blocks of B. There is no need to reload A on every
                // iteration. The A buffer must be switched only when reloading
                // A. On the other hand, the B buffer is switched every
                // iteration, and the C buffer only needs to be switched after
                // fully accumulating the result, i.e. after finishing the K loop.
                int a_buff_idx = largs->double_buffer ? dma_in_m % 2 : 0;
                int b_buff_idx = largs->double_buffer ? dma_in_i % 2 : 0;
                int c_buff_idx = largs->double_buffer ? dma_in_mn % 2 : 0;

                // Load A
                if (largs->load_a && (dma_in_n == 0)) {
                    if (largs->partition_banks) {
                        snrt_dma_1d_to_2d(
                            la[a_buff_idx],
                            (void *)((uintptr_t)largs->a +
                                     dma_in_m_abs * tile_a_size),
                            tile_a_size,
                            banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                            SNRT_TCDM_HYPERBANK_WIDTH);
                    } else {
                        snrt_dma_load_2d_tile(
                            la[a_buff_idx], largs->a, dma_in_m_abs, dma_in_k_abs,
                            tile_m, tile_k, largs->lda, largs->prec);
                    }
                }

                // Load B
                if (largs->load_b) {
                    if (largs->transb) {
                        snrt_dma_load_2d_tile(lb[b_buff_idx], largs->b,
                                              dma_in_n_abs, dma_in_k_abs,
                                              tile_n, tile_k,
                                              largs->ldb, largs->prec);
                    } else {
                        if (largs->partition_banks) {
                            snrt_dma_1d_to_2d(
                                lb[b_buff_idx],
                                (void *)((uintptr_t)largs->b +
                                         dma_in_k_abs * tile_b_size),
                                tile_b_size,
                                banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                                SNRT_TCDM_HYPERBANK_WIDTH);
                        } else {
                            // In SW_NAIVE mode, every cluster fetches the B
                            // tile it requires, independently. In all other
                            // modes, the clusters in row 0 multicast the B
                            // tile to all clusters in the same column.
                            if (MODE == HW) {
                                if (pb_cluster_row_idx() == 0) {
                                    snrt_dma_load_2d_tile_mcast(
                                        lb[b_buff_idx], largs->b, dma_in_k_abs,
                                        dma_in_n_abs, tile_k, tile_n,
                                        largs->ldb, largs->prec,
                                        col_comm[pb_cluster_col_idx()]);
                                }
                            } else if (MODE == SW_TREE) {
                                snrt_dma_load_2d_tile_mcast_sw(
                                    lb[b_buff_idx], largs->b, dma_in_k_abs,
                                    dma_in_n_abs, tile_k, tile_n,
                                    largs->ldb, largs->prec,
                                    col_comm[pb_cluster_col_idx()]);                            
                            } else {
                                snrt_dma_load_2d_tile(
                                    lb[b_buff_idx], largs->b, dma_in_k_abs,
                                    dma_in_n_abs, tile_k, tile_n, largs->ldb,
                                    largs->prec);
                            }
                        }
                    }
                }

                // Load C
                // C tile is loaded only upon the first k iteration, then
                // the C array will contain the partial results from the
                // previous iteration
                if (largs->load_c) {
                    if (dma_in_k_abs == 0) {
                        if (largs->partition_banks) {
                            snrt_dma_1d_to_2d(
                                lc[c_buff_idx],
                                (void *)((uintptr_t)largs->c +
                                         dma_in_m_abs * tile_c_size),
                                tile_c_size,
                                banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                                SNRT_TCDM_HYPERBANK_WIDTH);
                        } else {
                            snrt_dma_load_2d_tile(lc[c_buff_idx], largs->c,
                                                  dma_in_m_abs, dma_in_n_abs,
                                                  tile_m, tile_n, largs->ldc,
                                                  largs->prec);
                        }
                    } else if (dma_in_k == 0) {
                        // Clusters other than the first need to initialize
                        // the C array to zero in their first iteration
                        if (largs->partition_banks) {
                            snrt_dma_1d_to_2d(
                                lc[c_buff_idx], snrt_cluster()->zeromem.mem,
                                tile_c_size,
                                banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                                SNRT_TCDM_HYPERBANK_WIDTH);
                        } else {
                            snrt_dma_start_1d(lc[c_buff_idx],
                                              snrt_cluster()->zeromem.mem,
                                              tile_c_size);
                        }
                    }
                }
                snrt_dma_wait_all();
                snrt_mcycle();
            }
        }

        // Additional barrier required when not double buffering
        if (!largs->double_buffer) snrt_global_barrier();

        // Compute phase
        if (comp_i >= 0 && comp_i < num_tiles) {
            // Switch buffers
            int a_buff_idx = largs->double_buffer ? comp_m % 2 : 0;
            int b_buff_idx = largs->double_buffer ? comp_i % 2 : 0;
            int c_buff_idx = largs->double_buffer ? comp_mn % 2 : 0;

            // Only compute cores participate in the tile computation
            if (!snrt_is_dm_core()) {
                // uint32_t start_cycle = snrt_mcycle();

                // In the first k iteration we accumulate with the C matrix
                // scaled by beta, in successive iterations we accumulate
                // the previous partial result. The tile-level beta is thus
                // a function of k: beta(k).
                uint32_t beta_k = comp_k_abs == 0 ? largs->beta : 1;

                // Tile computation
                sc_st_gemm_args_t sc_st_args;
                sc_st_args.prec = largs->prec;
                sc_st_args.setup_ssr = largs->setup_ssr;
                sc_st_args.partition_banks = largs->partition_banks;
                sc_st_args.transa = largs->transa;
                sc_st_args.transb = largs->transb;
                sc_st_args.a = la[a_buff_idx];
                if (largs->transa) {
                    sc_st_args.lda = tile_m;
                } else if (largs->partition_banks) {
                    sc_st_args.lda = calculate_partitioned_banks_stride(
                        banks_per_buffer, tile_k, largs->prec);
                } else {
                    sc_st_args.lda = tile_k;
                }
                sc_st_args.b = lb[b_buff_idx];
                if (largs->transb) {
                    sc_st_args.ldb = tile_k;
                } else if (largs->partition_banks) {
                    sc_st_args.ldb = calculate_partitioned_banks_stride(
                        banks_per_buffer, tile_n, largs->prec);
                } else {
                    sc_st_args.ldb = tile_n;
                }
                sc_st_args.beta = beta_k;
                sc_st_args.c = lc[c_buff_idx];
                if (largs->partition_banks) {
                    sc_st_args.ldc = calculate_partitioned_banks_stride(
                        banks_per_buffer, tile_n, largs->prec);
                } else {
                    sc_st_args.ldc = tile_n;
                }
                sc_st_args.m = tile_m;
                sc_st_args.n = tile_n;
                sc_st_args.k = tile_k;
                sc_st_gemm(largs->gemm_fp, &sc_st_args);

                // uint32_t end_cycle = snrt_mcycle();
            }

            // Add the partial result tiles from the various clusters together
            // in a logarithmic reduction fashion.
            // Note: both compute and DMA cores participate in this step.
            if (largs->parallelize_k && (comp_k == (cluster_k_tiles - 1))) {
                snrt_global_reduction_dma(
                    (double *)lcr, (double *)lc[c_buff_idx], tile_m * tile_n);
            }
        }

        // Synchronize cores after every iteration
        snrt_global_barrier();
    }

    return 0;
}


int main () {
    gemm_picobello(&args);
    return 0;
}
