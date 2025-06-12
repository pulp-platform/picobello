// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This testbench aims to test multiple non-overlapping multicast requests.
// The following routine is implemented:
//   - Cluster 0 sends multicast to row 0 (Clusters 0, 4, 8, 12)
//   - Cluster 0 sends interrupt to row 0 (Clusters 0, 4, 8, 12)
//   - All clusters in the first row (0, 4, 8, 12) sends multicast to each column
//   - All clusters except for cluster 0 check the multicast result

#include <stdint.h>
#include "picobello_addrmap.h"
#include "snrt.h"

/* Parameters */
#define ROW_MASK 0x00300000
#define COLUMN_MASK 0x000C0000
#define TESTVAL 0xABCD


/* Helper functions */
/**
 * @brief Wake group of clusters via multicast feature.
 *
 * Similar to `snrt_wake_all`, but lets the caller restrict the wake-up
 * to a subset of clusters at a programmable distance from the caller.
 *
 * @param core_mask       Bit-mask of cores to set in the target clusters’
 *                        CLINT-SET register (usually 1 << core_id).
 * @param mask            Multicast mask that selects which clusters receive
 *                        the interrupt.
 * @param cluster_stride  Offset added to the caller’s cluster index to obtain the
 *                        destination cluster.
 *
 */
inline void snrt_wake_clusters(uint32_t core_mask, uint32_t mask, uint32_t cluster_stride) {
    uint32_t* addr = (uint32_t *)snrt_remote_l1_ptr((void*) snrt_cluster_clint_set_ptr(),
                                           snrt_cluster_idx(), snrt_cluster_idx() + cluster_stride);
    snrt_enable_multicast(mask);
    *((uint32_t *)addr) = core_mask;
    snrt_disable_multicast();
}

/**
 * @brief Send multicast request
 *
 * Function to send a multicast request to a subset of clusters.
 *
 * @param dst   Destination address of one of the multicast endpoints
 * @param mask  Multicast mask to encode the multiple destination endpoints
 *
 */
void send_mcast(uint32_t* dst, uint32_t mask){
  snrt_enable_multicast(mask);
  *((uint32_t*)dst) = TESTVAL;
  snrt_disable_multicast();
}


/* Main Function */
int main(){
  uint32_t* mcast_dst   = (uint32_t*)snrt_l1_start_addr();
  uint32_t  row_mask    = ROW_MASK;
  uint32_t  column_mask = COLUMN_MASK;

  snrt_global_barrier();
  if (snrt_cluster_core_idx() == 0){
    // Row multicast
    if (snrt_cluster_idx() == 0){
      // Send multicast data over first row
      mcast_dst = (uint32_t *)snrt_remote_l1_ptr((void*) snrt_l1_start_addr(),
                                           snrt_cluster_idx(), 4);
      send_mcast(mcast_dst, row_mask);

      // Send multicast wake up signal to the first row
      snrt_wake_clusters((1 << snrt_cluster_core_idx()),  row_mask, 4);

      // Send multicast over first column
      mcast_dst = (uint32_t *)snrt_remote_l1_ptr((void*) snrt_l1_start_addr(),
                                           snrt_cluster_idx(), 1);
      send_mcast(mcast_dst, column_mask);
      snrt_wake_clusters((1 << snrt_cluster_core_idx()), column_mask, 1);

    }
    else {
      // All other clusters wait for interrupts
      snrt_wfi();
      // The first row clusters issue a multicast to their own column
      if (snrt_cluster_idx()%4 == 0){
        uint32_t dst_idx = snrt_cluster_idx() + 1;
        mcast_dst = (uint32_t *)snrt_remote_l1_ptr((void*) snrt_l1_start_addr(),
                                           snrt_cluster_idx(), dst_idx);
        send_mcast(mcast_dst, column_mask);
        snrt_wake_clusters((1 << snrt_cluster_core_idx()), column_mask, 1);
      }
      // Once all clusters are awake, they can check the multicast result
      return (*mcast_dst ^ TESTVAL);
    }
  }
    return 0;
}
