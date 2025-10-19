// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Raphael Roth <raroth@student.ethz.ch>
//
// This code can be used to benchmark the reduction feature of the picobello system.
// It supports the binary tree based approach of sw reduction. Compared to the naive
// implementation this binary tree is pipelined and it uses the SSR for the reduction.
// to simplfy the code the innermot loop is unrolled
//
// Dataflow:
// See the documentation / presentation of my master thesis!
//
// Limitation:
// - The Target Cluster is hardcoded as 0
// - Code is written as unrolled!
// - To further simplify the sw we support only 8 / 16 reducting cluster
// - We assum that the computation takes always longer than the dma transfer e.g. at the end of the computation
//   the data are inside the new memory addresses (No real good way to check if transfer complete unless polling the register)

#include <stdint.h>
#include "pb_addrmap.h"
#include "snrt.h"

#ifndef NUMBER_OF_CLUSTERS
#define NUMBER_OF_CLUSTERS              4
#endif

#define HARDCODED_TARGET_CLUSTER        0

#ifndef DATA_BYTE
#define DATA_BYTE                       8192
#endif

// Translate from byte into doubles
#ifndef DATA_LENGTH
#define DATA_LENGTH                     (DATA_BYTE/8)
#endif

#ifndef STAGES
#define STAGES                          8
#endif

#define DATA_PER_STAGE                  (DATA_LENGTH/STAGES)
#define DATA_PER_SSR                    (DATA_PER_STAGE/snrt_cluster_compute_core_num())
#define DATA_EVAL_LENGTH                (DATA_LENGTH)

/**
 * @brief Verify if the data are properly copied. Please adapt the algorythm if you change the data generation
 * @param cluster_nr cluster id
 * @param ptrData pointer to fetch the data from
 */
static inline uint32_t cluster_verify_reduction(int cluster_nr, double * ptrData) {
    // Evaluate the reduction result
    if (snrt_is_dm_core() && (cluster_nr == HARDCODED_TARGET_CLUSTER)) {
        uint32_t n_errs = DATA_EVAL_LENGTH;
        double base_value = (NUMBER_OF_CLUSTERS*15.0) + (double) (((NUMBER_OF_CLUSTERS-1) * ((NUMBER_OF_CLUSTERS-1) + 1)) >> 1);
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

int main (void){
    snrt_interrupt_enable(IRQ_M_CLUSTER);

    // Sanity check:
    // Data should be dividable by number of stages
    if((DATA_LENGTH % STAGES) != 0){
        return 1;
    }
    // Data per stage should be dividable by 8 for easier SSR config
    if((DATA_PER_STAGE % 8) != 0){
        return 1;
    }

    // Cluster ID
    uint32_t cluster_id = snrt_cluster_idx();
    uint32_t max_level = ceil(log2(NUMBER_OF_CLUSTERS));

    // Generate unique data for the reduction
    double init_data = 15.0 + (double) cluster_id;

    // IMPORTANT:
    // TODO: Encode this in like uint32_t if possible --> fetches each element from memory which takes forever
    // This matrix does not only define if the dma cor is in the given level activ but it also defines to which cluster
    // it should send its data. If the number is equal to its own cluster number then the core doesn't do anything.
    //
    // Due to the compiler not optimizing this array (even if defined as const) 
    // I put the hole array inside a uint64_t. I hope this will be loaded as intermidiate!
    /*
#if NUMBER_OF_CLUSTERS == 16
    uint32_t dma_core_active[4][16] = { {  4,  5,  6,  7,  4,  5,  6,  7, 12, 13, 14, 15, 12, 13, 14, 15},
                                        {  0,  1,  2,  3,  1,  1,  3,  3,  8,  9, 10, 11,  9,  9, 11, 11},
                                        {  0,  2,  2,  2,  4,  5,  6,  7,  8, 10, 10, 10, 12, 13, 14, 15},
                                        {  0,  1,  0,  3,  4,  5,  6,  7,  8,  9,  0, 11, 12, 13, 14, 15}};
#else
    uint32_t dma_core_active[3][16] = { {  4,  5,  6,  7,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15},
                                        {  0,  1,  2,  3,  1,  1,  3,  3,  8,  9, 10, 11, 12, 13, 14, 15},
                                        {  0,  0,  2,  0,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15}};
#else
    uint32_t dma_core_active[2][16] = { {  1,  1,  3,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15},
                                        {  0,  0,  2,  0,  1,  1,  3,  3,  8,  9, 10, 11, 12, 13, 14, 15}};
#endif
    */

#if NUMBER_OF_CLUSTERS == 16
    uint64_t dma_core_active_stg1 = 0xFEDCFEDC76547654;
    uint64_t dma_core_active_stg2 = 0xBB99BA9833113210;
    uint64_t dma_core_active_stg3 = 0xFEDCAAA876542220;
    uint64_t dma_core_active_stg4 = 0xFEDCB09876543010;

#elif NUMBER_OF_CLUSTERS == 8
    uint64_t dma_core_active_stg1 = 0xFEDCBA9876547654;
    uint64_t dma_core_active_stg2 = 0xFEDCBA9833113210;
    uint64_t dma_core_active_stg3 = 0xFEDCBA9876540200;
#else
    uint64_t dma_core_active_stg1 = 0xFEDCBA9876543311;
    uint64_t dma_core_active_stg2 = 0xFEDCBA9876540200;
#endif

    // Same here
    // This maxtrix defines if the computer core is active in the given level. A "1" indicates active, "0" inactive
/*
#if NUMBER_OF_CLUSTERS == 16
    uint32_t compute_core_active[4][16] = { {  0,  0,  0,  0,  1,  1,  1,  1,  0,  0,  0,  0,  1,  1,  1,  1},
                                            {  0,  1,  0,  1,  0,  0,  0,  0,  1,  0,  1,  0,  0,  0,  0,  0},
                                            {  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0},
                                            {  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0}};
#else
    uint32_t compute_core_active[3][16] = { {  0,  0,  0,  0,  1,  1,  1,  1,  0,  0,  0,  0,  0,  0,  0,  0},
                                            {  0,  1,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
                                            {  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0}};
#else
    uint32_t compute_core_active[2][16] = { {  0,  1,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
                                            {  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0}};
#endif
*/

#if NUMBER_OF_CLUSTERS == 16
    uint32_t compute_core_active_stg1 = 0b00000000000000001111000011110000;
    uint32_t compute_core_active_stg2 = 0b00000000000000000000101000001010;
    uint32_t compute_core_active_stg3 = 0b00000000000000000000010000000100;
    uint32_t compute_core_active_stg4 = 0b00000000000000000000000000000001;
#elif NUMBER_OF_CLUSTERS == 8
    uint32_t compute_core_active_stg1 = 0b00000000000000000000000011110000;
    uint32_t compute_core_active_stg2 = 0b00000000000000000000000000001010;
    uint32_t compute_core_active_stg3 = 0b00000000000000000000000000000001;
#else
    uint32_t compute_core_active_stg1 = 0b00000000000000000000000000001010;
    uint32_t compute_core_active_stg2 = 0b00000000000000000000000000000001;
#endif

    // Allocate destination buffer
    double *buffer_src = (double*) snrt_l1_next_v2();                               // Source buffer (s: DATA_LENGTH)
    double *buffer_dst = buffer_src + DATA_LENGTH;                                  // Destination buffer (s: DATA_LENGTH)
    double *buffer_intermidiate_in = buffer_dst + DATA_LENGTH;                      // Input for intermidiate results (s: 2*2*DATA_PER_STAGE)

    // Allocate remaining vars
    double *data_ptr = buffer_src;
    double *data_ptr_target = buffer_dst;

    // Vars for the different iterations 
    uint32_t itr_stg1 = 0;
    uint32_t itr_stg2 = 0;
    uint32_t itr_stg3 = 0;
    uint32_t itr_stg4 = 0;

    // Determint the target address
    double *ptr_local_intermidiate_in[2][2] = { {buffer_intermidiate_in, buffer_intermidiate_in + DATA_PER_STAGE},
                                                {buffer_intermidiate_in + 2*DATA_PER_STAGE, buffer_intermidiate_in + 3*DATA_PER_STAGE}};
    double *ptr_local_intermidiate_out[2] = {buffer_dst, buffer_dst + DATA_PER_STAGE};  // We re-use the dst buffer as only the Target Cluster uses these

    // Fill the source buffer with the init data
    if (snrt_is_dm_core()) {
        for (uint32_t i = 0; i < DATA_LENGTH; i++) {
            buffer_src[i] = init_data + (double) i;
        }
    }

    // Wait until the cluster are finished
    snrt_global_barrier();

    // Do it 3 time to preheat the cache
    for(volatile int i = 0; i < 3; i++){

        // Reset Vars
        data_ptr = buffer_src;
        data_ptr_target = buffer_dst;

        itr_stg1 = 0;
        itr_stg1 = 0;
        itr_stg2 = 0;
        itr_stg3 = 0;
        itr_stg4 = 0;

        // Sync all cores
        snrt_mcycle();
        snrt_global_barrier();

        // *********************************************
        // Flow - Pipeline - Copy data & reduce @ target
        for(volatile int j = 0; j < (STAGES+max_level*2-1);j++){    // @ 16 Cluster: +7 @ 8 Cluster: +5
            snrt_mcycle();

            // Check the DMA Core for all levels
            if(snrt_is_dm_core()){
                uint32_t shift_cluster_id = cluster_id << 2;
                uint32_t extraced_cluster_id;

                // First Level
                extraced_cluster_id = ((uint32_t) (dma_core_active_stg1 >> shift_cluster_id)) & 0xF;
                if((extraced_cluster_id != cluster_id) && (j < STAGES)){
                    // Calc remote target address
                    double * src_local = (double *) snrt_remote_l1_ptr(ptr_local_intermidiate_in[itr_stg1][0], cluster_id, extraced_cluster_id);
                    // Start the DMA transfer
                    snrt_dma_start_1d(src_local, data_ptr, DATA_PER_STAGE * sizeof(double));
                    // Modify metadata
                    data_ptr = data_ptr + DATA_PER_STAGE;
                    itr_stg1 = itr_stg1 ^ 1;
                }

                // Second Level
                extraced_cluster_id = ((uint32_t) (dma_core_active_stg2 >> shift_cluster_id)) & 0xF;
                if((extraced_cluster_id != cluster_id) && (j > 1) && (j < (STAGES+2))){
                    // Calc remote target address
                    // Hotfix to support reduction with only 4 cluster - neeedsto be fixed!!!
# if(NUMBER_OF_CLUSTERS == 4)
                    double * src_local = (double *) snrt_remote_l1_ptr(ptr_local_intermidiate_in[itr_stg2][(cluster_id >> 1) % 2], cluster_id, extraced_cluster_id);
#else
                    double * src_local = (double *) snrt_remote_l1_ptr(ptr_local_intermidiate_in[itr_stg2][cluster_id % 2], cluster_id, extraced_cluster_id);
#endif
                    // Start the DMA transfer
                    snrt_dma_start_1d(src_local, ptr_local_intermidiate_out[itr_stg2], DATA_PER_STAGE * sizeof(double));
                    // Modify metadata
                    itr_stg2 = itr_stg2 ^ 1;
                }

#if ((NUMBER_OF_CLUSTERS == 8) || (NUMBER_OF_CLUSTERS == 16))
                // Third Level
                extraced_cluster_id = ((uint32_t) (dma_core_active_stg3 >> shift_cluster_id)) & 0xF;
                if((extraced_cluster_id != cluster_id) && (j > 3) && (j < (STAGES+4))){
                    // Calc remote target address
                    double * src_local = (double *) snrt_remote_l1_ptr(ptr_local_intermidiate_in[itr_stg3][(cluster_id >> 1) % 2], cluster_id, extraced_cluster_id);
                    // Start the DMA transfer
                    snrt_dma_start_1d(src_local, ptr_local_intermidiate_out[itr_stg3], DATA_PER_STAGE * sizeof(double));
                    // Modify metadata
                    itr_stg3 = itr_stg3 ^ 1;
                }
#endif

#if NUMBER_OF_CLUSTERS == 16
                // Forth (optinal) Level
                extraced_cluster_id = ((uint32_t) (dma_core_active_stg4 >> shift_cluster_id)) & 0xF;
                if((extraced_cluster_id != cluster_id) && (j > 5) && (j < (STAGES+6))){
                    // Calc remote target address
                    double * src_local = (double *) snrt_remote_l1_ptr(ptr_local_intermidiate_in[itr_stg4][(cluster_id >> 3) % 2], cluster_id, extraced_cluster_id);
                    // Start the DMA transfer
                    snrt_dma_start_1d(src_local, ptr_local_intermidiate_out[itr_stg4], DATA_PER_STAGE * sizeof(double));
                    // Modify metadata
                    itr_stg4 = itr_stg4 ^ 1;
                }
#endif

                // Wait till all DMA transfer are sent
                // Unfortunatly this is not a fence - it triggers as soon as all W-Beats are sent :(
                snrt_dma_wait_all();
            }

            // Check the Compute Core for all levels
            if(snrt_is_compute_core()){

                // First Level
                if((((compute_core_active_stg1 >> cluster_id) & 1) == 1) && (j > 0) && (j < (STAGES+1))){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(data_ptr, ptr_local_intermidiate_in[itr_stg1][0], ptr_local_intermidiate_out[itr_stg1]);
                    // Modify metadata
                    data_ptr = data_ptr + DATA_PER_STAGE;
                    itr_stg1 = itr_stg1 ^ 1;
                }

#if NUMBER_OF_CLUSTERS == 16
                // Second Level
                if((((compute_core_active_stg2 >> cluster_id) & 1) == 1) && (j > 2) && (j < (STAGES+3))){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg2][0], ptr_local_intermidiate_in[itr_stg2][1], ptr_local_intermidiate_out[itr_stg2]);
                    // Modify metadata
                    itr_stg2 = itr_stg2 ^ 1;
                }

                // Third Level
                if((((compute_core_active_stg3 >> cluster_id) & 1) == 1) && (j > 4) && (j < (STAGES+5))){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg3][0], ptr_local_intermidiate_in[itr_stg3][1], ptr_local_intermidiate_out[itr_stg3]);
                    // Modify metadata
                    itr_stg3 = itr_stg3 ^ 1;
                }

                // Forth Level
                if((((compute_core_active_stg4 >> cluster_id) & 1) == 1) && (j > 6)){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg4][0], ptr_local_intermidiate_in[itr_stg4][1], data_ptr_target);
                    // Modify metadata
                    data_ptr_target = data_ptr_target + DATA_PER_STAGE;
                    itr_stg4 = itr_stg4 ^ 1;
                }
#elif NUMBER_OF_CLUSTERS == 8
                // Second Level
                if((((compute_core_active_stg2 >> cluster_id) & 1) == 1) && (j > 2) && (j < (STAGES+3))){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg2][0], ptr_local_intermidiate_in[itr_stg2][1], ptr_local_intermidiate_out[itr_stg2]);
                    // Modify metadata
                    itr_stg2 = itr_stg2 ^ 1;
                }

                // Third Level
                if((((compute_core_active_stg3 >> cluster_id) & 1) == 1) && (j > 4)){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg3][0], ptr_local_intermidiate_in[itr_stg3][1], data_ptr_target);
                    // Modify metadata
                    data_ptr_target = data_ptr_target + DATA_PER_STAGE;
                    itr_stg3 = itr_stg3 ^ 1;
                }
#else
                // Second Level
                if((((compute_core_active_stg2 >> cluster_id) & 1) == 1) && (j > 2) && (j < (STAGES+3))){
                    // Reduce the first vector together
                    cluster_reduce_array_slice(ptr_local_intermidiate_in[itr_stg2][0], ptr_local_intermidiate_in[itr_stg2][1], data_ptr_target);
                    // Modify metadata
                    data_ptr_target = data_ptr_target + DATA_PER_STAGE;
                    itr_stg2 = itr_stg2 ^ 1;
                }
#endif
            }

            // Sync all cores
            snrt_mcycle();
            snrt_global_barrier();
        }
    }

    // Verify the final result
    return cluster_verify_reduction(cluster_id, buffer_dst);
}
