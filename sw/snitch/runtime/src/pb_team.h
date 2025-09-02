// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>


/**
 * @file
 * @brief This file contains functions and macros related to Picobello team
 * management.
 *
 * The functions in this file provide information about the Snitch hardware
 * configuration, such as the number of clusters, cores per cluster, and the
 * current core's index within the system. These functions can be used for team
 * management and core-specific operations.
 */

// TODO (lleone): Chekc if these functions can be difend as static

/**
 * @brief Get start address of a memory tile
 * @param tile_idx The memory tile idx in the NoC
 * @return Start addres of memory tile idx
 */
inline uintptr_t l3_tile_address(uint32_t tile_idx) {
    return (uintptr_t)L3_START_ADDRESS +
           (uintptr_t)tile_idx * (uintptr_t)L3_SIZE;
}

/**
 * @brief Get the address offset of a data respect to the memory tile start address
 * @param src_addr The data absolute address
 * @return Address location offset respect to the tile start address
 */
inline uintptr_t l3_tile_offset(uintptr_t src_addr) {
    return (src_addr - (uintptr_t)L3_START_ADDRESS) & (uintptr_t)(L3_SIZE - 1);
}

/**
 * @brief Get the NoC row index
 * @param cidx The cluster index
 * @return The Row index
 */
inline uint32_t cluster_row(uint32_t cidx)
{
  return cidx % CLUSTER_PER_ROW;
}

/**
 * @brief Get the NoC column index
 * @param cidx The cluster index
 * @return The Column index
 */
inline uint32_t cluster_col(uint32_t cidx)
{
  return cidx % CLUSTER_PER_COL;
}

inline uint32_t dst_tile_for_cluster(uint32_t cidx) {
    uint32_t row = cluster_row(cidx);
    return (cidx < 8u) ? row        // first 8 clusters -> left column tiles 0..3
                      : (row + 4u); // clusters >= 8  -> right column tiles 4..7
}
