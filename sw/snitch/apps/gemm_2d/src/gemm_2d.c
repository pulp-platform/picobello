// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
//         Luca Bertaccini <lbertaccini@iis.ee.ethz.ch>
//         Luca Colagrande <colluca@iis.ee.ethz.ch>
//         Viviane Potocnik <vivianep@iis.ee.ethz.ch>
//         Lorenzo leone <lleone@iis.ee.ethz.ch>

// TODO (lleone): LIMITATIONS
//
// - Works only when M_tile = snrt_cluster_num()
// - Works only if parallelized on M

#include "snrt.h"
#include <stdalign.h>
#include <stdint.h>

#include <math.h>
#include "blas.h"

#define HW_MCAST

#define L3_START_ADDRESS    0x70000000UL    // Base address of memory tile 0
#define L3_SIZE             0x100000UL      // Size of memory tile (1MiB)
#define NUM_L3_TILES        8               // Number of memory tiles

// #define JOB_ARGS_PRELOADED

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreorder-init-list"
#include "data.h"
#pragma clang diagnostic pop

/*------------------------- NoC Helper functions ---------------------------*/
static inline uintptr_t l3_tile_address(uint32_t tile_idx) {
    return (uintptr_t)L3_START_ADDRESS +
           (uintptr_t)tile_idx * (uintptr_t)L3_SIZE;
}

static inline uintptr_t l3_tile_offset(uintptr_t src_addr) {
    return (src_addr - (uintptr_t)L3_START_ADDRESS) & (uintptr_t)(L3_SIZE - 1);
}

static inline uint32_t cluster_row(uint32_t cid) { return cid % 4u; }

static inline uint32_t dst_tile_for_cluster(uint32_t cid) {
    uint32_t row = cluster_row(cid);
    return (cid < 8u) ? row        // first 8 clusters -> left column tiles 0..3
                      : (row + 4u); // clusters >= 8  -> right column tiles 4..7
}

// Allocate data in L3 to betetr map kernel in NoC system
static inline void allocate_l3_buffers(gemm_args_t *largs ) {

    uint32_t prec = largs->prec;
    uint32_t mem_tile_idx = dst_tile_for_cluster(snrt_cluster_idx());

    uintptr_t a_off = l3_tile_offset((uintptr_t) largs -> a);
    uintptr_t c_off = l3_tile_offset((uintptr_t) largs -> c);
    uintptr_t a_dst = l3_tile_address(mem_tile_idx) + a_off;
    uintptr_t c_dst = l3_tile_address(mem_tile_idx) + c_off;

    // Move data in the correct memory tile location
    uint32_t size_a = (size_t)largs->m * (size_t)largs->k;
    uint32_t size_c = (size_t)largs->m * (size_t)largs->n;
    snrt_dma_start_1d((void *) a_dst, (void *) largs->a, size_a * prec);
    snrt_dma_start_1d((void *) c_dst, (void *) largs->c, size_c * prec);

    // Update A and C local pointer to the relocated memory tile address
    largs->a = (void *) a_dst;
    largs->c = (void *) c_dst;
}

// Write back C tiles in original memory tile for verification purposes
static inline void write_back_c_tiles(gemm_args_t* largs, uint32_t m_tile_size,
                                      uint32_t n_tile_size) {
    uintptr_t c_src, c_dst;
    int c_m_abs, c_n_abs;


    for (uint32_t i = 0; i < largs->n_tiles; i++) {
        // Position of the first element in the Tile to be written back
        c_src = (uintptr_t )largs->c + (snrt_cluster_idx() * largs->n * m_tile_size + i * n_tile_size) * largs->prec;
        c_dst = l3_tile_address(0) + l3_tile_offset(c_src);

        if (c_src != c_dst) {
            c_m_abs = snrt_cluster_idx() * m_tile_size;
            c_n_abs = i * n_tile_size;

            // Transfer the C tile into the destination
            snrt_dma_store_2d_tile((void *) c_dst, (void *) c_src,
                                    c_m_abs, c_n_abs, m_tile_size,
                                    n_tile_size, largs->ldc, largs->prec);

            snrt_dma_wait_all();
        }
    }
}

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

    // Use the DMA core of cluster 0 to place all data in the correct positions
    // so the problem becomes NoC-optimized.
    //
    // Case: parallelization over M, with tiling along both M and N.
    // - Each cluster processes a set of rows of A:
    //   [Cluster_idx * Mt : (Cluster_idx + 1) * Mt - 1].
    // - All clusters share the same set of columns of B:
    //   [num_iter * Nt : (num_iter + 1) * Nt - 1].
    // - Each cluster computes a full tile of C (no partial results - no reduction).
    //
    // Memory tile mapping:
    // - Rows of A for a given cluster are placed in the same row.
    //   * The first half of the clusters load A from the memory tiles on the left [tile 0 - 3].
    //   * The second half of the clusters load A from the memory tiles on the right [tile 4 - 7].
    // - The same scheme is used to store the corresponding tile of C.
    // - Matrix B is stored entirely in the first memory tile.
    //   * Since all clusters need access to B, its exact location does not affect
    //     performance significantly.
    //
    // Notes:
    // - All data movement to arrange memory tiles is performed before measuring
    //   kernel execution time.
    // - With a proper linker script, data could be placed directly in the correct
    //   memory tiles without requiring extra DMA work from cluster 0.

    // TODO (lleone): Improve copying only the necessary information and not the full data stack
    if (snrt_is_dm_core())
    {
        allocate_l3_buffers(largs);
        snrt_dma_wait_all();
    }
    snrt_global_barrier();

    // Distribute m and k tiles to clusters
    uint32_t cluster_m_tiles = largs->m_tiles;
    uint32_t cluster_k_tiles = largs->k_tiles;
    if (largs->parallelize_m) {
        uint32_t m_tiles_quotient = cluster_m_tiles / snrt_cluster_num();
        uint32_t m_tiles_remainder = cluster_m_tiles % snrt_cluster_num();
        cluster_m_tiles = m_tiles_quotient;
        if (snrt_cluster_idx() < m_tiles_remainder) cluster_m_tiles++;
    }
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

        // In the first k iteration we accumulate with the C matrix
        // scaled by beta, in successive iterations we accumulate
        // the previous partial result. The tile-level beta is thus
        // a function of k: beta(k).
        uint32_t comp_k_beta = comp_k_abs == 0 ? largs->beta : 1;
        uint32_t dma_in_k_beta = dma_in_k_abs == 0 ? largs->beta : 1;

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
                                               dma_out_m_abs, dma_out_n, tile_m,
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
                // A and B buffers are switched every iteration, while the C
                // buffer only needs to be switched after fully accumulating
                // the result, i.e. after finishing the K loop.
                int buff_idx = largs->double_buffer ? dma_in_i % 2 : 0;
                int c_buff_idx = largs->double_buffer ? dma_in_mn % 2 : 0;
                int load_a = largs->double_buffer ? (dma_in_i < 2) : (dma_in_i < 1);

                // Load A
                // TODO (lleone): When tiling on M and parallelizing on M there is no need
                // to load At multiple times.
                // If you have DOBU, you load twice and then At is available
                // in both buffers. This can be done only when Mt is fully parallelizable
                // in you system.
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
                        if (load_a) {
                            snrt_dma_load_2d_tile(
                                la[buff_idx], largs->a, dma_in_m_abs, dma_in_k_abs,
                                tile_m, tile_k, largs->lda, largs->prec);
                        }
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
                            // TODO (lleone): Is it really necessary?
                            if (largs->parallelize_k) {
                                snrt_dma_load_2d_tile(
                                    lb[buff_idx], largs->b, dma_in_k_abs, dma_in_n,
                                    tile_k, tile_n, largs->ldb, largs->prec);
                            } else {
                                // Multicast B to all clusters
                                #ifdef HW_MCAST
                                    if (snrt_cluster_idx() == 0) {
                                        // Load B from L2
                                        snrt_dma_load_2d_tile_mcast(
                                        lb[buff_idx], largs->b, dma_in_k_abs, dma_in_n,
                                        tile_k, tile_n, largs->ldb, largs->prec, 0x003C0000);
                                    }
                                #else
                                    snrt_dma_load_2d_tile(
                                    lb[buff_idx], largs->b, dma_in_k_abs, dma_in_n,
                                    tile_k, tile_n, largs->ldb, largs->prec);
                                #endif
                            }
                        }
                    }
                }

                // Load C
                // C tile is loaded only upon the first k iteration, then
                // the C array will contain the partial results from the
                // previous iteration
                if (largs->load_c && dma_in_k_beta != 0) {
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
        if (!largs->double_buffer) snrt_global_barrier();

        // Compute phase
        if (comp_i >= 0 && comp_i < num_tiles) {
            // Switch buffers
            int buff_idx = largs->double_buffer ? comp_i % 2 : 0;
            int c_buff_idx = largs->double_buffer ? comp_mn % 2 : 0;

            // Only compute cores participate in the tile computation
            if (!snrt_is_dm_core()) {
                // uint32_t start_cycle = snrt_mcycle();

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
                sc_st_args.beta = comp_k_beta;
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

    // Before completing the kernel, each cluster writes back its C tiles in the
    // original memory tile. This is necessary only to run teh verify.py script
    // if (snrt_is_dm_core()) {
    //     write_back_c_tiles(largs, tile_m, tile_n);
    // }
    return 0;
}


int main () {
    gemm_picobello(&args);
    return 0;
}
