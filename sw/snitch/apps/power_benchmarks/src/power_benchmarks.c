// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "snrt.h"
#include "blas.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreorder-init-list"
#include "data.h"
#pragma clang diagnostic pop

// Cluster indices
#define C0 pb_calculate_cluster_idx(0, 0)  // row 0, col 0 — netlist under test
#define C4 pb_calculate_cluster_idx(0, 1)  // row 0, col 1 — helper cluster

// Run an experiment function twice. The first run warms up the state; the
// second run is the one used for power measurement (identified by the pair of
// snrt_mcycle() markers surrounding it). Barriers bracketing each rep are
// placed outside the measurement window.
#define RUN_EXPERIMENT(call) do {                    \
    snrt_global_barrier(comm);                       \
    for (volatile int _rep = 0; _rep < 2; _rep++) {  \
        snrt_mcycle();                               \
        call;                                        \
        snrt_mcycle();                               \
        snrt_global_barrier(comm);                   \
    }                                                \
} while (0)

// Experiment 1: DMA load from memory tile 0 into cluster 0's TCDM.
// Measures energy per word transferred on the cluster's load path from L2.
// C0 is active; C4 is idle (not measured).
static inline void exp_dma_load(double *a, size_t sz) {
    if (snrt_cluster_idx() == C0 && snrt_is_dm_core()) {
        snrt_dma_start_1d(a, (void *)mat, sz);
        snrt_dma_wait_all();
    }
    snrt_cluster_hw_barrier();
}

// Experiment 2: DMA store from cluster 0's TCDM to memory tile 0.
// Measures energy per word transferred on the cluster's store path to L2.
// C0 is active; C4 is idle (not measured).
static inline void exp_dma_store(double *a, size_t sz) {
    if (snrt_cluster_idx() == C0 && snrt_is_dm_core()) {
        snrt_dma_start_1d((void *)mat, a, sz);
        snrt_dma_wait_all();
    }
    snrt_cluster_hw_barrier();
}

// Experiment 3: cluster 4 transfers data to memory tile 0.
// The path goes C4 → C0's router → M0, so cluster 0 is passive but its
// router carries the traffic. Measures cluster 0's router traversal energy.
// C4 is active; C0 is passive (its DM sleeps until woken by C4's DM).
static inline void exp_crossing(double *a, size_t sz) {
    uint32_t n = snrt_cluster_compute_core_num();
    if (snrt_cluster_idx() == C4 && snrt_is_dm_core()) {
        snrt_dma_start_1d((void *)mat, a, sz);
        snrt_dma_wait_all();
        snrt_int_cluster_set(1u << n, C0);  // wake C0 DM
    } else if (snrt_cluster_idx() == C0 && snrt_is_dm_core()) {
        snrt_wfi();
        snrt_int_clr_mcip();
    }
    snrt_cluster_hw_barrier();
}

// Experiment 4: cluster 4 writes into cluster 0's TCDM.
// C4 is active; C0 is passive (its DM sleeps until woken by C4's DM).
static inline void exp_remote_write(double *a, size_t sz) {
    uint32_t n = snrt_cluster_compute_core_num();
    if (snrt_cluster_idx() == C4 && snrt_is_dm_core()) {
        void *a_in_c0 = snrt_remote_l1_ptr(a, C4, C0);
        snrt_dma_start_1d(a_in_c0, a, sz);
        snrt_dma_wait_all();
        snrt_int_cluster_set(1u << n, C0);  // wake C0 DM
    } else if (snrt_cluster_idx() == C0 && snrt_is_dm_core()) {
        snrt_wfi();
        snrt_int_clr_mcip();
    }
    snrt_cluster_hw_barrier();
}

// Experiment 5: GEMM in cluster 0 with A, B, C residing in TCDM.
// Measures the energy per GEMM operation in the compute cores.
// C0 DM sleeps at the hw_barrier while compute cores work; C4 is idle.
static inline void exp_gemm(double *a, double *b, double *c, uint32_t m) {
    if (snrt_cluster_idx() == C0 && snrt_is_compute_core()) {
        sc_st_gemm_args_t args;
        args.prec = FP64;
        args.setup_ssr = 1;
        args.partition_banks = 0;
        args.transa = 0;
        args.transb = 0;
        args.m = m;
        args.n = m;
        args.k = m;
        args.alpha = 1.0;
        args.a = a;
        args.lda = m;
        args.b = b;
        args.ldb = m;
        args.beta = 0;
        args.c = c;
        args.ldc = m;
        sc_st_gemm(gemm_fp64_opt, &args);
    } else {
        snrt_mcycle();
        snrt_mcycle();
    }
    // C0 DM sleeps here while compute cores run sc_st_gemm; C4 unblocks
    // immediately (no work) and proceeds to the global barrier.
    snrt_cluster_hw_barrier();
}

// Experiment 6: element-wise matrix sum C = A + B in cluster 0.
// Matrices live in TCDM. Models the energy of a software reduction step.
// C0 DM sleeps at the hw_barrier while compute cores work; C4 is idle.
static inline void exp_sw_sum(double *a, double *b, double *c, uint32_t m) {
    if (snrt_cluster_idx() == C0 && snrt_is_compute_core()) {
        uint32_t n      = m * m;
        uint32_t step   = snrt_cluster_compute_core_num();
        uint32_t frac   = n / step;
        uint32_t offset = snrt_cluster_core_idx();

        snrt_ssr_loop_1d(SNRT_SSR_DM_ALL, frac, step * sizeof(double));
        snrt_ssr_read(SNRT_SSR_DM0, SNRT_SSR_1D, a + offset);
        snrt_ssr_read(SNRT_SSR_DM1, SNRT_SSR_1D, b + offset);
        snrt_ssr_write(SNRT_SSR_DM2, SNRT_SSR_1D, c + offset);
        snrt_ssr_enable();
#ifdef SNRT_SUPPORTS_FREP
        asm volatile(
            "frep.o %[n_frep], 1, 0, 0 \n"
            "fadd.d ft2, ft0, ft1\n"
            :
            : [n_frep] "r"(frac - 1)
            : "ft0", "ft1", "ft2", "memory");
#endif
        snrt_fpu_fence();
        snrt_ssr_disable();
    }
    // C0 DM sleeps here while compute cores run the sum; C4 unblocks
    // immediately (no work) and proceeds to the global barrier.
    snrt_cluster_hw_barrier();
}

// Experiment 7: hardware reduction — both cluster 0 and cluster 4 write to
// memory tile 0 with a floating-point add reduction opcode. The interconnect
// accumulates the two writes atomically. Measures cluster 0's energy when its
// DMA participates in a hardware reduction.
// Both DMs are active; compute cores of both clusters sleep at the hw_barrier.
static inline void exp_hw_reduction(double *a, size_t sz, uint64_t mask) {
    if (snrt_is_dm_core()) {
        // Both clusters write to the same physical address: memory tile 0.
        snrt_dma_start_1d_reduction((void *)mat, a, sz, mask,
                                    SNRT_REDUCTION_FADD);
        snrt_dma_wait_all();
    }
    snrt_cluster_hw_barrier();
}

// Experiment 8: idle baseline — cluster 0 is fully idle while cluster 4 spins
// in a NOP loop for `nop_iters` iterations, then wakes cluster 0's DM via
// interrupt. C0's DM sleeps (wfi); C0's compute cores stall at the hw_barrier.
// Measures the static/leakage power of cluster 0 with no activity on any
// network or compute path.
static inline void exp_idle(uint32_t nop_iters) {
    uint32_t n = snrt_cluster_compute_core_num();
    if (snrt_cluster_idx() == C4 && snrt_is_dm_core()) {
        for (volatile uint32_t i = 0; i < nop_iters; i++) snrt_nop();
        snrt_int_cluster_set(1u << n, C0);  // wake C0 DM
    } else if (snrt_cluster_idx() == C0 && snrt_is_dm_core()) {
        snrt_wfi();
        snrt_int_clr_mcip();
    }
    snrt_cluster_hw_barrier();
}

int main() {
    // Create a communicator for clusters 0 and 4 only (1 row × 2 cols).
    // All 16 clusters must call this because it contains a world barrier.
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, 1, 2, 0, 0);

    // Park all clusters that are not part of this benchmark.
    if (!comm->is_participant) return 0;

    // Allocate three M×M buffers in each active cluster's TCDM.
    // Both clusters allocate in the same order so that the TCDM offsets of a,
    // b, c are identical, enabling snrt_remote_l1_ptr to work correctly.
    double *a = snrt_l1_alloc_cluster_local<double>(M * M);
    double *b = snrt_l1_alloc_cluster_local<double>(M * M);
    double *c = snrt_l1_alloc_cluster_local<double>(M * M);
    size_t sz = M * M * sizeof(double);

    // Initialize a and b from the data array generated in data.h.
    if (snrt_is_dm_core()) {
        snrt_dma_start_1d(a, mat, sz);
        snrt_dma_start_1d(b, mat, sz);
        snrt_dma_wait_all();
    }
    snrt_cluster_hw_barrier();
    snrt_global_barrier(comm);

    // Collective mask for hardware reduction (experiment 7).
    uint64_t mask = snrt_get_collective_mask(comm);

    // Run the 8 experiments. Each experiment is executed twice; the VCD window
    // for power measurement is taken from the second repetition.
    RUN_EXPERIMENT(exp_dma_load(a, sz));
    RUN_EXPERIMENT(exp_dma_store(a, sz));
    RUN_EXPERIMENT(exp_crossing(a, sz));
    RUN_EXPERIMENT(exp_remote_write(a, sz));
    RUN_EXPERIMENT(exp_gemm(a, b, c, M));
    RUN_EXPERIMENT(exp_sw_sum(a, b, c, M));
    RUN_EXPERIMENT(exp_hw_reduction(a, sz, mask));
    RUN_EXPERIMENT(exp_idle(100));

    return 0;
}
