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

/**
 * @brief Get start address of a memory tile
 * @param tile_idx The memory tile idx in the NoC
 * @return Start addres of memory tile idx
 */
inline uintptr_t pb_l3_tile_address(uint32_t tile_idx) {
    return (uintptr_t) (picobello_addrmap.l2_spm[tile_idx].mem);
}

/**
 * @brief Get the address offset of a data respect to the memory tile start address
 * @param src_addr The data absolute address
 * @return Address location offset respect to the tile start address
 */
inline uintptr_t pb_l3_tile_offset(uintptr_t src_addr) {
    return (src_addr - (uintptr_t)L3_START_ADDRESS) & (uintptr_t)(L3_SIZE - 1);
}


/**
 * @brief Get the NoC row index
 * @param cidx The cluster index
 * @return The Row index
 */
inline uint32_t pb_cluster_row(uint32_t cidx)
{
  return cidx % CLUSTER_PER_ROW;
}

/**
 * @brief Get the NoC row index
 * This is a convenience orload of pb_cluster_row()
 * @return The Row index
 */
inline uint32_t pb_cluster_row()
{
  return pb_cluster_row(snrt_cluster_idx());
}


/**
 * @brief Get the NoC column index
 * @param cidx The cluster index
 * @return The Column index
 */
inline uint32_t pb_cluster_col(uint32_t cidx)
{
  return cidx % CLUSTER_PER_COL;
}

/**
 * @brief Get the NoC column index
 * This is a convenience orload of pb_cluster_row()
 * @return The Column index
 */
inline uint32_t pb_cluster_col()
{
  return pb_cluster_col(snrt_cluster_idx());
}


/**
 * @brief Get the index of the closest memory tile
 * @param cidx The cluster index
 * @return Index of the closest memory tile to cidx
 */
inline uint32_t pb_closest_mem_tile(uint32_t cidx) {
    uint32_t row = pb_cluster_row(cidx);
    return (cidx < 8u) ? row        // first 8 clusters -> left column tiles 0..3
                      : (row + 4u); // clusters >= 8  -> right column tiles 4..7
}

/**
 * @brief Get the index of the closest memory tile
 * This is a convenience orload of pb_closest_mem_tile()
 */
inline uint32_t pb_closest_mem_tile() {
    return pb_closest_mem_tile(snrt_cluster_idx());
}
