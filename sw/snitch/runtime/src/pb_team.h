// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
// Luca Colagrande <colluca@iis.ee.ethz.ch>

/**
 * @file
 * @brief This file contains functions and macros related to Picobello team
 * management.
 */

/**
 * @brief Get start address of a memory tile
 * @param tile_idx The memory tile idx in the NoC
 * @return Start addres of memory tile idx
 */
inline uintptr_t pb_l2_tile_address(uint32_t tile_idx) {
    return (uintptr_t) (picobello_addrmap.l2_spm[tile_idx].mem);
}

/**
 * @brief Get the address offset of a data respect to the memory tile start address
 * @param src_addr The data absolute address
 * @return Address location offset respect to the tile start address
 */
inline uintptr_t pb_l2_tile_offset(uintptr_t src_addr) {
    return (src_addr - PICOBELLO_ADDRMAP_L2_SPM_0_BASE_ADDR) %
        PICOBELLO_ADDRMAP_L2_SPM_0_SIZE;
}

/**
 * @brief Get the log2 of the number of clusters in a row
 */
 inline constexpr uint32_t pb_log2_cluster_num_in_row() {
    // TODO(colluca): derive this from pb_cluster_num_in_row() or viceversa
    return 2;
}

/**
 * @brief Get the log2 of the number of clusters in a column
 */
inline constexpr uint32_t pb_log2_cluster_num_in_col() {
    // TODO(colluca): derive this from pb_cluster_num_in_col() or viceversa
    return 2;
}

/**
 * @brief Get the number of clusters in a row
 */
inline constexpr uint32_t pb_cluster_num_in_row() {
    return PB_CLUSTER_PER_ROW;
}

/**
 * @brief Get the number of clusters in a column
 */
inline constexpr uint32_t pb_cluster_num_in_col() {
    return PB_CLUSTER_PER_COL;
}

/**
 * @brief Get the row index of a cluster
 * @param cluster_idx The cluster index
 * @return The row index relative to the first row of cluster tiles
 */
inline uint32_t pb_cluster_row_idx(uint32_t cluster_idx)
{
    return cluster_idx % pb_cluster_num_in_col();
}

/**
 * @brief Get the row index of the invoking cluster
 * @return The row index relative to the first row of cluster tiles
 */
inline uint32_t pb_cluster_row_idx()
{
    return pb_cluster_row_idx(snrt_cluster_idx());
}

/**
 * @brief Get the column index of a cluster
 * @param cluster_idx The cluster index
 * @return The column index relative to the first column of cluster tiles
 */
inline uint32_t pb_cluster_col_idx(uint32_t cluster_idx)
{
    return cluster_idx / pb_cluster_num_in_col();
}

/**
 * @brief Get the column index of the invoking cluster
 * @return The column index relative to the first column of cluster tiles
 */
inline uint32_t pb_cluster_col_idx()
{
    return pb_cluster_col_idx(snrt_cluster_idx());
}

/**
 * @brief Calculate the cluster index from its (row, col) coordinates
 * @param row Row index relative to the first row of cluster tiles
 * @param col Column index relative to the first column of cluster tiles
 */
inline uint32_t pb_calculate_cluster_idx(uint32_t row, uint32_t col) {
    return col * pb_cluster_num_in_col() + row;
}

/**
 * @brief Test if cluster is in a given row
 * @param row Row index relative to the first row of cluster tiles
 */
inline uint32_t pb_cluster_in_row(uint32_t row) {
    return pb_cluster_row_idx() == row;
}

/**
 * @brief Test if cluster is in a given column
 * @param col Column index relative to the first column of cluster tiles
 */
inline uint32_t pb_cluster_in_col(uint32_t col) {
    return pb_cluster_col_idx() == col;
}

/**
 * @brief Get cluster index of north neighbour
 */
inline uint32_t pb_cluster_north_neighbour() {
    return snrt_cluster_idx() + 1;
}

/**
 * @brief Get cluster index of east neighbour
 */
inline uint32_t pb_cluster_east_neighbour() {
    return snrt_cluster_idx() + pb_cluster_num_in_row();
}

/**
 * @brief Get cluster index of south neighbour
 */
inline uint32_t pb_cluster_south_neighbour() {
    return snrt_cluster_idx() - 1;
}

/**
 * @brief Get cluster index of west neighbour
 */
inline uint32_t pb_cluster_west_neighbour() {
    return snrt_cluster_idx() - pb_cluster_num_in_row();
}

/**
 * @brief Get the index of the closest memory tile
 * @param cluster_idx The cluster index
 * @return Index of the closest memory tile to cluster_idx
 */
inline uint32_t pb_closest_mem_tile(uint32_t cluster_idx) {
    uint32_t row = pb_cluster_row_idx(cluster_idx);
    // e.g. with 4x4 matrix
    // first 8 clusters -> left column tiles 0..3
    // clusters >= 8 -> right column tiles 4..7
    return (cluster_idx < (snrt_cluster_num() / 2)) ?
        row : (row + PB_CLUSTER_PER_COL);
}

/**
 * @brief Get the index of the closest memory tile
 * This is a convenience overload of pb_closest_mem_tile()
 */
inline uint32_t pb_closest_mem_tile() {
    return pb_closest_mem_tile(snrt_cluster_idx());
}
