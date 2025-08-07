// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>
// Lorenzo Leone   <lleone@iis.ee.ethz.ch>
//
// This code tests the multicast feature of the wide interconnect.
// It uses the DMA to broadcast chunks of data to different clusters
// in the Picobello system.
//
// Extension: 30-07-25
// The code can now be used to run microbenchamrk and check the multicast
// feature performance. The test support different software implemenation
// to multicast some DMA trasnefers over multiple clusters in the Picobello
// system. By driving some parameters externally, it's possible to get
// the performance results.
//
// Comment:
// The use of WFI and global_barrier together can create some issues due to
// non unique CLINT signal mapping. A possibility would be not to send the
// clusters into WFI, however this will create complicances in teh wake up routine.
// For instance, each cluster would nee to poll the DMA transfer detsination
// until teh expected value is written, and only then it can move to the next
// algorithm step. However, since the code is run twice to pre-heat the cache,
// in the second iteration each cluster will already have the expected results
// and will start the transfer immediately.

#include <stdint.h>
#include "pb_addrmap.h"
#include "snrt.h"

#define INITIALIZER 0xAAAAAAAA

typedef enum {
    SW_UNOPT,
    SW_OPT,
    SW_OPT2,
    HW_MCAST
} mode_t;

// Run experiments with and without multicast support
#ifndef MODE
#define MODE SW_UNOPT
#endif

// Transfer LENGTH in uint32_t elements
#ifndef TRAN_LEN
#define TRAN_LEN 1024
#endif

#define LENGTH_TO_CHECK 32

#ifndef N_CLUSTERS_TO_USE
#define N_CLUSTERS_TO_USE 8
#endif

#define LOG2_COL 2
#define LOG2_ROW 2

#define BCAST_MASK_ACTIVE ((N_CLUSTERS_TO_USE - 1) << 18)

#define cluster_is_in_column(col) \
    __cluster_is_in_column_api((col) - 1)

static inline int __cluster_is_in_column_api(int col){
    return ((snrt_cluster_idx() >> LOG2_ROW) == col);
}

//-------------------
//| Mcast functions |
//-------------------
//
// HW_MCAST: Broadcast from cluster_idx to all mcast destinations (only power of 2 dst supported)
static inline void cluster_broadcast_hw(uint32_t cluster_idx, void* dst, void* src, size_t size) {
    if (snrt_is_dm_core() && (snrt_cluster_idx() == cluster_idx)) {
        snrt_dma_start_1d_mcast(snrt_remote_l1_ptr(dst, 0, 1), src, size, BCAST_MASK_ACTIVE);
        snrt_dma_wait_all();
    }
}


// SW_UNOPT: Unoptimized software version. Cluster_idx initiates multiple DMA transfers to each destination
static inline void cluster_broadcast_sw_unopt(uint32_t cluster_idx, void* dst, void* src, size_t size) {
    if (snrt_is_dm_core() && (snrt_cluster_idx() == cluster_idx)) {
        for (int cl = 0; cl < N_CLUSTERS_TO_USE; cl++) {
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, cl), src, size);
            snrt_dma_wait_all();
        }
    }
}


// SW_OPT: Cluster 0 broadcast over the first column, then each cluster in the first column
// broadcast over its own row
static inline void cluster_broadcast_sw_opt(uint32_t cluster_idx, void* dst, void* src, size_t size) {
    if (snrt_is_dm_core() && (snrt_cluster_idx() == cluster_idx)) {
        for (int row_cl = 0; row_cl < 4; row_cl ++){
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, row_cl), src, size);
            snrt_dma_wait_all();
        }
        // Wait completion of all the transfer to then wakeup the clusters in col 0
        // In this benchmark setup, it's okay to wake up all clusters in a col together,
        // because they'll issue multicast requests on their row without creating
        // crossing paths between multicast transactions and therefore without creating
        // any network congestion that might affect the final results.

        // Wake up clusters in col 0
        if (N_CLUSTERS_TO_USE > 4) {
            for (int row_cl = 1; row_cl < 4; row_cl ++){
               snrt_cluster(row_cl)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }
        }
        // Send data from cluster 0 to row 0
        for (int col_cl = 1; col_cl < N_CLUSTERS_TO_USE/4; col_cl ++){
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, col_cl * 4),
                                src, size);
            snrt_dma_wait_all();
        }
    } else if (snrt_is_dm_core() && cluster_is_in_column(1) && N_CLUSTERS_TO_USE > 4) {
        // The clusters in the first column will wait to be waked up by cluster 0
        // and only then will isue the multicast transaction to the row
        snrt_wfi();
        snrt_int_clr_mcip();
        // Send data to each row
        for (int col_cl = 1; col_cl < N_CLUSTERS_TO_USE/4; col_cl ++){
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, snrt_cluster_idx(), snrt_cluster_idx() + col_cl * 4),
                                dst, size);
            snrt_dma_wait_all();
        }
    }
}

// SW_OPT2: to maximize the paralle work, cluster 0 multicast to cluster 2,
// then simultaneously cluster 0 and 2 multicast to 1 and 3 respectively.
// The same strided approach is used column-wise.
// This approach is afster for NUM_CLUSTERS = 16 only.
// or this reason the following code is not generic enough to handle NUM_CLUSTERS < 16.
static inline void cluster_broadcast_sw_opt2(uint32_t cluster_idx, void* dst, void* src, size_t size) {

    if (snrt_is_dm_core() && (snrt_cluster_idx() == cluster_idx)) {
        // DMA transfer to cluster 0
        snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, 0), src, size);
        snrt_dma_wait_all();

        // DMA transfer to cluster 2 anf then wake up and move one
        snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, 2), src, size);
        snrt_dma_wait_all();
        snrt_cluster(2)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;

        // DMA transfer to cluster 1 and then wake up and move to the row
        snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, 1), src, size);
        snrt_dma_wait_all();
        // WWake up cluster 1 only if you need a second iteration for the next column
        if (N_CLUSTERS_TO_USE > 4){
            snrt_cluster(1)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }

        if (N_CLUSTERS_TO_USE > 8){
            // DMA transfer to cluster 8 and then wake up and move to 4
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, 8), src, size);
            snrt_dma_wait_all();
            snrt_cluster(8)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }

        if (N_CLUSTERS_TO_USE > 4) {
            // DMA transfer to cluster 4. No need to wake it up now since
            // it is not involved in any transfer
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, 0, 4), src, size);
            snrt_dma_wait_all();
        }

    } else if (snrt_is_dm_core() && cluster_is_in_column(1)) {
        // The clusters in the first column will wait to be waked up by cluster 0
        // and only then will isue the multicast transaction to the row
        if (N_CLUSTERS_TO_USE > 4 || snrt_cluster_idx() == 2) {
            snrt_wfi();
            snrt_int_clr_mcip();
        }

        // Only cluster 2 is repsonsible to transfer also to cluster 3
        if (snrt_cluster_idx() == 2) {
            // DMA transfer to cluster 8 and then wake up and move to 4
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, snrt_cluster_idx(), snrt_cluster_idx() + 1), dst, size);
            snrt_dma_wait_all();
            snrt_cluster(snrt_cluster_idx() + 1)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }

        if (N_CLUSTERS_TO_USE > 8){
            // All clusters in the first column need to send the data with
            // a stride of 8 first and 4 after.
            // DMA transfer to cluster 8 and then wake up and move to 4
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, snrt_cluster_idx(), snrt_cluster_idx() + 8), dst, size);
            snrt_dma_wait_all();
            snrt_cluster(snrt_cluster_idx() + 8)->peripheral_reg.cl_clint_set.f.cl_clint_set = 0x1ff;
        }

        if (N_CLUSTERS_TO_USE > 4) {
            // Then the clusters in the first column can send the transfer with stride 4,
            // i.e. to the cluster in he same row but next column.
            snrt_dma_start_1d(snrt_remote_l1_ptr(dst, snrt_cluster_idx(), snrt_cluster_idx() + 4), dst, size);
            snrt_dma_wait_all();
        }


    } else if (snrt_is_dm_core() && cluster_is_in_column(3) && N_CLUSTERS_TO_USE > 8) {
        // The clusters in the column 3 will wait to be waked up by cluster
        // and only then will isue the multicast transaction to the row
        snrt_wfi();
        snrt_int_clr_mcip();

        snrt_dma_start_1d(snrt_remote_l1_ptr(dst, snrt_cluster_idx(), snrt_cluster_idx() + 4), dst, size);
        snrt_dma_wait_all();
    }
}


static inline void dma_broadcast_to_clusters(void* dst, void* src, size_t size) {
    switch (MODE) {
        case HW_MCAST:
        default:
            cluster_broadcast_hw(0, dst, src, size);
            break;
        case SW_UNOPT:
            cluster_broadcast_sw_unopt(0, dst, src, size);
            break;
        case SW_OPT:
            cluster_broadcast_sw_opt(0, dst, src, size);
            break;
        case SW_OPT2:
            cluster_broadcast_sw_opt2(0, dst, src, size);
            break;
    }
}


static inline int cluster_participates_in_bcast(int i) {
    return (i < N_CLUSTERS_TO_USE);
}

static inline void broadcast_wrapper(void* dst, void* src, size_t size) {
    snrt_global_barrier();
    snrt_mcycle();
    dma_broadcast_to_clusters(dst, src, size);
    snrt_mcycle();
}

//
//
int main() {
    snrt_interrupt_enable(IRQ_M_CLUSTER);
    snrt_int_clr_mcip();

    // Allocate destination buffer
    uint32_t *buffer_dst = (uint32_t *)snrt_l1_next_v2();

    // ALlocate source buffer. To avoid multicast conflictr in the Multicast
    // capable AXI Xbar inside each cluster, the source will be a location in
    // the memory tile (L3).
    // To have better contorl of the DMA transfers triggerred for a given LENGTH,
    // align the src pointer to 4kiB, since whenever the src address cross the
    // 4kiB section, the DMA will issue multiple transfers.
    uintptr_t raw_buffer_src = (uintptr_t) snrt_l3_next_v2();
    uintptr_t aligned_addr = (raw_buffer_src + 4095) & ~(uintptr_t)(4095);  // Align to 4 KiB
    uint32_t *buffer_src = (uint32_t *)aligned_addr;


    // Every cluster initializes its destination buffer.
    if (snrt_is_dm_core()) {
        snrt_dma_start_1d(buffer_dst, snrt_cluster()->zeromem.mem, LENGTH * sizeof(uint32_t));
        snrt_dma_wait_all();
    }

    // Synchronize all clusters.
    snrt_global_barrier();

    // First cluster initializes the source buffer and multicast-
    // copies it to the destination buffer in every cluster's TCDM.
    if (snrt_is_dm_core() && (snrt_cluster_idx() == 0)) {
        for (uint32_t i = 0; i < TRAN_LEN; i++) {
            buffer_src[i] = INITIALIZER;
        }
    }

    // Initiate DMA transfer (twice to preheat the cache)
    for (volatile int i = 0; i < 2; i++) {
        broadcast_wrapper(buffer_dst, buffer_src, TRAN_LEN * sizeof(uint32_t) );
    }

    // All other clusters wait on a global barrier to signal the transfer
    // completion.
    snrt_global_barrier();

    // Every cluster except cluster 0 checks that the data in the destination
    // buffer is correct. To speed this up we only check the first 32 elements.
    if (snrt_is_dm_core() && (snrt_cluster_idx() < N_CLUSTERS_TO_USE) && (snrt_cluster_idx() != 0)) {
        uint32_t n_errs = LENGTH_TO_CHECK;
        for (uint32_t i = 0; i < LENGTH_TO_CHECK; i++) {
            if (buffer_dst[i] == INITIALIZER) n_errs--;
        }
        return n_errs;
    } else
        return 0;
  }
