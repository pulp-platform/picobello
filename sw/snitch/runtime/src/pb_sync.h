// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

inline void pb_create_mesh_comm(snrt_comm_t *comm, uint32_t n_rows,
    uint32_t n_cols) {
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
    (*comm)->size = n_rows * n_cols;
    (*comm)->mask = ((n_cols - 1) << PB_LOG2_CLUSTER_PER_COL) |
        (n_rows - 1);
    (*comm)->base = 0;
    (*comm)->barrier_ptr = (uint32_t *)barrier_ptr;
    (*comm)->is_participant = (pb_cluster_row_idx() < n_rows) &&
        (pb_cluster_col_idx() < n_cols);
}
