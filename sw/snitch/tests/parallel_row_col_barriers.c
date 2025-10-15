// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

#include "snrt.h"

int main (void) {

    // Create communicators for each row and column.
    snrt_comm_t row_comm[pb_cluster_num_in_col()];
	snrt_comm_t col_comm[pb_cluster_num_in_row()];
	for (uint32_t r = 0; r < pb_cluster_num_in_col(); r++) {
		pb_create_mesh_comm(&row_comm[r], 1, pb_cluster_num_in_row(),
			r, 0);
	}
	for (uint32_t c = 0; c < pb_cluster_num_in_row(); c++) {
		pb_create_mesh_comm(&col_comm[c], pb_cluster_num_in_col(), 1,
			0, c);
	}

	// Test multiple barriers in succession (row, col and global)
	for (int i = 0; i < 10; i++) {
		snrt_global_barrier(row_comm[pb_cluster_row_idx()]);
		snrt_global_barrier(col_comm[pb_cluster_col_idx()]);
		snrt_global_barrier();
	}

	return 0;
}
