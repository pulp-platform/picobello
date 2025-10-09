// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

#include "snrt.h"

#ifndef N_ROWS
#define N_ROWS (pb_cluster_num_in_col())
#endif

#ifndef N_COLS
#define N_COLS (pb_cluster_num_in_row())
#endif

typedef enum {
    SW,
    HW
} impl_t;

#ifndef IMPL
#define IMPL SW
#endif

static inline void sw_barrier(snrt_comm_t comm) {
    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_COLLECTIVE_MULTICAST;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    volatile uint32_t *mcip_set = (uint32_t *)&(snrt_cluster()->peripheral_reg.cl_clint_set.w);
    volatile uint32_t *mcip_clr = (uint32_t *)&(snrt_cluster()->peripheral_reg.cl_clint_clear.w);
    uint32_t size = comm->size;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Execute barrier in submesh (first iteration to preheat I$)
    for (volatile uint32_t i = 0; i < 2; i++) {
        // Align start times using hardware barrier
        snrt_inter_cluster_barrier(comm);
        
        snrt_mcycle();

        // Perform software inter-cluster barrier.
        uint32_t cnt = __atomic_add_fetch(barrier_ptr, 1, __ATOMIC_RELAXED);

        // Cluster 0 polls the barrier counter, resets it for the next barrier
        // and multicasts an interrupt to wake up the other clusters. Compared
        // to the implementation in sync.h, this version is cache-friendly,
        // i.e. successive invocations of the barrier will find a hot cache.
        if (snrt_cluster_idx() == 0) {
            while (*barrier_ptr != size);
            *barrier_ptr = 0;
            snrt_fence();
            snrt_set_awuser_low(user);
            *mcip_set = 1 << snrt_cluster_compute_core_num();
            snrt_set_awuser_low(0);
        } else {
            snrt_wfi();
        }
        // Clear interrupt for next barrier (also the sending cluster)
        *mcip_clr = 1 << snrt_cluster_compute_core_num();
        snrt_mcycle();
    }
}

static inline void hw_barrier(snrt_comm_t comm) {
    // Prepare for inter-cluster barrier in advance, preventing instruction
    // reordering using the volatile block.
    snrt_collective_op_t op;
    op.f.collective_op = SNRT_REDUCTION_BARRIER;
    op.f.mask = snrt_get_collective_mask(comm);
    volatile uint32_t *barrier_ptr = comm->barrier_ptr;
    uint32_t user = (uint32_t)op.w;
    asm volatile ("" : "+r"(user) ::);

    // Execute barrier in submesh (first iteration to preheat I$, second to
    // align start times for third iteration)
    for (volatile uint32_t i = 0; i < 3; i++) {
        snrt_mcycle();
        // Perform inter-cluster barrier. Disable reduction before the fence
        // so it overlaps with the latency of the ongoing reduction operation.
        snrt_set_awuser_low(user);
        *barrier_ptr = 1;
        snrt_set_awuser_low(0);
        snrt_fence();
        snrt_mcycle();
    }
}

int main (void) {

    // Create communicator for submesh
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, N_ROWS, N_COLS);

    if (snrt_is_dm_core() && comm->is_participant) {
        // Execute barrier in submesh
        if (IMPL == SW) {
            sw_barrier(comm);
        } else {
            hw_barrier(comm);
        }

        // Wake up all cores put to sleep.
        // Note: this is a workaround since multiple intersecting barriers are
        // not supported yet.
        if (snrt_cluster_idx() == 0) {
            for (uint32_t i = 0; i < snrt_cluster_num(); i++) {
                uint32_t is_participant = pb_cluster_col_idx(i) < N_COLS &&
                    pb_cluster_row_idx(i) < N_ROWS;
                if (!is_participant) snrt_int_cluster_set(
                    1 << snrt_cluster_compute_core_num(), i);
            }
        }
    }
    // Other clusters go to sleep
    else {
        if (snrt_is_dm_core()) {
            snrt_wfi();
            snrt_int_clr_mcip();
        }
    }

    // Make compute cores wait on cluster hardware barrier
    snrt_cluster_hw_barrier();

	return 0;
}
