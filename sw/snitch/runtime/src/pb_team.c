// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

extern inline uintptr_t pb_l2_tile_address(uint32_t tile_idx);

extern inline uintptr_t pb_l2_tile_offset(uintptr_t src_addr);

extern inline constexpr uint32_t pb_log2_cluster_num_in_col();

extern inline constexpr uint32_t pb_log2_cluster_num_in_row();

extern inline constexpr uint32_t pb_cluster_num_in_row();

extern inline constexpr uint32_t pb_cluster_num_in_col();

extern inline uint32_t pb_cluster_row_idx(uint32_t cluster_idx);

extern inline uint32_t pb_cluster_row_idx();

extern inline uint32_t pb_cluster_col_idx(uint32_t cluster_idx);

extern inline uint32_t pb_cluster_col_idx();

extern inline uint32_t pb_calculate_cluster_idx(uint32_t row, uint32_t col);

extern inline uint32_t pb_cluster_in_row(uint32_t row);

extern inline uint32_t pb_cluster_in_col(uint32_t col);

extern inline uint32_t pb_cluster_is_easternmost();

extern inline uint32_t pb_cluster_is_northernmost();

extern inline uint32_t pb_cluster_north_neighbour();

extern inline uint32_t pb_cluster_east_neighbour();

extern inline uint32_t pb_cluster_south_neighbour();

extern inline uint32_t pb_cluster_west_neighbour();
    
extern inline uint32_t pb_closest_mem_tile(uint32_t cluster_idx);

extern inline uint32_t pb_closest_mem_tile();
