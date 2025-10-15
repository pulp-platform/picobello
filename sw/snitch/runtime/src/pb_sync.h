// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

inline void pb_create_mesh_comm(snrt_comm_t *comm, uint32_t n_rows,
    uint32_t n_cols, uint32_t start_row = 0, uint32_t start_col = 0) {
    // Allocate communicator struct in L1 and point to it.
    *comm =
        (snrt_comm_t)snrt_l1_alloc_cluster_local(sizeof(snrt_comm_info_t));

    // Allocate barrier counter in L1. Only the first cluster's is actually
    // used, but we want to keep all clusters' L1 allocators aligned. Thus, 
    // only the first cluster initializes its barrier counter. A global barrier
    // is then used to ensure all cores "see" the initialized value.
    uint32_t first_cluster = start_col * pb_cluster_num_in_col() + start_row;
    void *barrier_ptr = snrt_l1_alloc_cluster_local(sizeof(uint32_t));
    barrier_ptr = snrt_remote_l1_ptr(barrier_ptr, snrt_cluster_idx(),
        first_cluster);
    if ((snrt_cluster_idx() == first_cluster) && snrt_is_dm_core()) {
        *(uint32_t *)barrier_ptr = 0;
        snrt_fence();
    }
    snrt_global_barrier();

    // Initialize communicator, pointing to the newly-allocated barrier
    // counter in L3.
    (*comm)->size = n_rows * n_cols;
    (*comm)->mask = ((n_cols - 1) << PB_LOG2_CLUSTER_PER_COL) |
        (n_rows - 1);
    (*comm)->base = (start_col << PB_LOG2_CLUSTER_PER_COL) | start_row;
    (*comm)->barrier_ptr = (uint32_t *)barrier_ptr;
    uint32_t in_row_range = (pb_cluster_row_idx() >= start_row) &&
        (pb_cluster_row_idx() < (start_row + n_rows));
    uint32_t in_col_range = (pb_cluster_col_idx() >= start_col) &&
        (pb_cluster_col_idx() < (start_col + n_cols));
    (*comm)->is_participant = in_row_range && in_col_range;
}
