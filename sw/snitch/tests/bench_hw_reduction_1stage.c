// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Raphael Roth <raroth@student.ethz.ch>
//
// This code can be used to benchmark the hardware reduction feature of the picobello
// system. It can reduce double data directly in flight with the internal DMA.
// It is possible to set the target cluster freely.
// The reduction is done in one stage for all clusters.

#include <stdint.h>
#include "pb_addrmap.h"
#include "snrt.h"

// use this define to enable "row" reduction instead of columne reduction
// has only a effect if Number of cluster is 8!
#ifndef REDUCE_IN_ROW
#define REDUCE_IN_ROW                   0
#endif

// Benchmark Parameter:
#ifndef NUMBER_OF_CLUSTERS
#define NUMBER_OF_CLUSTERS              16   // Needs to be either 4 / 8 / 16
#endif

#ifndef TARGET_CLUSTER
#define TARGET_CLUSTER                  0
#endif

#ifndef DATA_BYTE
#define DATA_BYTE                       8192
#endif

// Translate from byte into doubles
#ifndef DATA_LENGTH
#define DATA_LENGTH                     (DATA_BYTE/8)
#endif

#define DATA_EVAL_LENGTH    (DATA_LENGTH)

// Define the reduction mask depending on the number of involved clusters
// When we reduce in the row then the mask is hardcoded!
#if REDUCE_IN_ROW == 0
    #define REDUCTION_MASK      ((NUMBER_OF_CLUSTERS - 1) << 18)
#else
    #define GROUND_MASK (((NUMBER_OF_CLUSTERS == 4) * 12) + ((NUMBER_OF_CLUSTERS == 8) * 13) + ((NUMBER_OF_CLUSTERS == 16) * 15))
    #define REDUCTION_MASK      (GROUND_MASK << 18)
#endif

/**
 * @brief Return if the cluster is involved in the reduction or not.
 * @param cluster_nr cluster id
 */
static inline int cluster_participates_in_reduction(int cluster_nr) {
#if REDUCE_IN_ROW == 0
    return (cluster_nr < NUMBER_OF_CLUSTERS);
#else
    if(NUMBER_OF_CLUSTERS == 4){
        return ((cluster_nr % 4) == 0);
    } else if(NUMBER_OF_CLUSTERS == 8){
        return (((cluster_nr % 4) == 0) || ((cluster_nr % 4) == 1));
    } else {
        return (cluster_nr < NUMBER_OF_CLUSTERS);
    }
#endif
}

/**
 * @brief Verify if the data are properly copied. Please adapt the algorythm if you change the data generation
 * @param cluster_nr cluster id
 * @param ptrData pointer to fetch the data from
 */
static inline uint32_t cluster_verify_reduction(int cluster_nr, double * ptrData) {
    // Evaluate the reduction result
    if (snrt_is_dm_core() && (cluster_nr == TARGET_CLUSTER)) {
        uint32_t n_errs = DATA_EVAL_LENGTH;
#if REDUCE_IN_ROW == 0
        double base_value = (NUMBER_OF_CLUSTERS * 15.0) + (double) (((NUMBER_OF_CLUSTERS-1) * ((NUMBER_OF_CLUSTERS-1) + 1)) >> 1);
#else
        double base_value = 0.0;
        if(NUMBER_OF_CLUSTERS == 4){
            base_value = (NUMBER_OF_CLUSTERS * 15.0) + 24.0;
        } else if(NUMBER_OF_CLUSTERS == 8){
            base_value = (NUMBER_OF_CLUSTERS * 15.0) + 52.0;
        } else {
            base_value = (NUMBER_OF_CLUSTERS * 15.0) + 120.0;
        }
#endif
        for (uint32_t i = 0; i < DATA_EVAL_LENGTH; i++) {
            if (*ptrData == base_value){
                n_errs--;
            }
            base_value = base_value + (double) NUMBER_OF_CLUSTERS;
            ptrData = ptrData + 1;
        }
        return n_errs;
    } else {
        return 0;
    }
}

// Main code
int main() {
    snrt_interrupt_enable(IRQ_M_CLUSTER);

    // Sanity check:
    if(((NUMBER_OF_CLUSTERS % 4) != 0) && (NUMBER_OF_CLUSTERS != 12)){
        // Number of cluster should be a power of 2 (for mask generation)
        return 1;
    }

    // Cluster ID
    uint32_t cluster_id = snrt_cluster_idx();

    // Set the mask for the multicast
    uint64_t mask = REDUCTION_MASK;

    // Generate unique data for the reduction
    double fill_value = 42.0;
    double init_data = 15.0 + (double) cluster_id;

    // Allocate destination buffer
    double *buffer_dst = (double*) snrt_l1_next_v2();
    double *buffer_src = buffer_dst + DATA_LENGTH;

    // Determint the target address
    double *buffer_target = (double*) snrt_remote_l1_ptr(buffer_dst, cluster_id, TARGET_CLUSTER);
    volatile double *buffer_last_entry = (volatile double *) (buffer_dst + DATA_LENGTH - 1);

    // Fill the source buffer with the init data
    if (snrt_is_dm_core()) {
        for (uint32_t i = 0; i < DATA_LENGTH; i++) {
            buffer_src[i] = init_data + (double) i;
            buffer_dst[i] = fill_value;
        }
    }

    // Do the transmission 3 times to preheat the cache
    for(volatile int i = 0; i < 3; i++){
        // Reset the last entry from prior loop (if @ end of loop > check at end fails)
        if((cluster_id == TARGET_CLUSTER) && snrt_is_dm_core()){
            *buffer_last_entry = fill_value;
        }

        // Wait until the cluster are finished
        snrt_global_barrier();

        // Perf. analysis
        snrt_mcycle();

        // Init the DMA multicast
        if (snrt_is_dm_core() && cluster_participates_in_reduction(cluster_id)) {
            snrt_dma_start_1d_reduction(buffer_target, buffer_src, DATA_LENGTH * sizeof(double), mask, SNRT_REDUCTION_FADD);
            // Only waits until last w is transmitted but not until b response arrives!
            snrt_dma_wait_all();
        }

        // Target cluster polls the last array entry to know when we wrote the data
        if((cluster_id == TARGET_CLUSTER) && snrt_is_dm_core()){
            while(*buffer_last_entry == fill_value);
        }

        // Perf. analysis
        snrt_mcycle();

    }

    // Sync all cores
    snrt_global_barrier();

    // Evaluate the reduction result
    return cluster_verify_reduction(cluster_id, buffer_dst);
}
