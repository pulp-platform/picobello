// Copyright 2020 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/* Tests that a single core can do atomics */

#include <snrt.h>

//===============================================================
// RISC-V atomic instruction wrappers
//===============================================================

static inline uint32_t lr_w(volatile uint32_t* addr) {
    uint32_t data = 0;
    asm volatile("lr.w %[data], (%[addr])"
                 : [ data ] "+r"(data)
                 : [ addr ] "r"(addr)
                 : "memory");
    return data;
}

static inline uint32_t sc_w(volatile uint32_t* addr, uint32_t data) {
    uint32_t err = 0;
    asm volatile("sc.w %[err], %[data], (%[addr])"
                 : [ err ] "+r"(err)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return err;
}

static inline uint32_t atomic_maxu_fetch(volatile uint32_t* addr,
                                         uint32_t data) {
    uint32_t prev = 0;
    asm volatile("amomaxu.w %[prev], %[data], (%[addr])"
                 : [ prev ] "+r"(prev)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return prev;
}

static inline uint32_t atomic_minu_fetch(volatile uint32_t* addr,
                                         uint32_t data) {
    uint32_t prev = 0;
    asm volatile("amominu.w %[prev], %[data], (%[addr])"
                 : [ prev ] "+r"(prev)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return prev;
}

//===============================================================
// Test atomics on a given memory location (single core)
//===============================================================

uint32_t test_atomics(volatile uint32_t* atomic_var) {
    uint32_t tmp = 0;
    uint32_t nerrors = 0;
    uint32_t dummy_val = 42;
    uint32_t amo_operand;
    uint32_t expected_val;

    uint32_t cluster_num = snrt_cluster_num();

    /******************************************************
     * Initialize
     ******************************************************/
    *atomic_var = 0;
    expected_val = *atomic_var;
    snrt_inter_cluster_barrier();

    /******************************************************
     * Test 2: AMOADD
     ******************************************************/
    amo_operand = 1;
    expected_val += amo_operand * cluster_num;
    __atomic_add_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    snrt_inter_cluster_barrier();
    if (*atomic_var != expected_val) nerrors++;
    snrt_inter_cluster_barrier();

    /******************************************************
     * Test 3: AMOSUB
     ******************************************************/
    amo_operand = 1;
    expected_val -= amo_operand * cluster_num;
    __atomic_sub_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    snrt_inter_cluster_barrier();
    if (*atomic_var != expected_val) nerrors++;
    snrt_inter_cluster_barrier();

    return nerrors;
}

// Use at least two locations to test unaligned accesses
#define NUM_SPM_LOCATIONS 2
volatile uint32_t l3_a[NUM_SPM_LOCATIONS];
volatile uint32_t* multicluster_error;

int main() {
    uint32_t core_id = snrt_cluster_core_idx();
    uint32_t core_num = snrt_cluster_core_num();
    uint32_t register volatile nerrors = 0;

    if (core_id == 0) {
    	// Verify atomics
        for (uint32_t i = 0; i < NUM_SPM_LOCATIONS; i++) {
            nerrors = test_atomics(&l3_a[i]);
            __atomic_add_fetch(multicluster_error, nerrors, __ATOMIC_RELAXED);
            snrt_inter_cluster_barrier();
            return *multicluster_error;
        }
    } else {
        return 0;
    }
}
