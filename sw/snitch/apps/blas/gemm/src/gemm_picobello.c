// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
//         Luca Bertaccini <lbertaccini@iis.ee.ethz.ch>
//         Luca Colagrande <colluca@iis.ee.ethz.ch>
//         Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include "snrt.h"
#include <stdalign.h>
#include <stdint.h>

#include <math.h>
#include "blas.h"

// #define JOB_ARGS_PRELOADED

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreorder-init-list"
#include "data.h"
#pragma clang diagnostic pop


/**
 * @brief Performs a General Matrix Multiplication (GEMM) operation on a
 *        Snitch-based multiple-cluster architecture with support for
 *        parallelization, tiling, and data movement optimizations.
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
 *    - Performs a logarithmic reduction to combine partial results across
 *      clusters, if `parallelize_k` is enabled.
 *    - Writes the result back to global memory.
 *
 * @note Current implementation assumes that `parallelize_m` and
 *       `parallelize_k` options are mutually exclusive.
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

    // Distribute m and k tiles to clusters
    uint32_t cluster_m_tiles = largs->m_tiles;
    uint32_t cluster_k_tiles = largs->k_tiles;
    if (largs->parallelize_m) cluster_m_tiles /= snrt_cluster_num();
    if (largs->parallelize_k) cluster_k_tiles /= snrt_cluster_num();

    // Calculate number of iterations
    uint32_t num_tiles = cluster_m_tiles * largs->n_tiles * cluster_k_tiles;
    uint32_t num_iters = num_tiles;
    if (largs->double_buffer)
        num_iters += 2;
    else
        num_iters += 1;

    // Iterate over all tiles
    for (uint32_t i = 0; i < num_iters; i++) {
        // Calculate tile indices (we iterate in k->n->m order)
        int dma_in_i = i;
        int comp_i = largs->double_buffer ? i - 1 : i;
        int dma_out_i = largs->double_buffer ? i - 2 : i - 1;
        int dma_in_k = dma_in_i % cluster_k_tiles;
        int dma_in_mn = dma_in_i / cluster_k_tiles;
        int dma_in_n = dma_in_mn % largs->n_tiles;
        int dma_in_m = dma_in_mn / largs->n_tiles;
        int comp_k = comp_i % cluster_k_tiles;
        int comp_mn = comp_i / cluster_k_tiles;
        int comp_n = comp_mn % largs->n_tiles;
        int comp_m = comp_mn / largs->n_tiles;
        int dma_out_k = dma_out_i % cluster_k_tiles;
        int dma_out_mn = dma_out_i / cluster_k_tiles;
        int dma_out_n = dma_out_mn % largs->n_tiles;
        int dma_out_m = dma_out_mn / largs->n_tiles;

        // If m and k tiles are parallelized across clusters,
        // calculate the absolute m and k indices for each cluster
        int dma_in_m_abs = dma_in_m;
        int comp_m_abs = comp_m;
        int dma_out_m_abs = dma_out_m;
        int dma_in_k_abs = dma_in_k;
        int comp_k_abs = comp_k;
        int dma_out_k_abs = dma_out_k;
        if (largs->parallelize_m) {
            dma_in_m_abs += snrt_cluster_idx() * cluster_m_tiles;
            comp_m_abs += snrt_cluster_idx() * cluster_m_tiles;
            dma_out_m_abs += snrt_cluster_idx() * cluster_m_tiles;
        }
        if (largs->parallelize_k) {
            dma_in_k_abs += snrt_cluster_idx() * cluster_k_tiles;
            comp_k_abs += snrt_cluster_idx() * cluster_k_tiles;
            dma_out_k_abs += snrt_cluster_idx() * cluster_k_tiles;
        }

        // DMA out phase
        if (snrt_is_dm_core()) {
            if (dma_out_i >= 0) {
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
                                               dma_out_m_abs, dma_out_n, tile_m,
                                               tile_n, largs->ldc, largs->prec);
                    }
                    snrt_dma_wait_all();
                }
            }
        }

        // DMA in phase
        if (snrt_is_dm_core()) {
            if (dma_in_i < num_tiles) {
                snrt_mcycle();
                // Switch buffers
                // A and B buffers are switched every iteration, while the C
                // buffer only needs to be switched after fully accumulating
                // the result, i.e. after finishing the K loop.
                int buff_idx = largs->double_buffer ? dma_in_i % 2 : 0;
                int c_buff_idx = largs->double_buffer ? dma_in_mn % 2 : 0;

                // Load A
                if (largs->load_a) {
                    if (largs->partition_banks) {
                        snrt_dma_1d_to_2d(
                            la[buff_idx],
                            (void *)((uintptr_t)largs->a +
                                     dma_in_m_abs * tile_a_size),
                            tile_a_size,
                            banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                            SNRT_TCDM_HYPERBANK_WIDTH);
                    } else {
                        snrt_dma_load_2d_tile(
                            la[buff_idx], largs->a, dma_in_m_abs, dma_in_k_abs,
                            tile_m, tile_k, largs->lda, largs->prec);
                    }
                }

                // Load B
                if (largs->load_b) {
                    if (largs->transb) {
                        snrt_dma_load_2d_tile(lb[buff_idx], largs->b, dma_in_n,
                                              dma_in_k_abs, tile_n, tile_k,
                                              largs->ldb, largs->prec);
                    } else {
                        if (largs->partition_banks) {
                            snrt_dma_1d_to_2d(
                                lb[buff_idx],
                                (void *)((uintptr_t)largs->b +
                                         dma_in_k_abs * tile_b_size),
                                tile_b_size,
                                banks_per_buffer * SNRT_TCDM_BANK_WIDTH,
                                SNRT_TCDM_HYPERBANK_WIDTH);
                        } else {
                            if (largs->parallelize_k) {
                                snrt_dma_load_2d_tile(
                                    lb[buff_idx], largs->b, dma_in_k_abs, dma_in_n,
                                    tile_k, tile_n, largs->ldb, largs->prec);
                            } else {
                                // Multicast B to all clusters
                                if (snrt_cluster_idx() == 0) {
                                    // Load B from L2
                                    snrt_dma_load_2d_tile_mcast(
                                    lb[buff_idx], largs->b, dma_in_k_abs, dma_in_n,
                                    tile_k, tile_n, largs->ldb, largs->prec, 0x003C0000);
                                }
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
                                                  dma_in_m_abs, dma_in_n,
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
        if (!largs->double_buffer) snrt_cluster_hw_barrier();

        // Compute phase
        if (comp_i >= 0 && comp_i < num_tiles) {
            // Switch buffers
            int buff_idx = largs->double_buffer ? comp_i % 2 : 0;
            int c_buff_idx = largs->double_buffer ? comp_mn % 2 : 0;

            // Only compute cores participate in the tile computation
            if (!snrt_is_dm_core()) {
                uint32_t start_cycle = snrt_mcycle();

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
                sc_st_args.a = la[buff_idx];
                if (largs->transa) {
                    sc_st_args.lda = tile_m;
                } else if (largs->partition_banks) {
                    sc_st_args.lda = calculate_partitioned_banks_stride(
                        banks_per_buffer, tile_k, largs->prec);
                } else {
                    sc_st_args.lda = tile_k;
                }
                sc_st_args.b = lb[buff_idx];
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

                uint32_t end_cycle = snrt_mcycle();
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
