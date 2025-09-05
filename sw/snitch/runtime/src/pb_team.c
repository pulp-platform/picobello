// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

extern uintptr_t l3_tile_address(uint32_t tile_idx);

extern inline uintptr_t l3_tile_offset(uintptr_t src_addr);

extern inline uint32_t cluster_row(uint32_t cidx);

extern inline uint32_t cluster_col(uint32_t cidx);

extern inline uint32_t dst_tile_for_cluster(uint32_t cidx);
