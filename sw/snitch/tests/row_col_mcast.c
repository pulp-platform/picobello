// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This testbench aims to test multiple multicast transactions.
// Each cluster in column 0 sends a multicast request to all clusters in the same row.
// Each cluster in row 0 sends a multicast request to all clusters in the same column.

#include <stdint.h>
#include "picobello_addrmap.h"
#include "snrt.h"

/* Parameters */
#define ROW_MASK    0x00300000
#define COLUMN_MASK 0x000C0000
#define ROW_INIT    0x9999
#define COLUMN_INIT 0xEEEE
#define TESTVAL     0xABCD

#define LENGTH 1024
#define LENGTH_TO_CHECK 1024

/* Helper functions */
void send_mcast(uint32_t* dst, uint32_t mask){
  snrt_enable_multicast(mask);
  *((uint32_t*)dst) = TESTVAL;
  snrt_disable_multicast();
}

// Function to issue multicast DMA requests
static inline void dma_broadcast_to_clusters(void* dst, void* src, size_t size, uint32_t mask) {
    if (snrt_is_dm_core()) {
        snrt_dma_start_1d_mcast(dst, src, size, mask);
        snrt_dma_wait_all();
    }
}

void issue_dma_mcast(uint32_t *buffer_src, uint32_t *buffer_dst, uint32_t cluster_offset, uint32_t mcast_mask) {
  uint32_t* mcast_dst = (uint32_t *)snrt_remote_l1_ptr((void*) buffer_dst,
                                                 snrt_cluster_idx(), snrt_cluster_idx() + cluster_offset);
  uint32_t* mcast_src = buffer_src;
  dma_broadcast_to_clusters(mcast_dst, mcast_src, LENGTH * sizeof(uint32_t), mcast_mask);
}


// Function to issue multicast request over the full row
void issue_mcast_row(uint32_t *buffer_src, uint32_t *buffer_dst) {
  issue_dma_mcast(buffer_src, buffer_dst, 4, ROW_MASK);
}

// Function to issue multicast request over the full column
void issue_mcast_column(uint32_t *buffer_src, uint32_t *buffer_dst) {
  issue_dma_mcast(buffer_src, buffer_dst, 1, COLUMN_MASK);
}


/* Main Function */
int main() {

  uint32_t ret_val = 0;

  snrt_global_barrier();

  if (snrt_is_dm_core()){

    // Each cluster allocates 3 buffers in L1 memory: SOURCE, DESTINATION ROW, DESTINATION COLUMN
    uint32_t* buf_src         = snrt_l1_alloc_cluster_local(LENGTH * sizeof(uint32_t), sizeof(uint32_t));
    uint32_t* buf_dst_row     = snrt_l1_alloc_cluster_local(LENGTH * sizeof(uint32_t), sizeof(uint32_t));
    uint32_t* buf_dst_column  = snrt_l1_alloc_cluster_local(LENGTH * sizeof(uint32_t), sizeof(uint32_t));

    // Run twice to heat the cache
    for (volatile int i = 0; i < 2; i++){
      // Initialize src buffer in all dst clusters involved in the transfer
      for (int i = 0; i < LENGTH; i++) {
        buf_src[i]        = TESTVAL;
        buf_dst_row[i]    = ROW_INIT;
        buf_dst_column[i] = COLUMN_INIT;
      }
      snrt_inter_cluster_barrier();

      // Send multicast transactions
      if (snrt_cluster_idx() < 4) issue_mcast_row(buf_src, buf_dst_row);
      else if (snrt_cluster_idx() % 4 == 0) issue_mcast_column(buf_src, buf_dst_column);
    }

    snrt_inter_cluster_barrier();

    // Check results of multicast writes
    if (snrt_cluster_idx() != 0){
      for (int i = 0; i < LENGTH_TO_CHECK; i++) {
        if (snrt_cluster_idx() > 3) {
          ret_val |= (buf_dst_row[i] ^ TESTVAL);
          if (snrt_cluster_idx() % 4 != 0) {
            ret_val |= (buf_dst_column[i] ^ TESTVAL);
          }
        }
      }
    }
  }
    return ret_val;
}
