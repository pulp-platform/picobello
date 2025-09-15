// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

extern inline uintptr_t pb_l2_tile_address(uint32_t tile_idx);

extern inline uintptr_t pb_l2_tile_offset(uintptr_t src_addr);

extern inline uint32_t pb_cluster_row(uint32_t cidx);

extern inline uint32_t pb_cluster_row();

extern inline uint32_t pb_cluster_col(uint32_t cidx);

extern inline uint32_t pb_cluster_col();

extern inline uint32_t pb_closest_mem_tile(uint32_t cidx);

extern inline uint32_t pb_closest_mem_tile();
