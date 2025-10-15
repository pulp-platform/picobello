// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Luca Colagrande <colluca@iis.ee.ethz.ch>

#include "snrt.h"

int main (void) {

    // Create communicator for row 0
    snrt_comm_t comm;
    pb_create_mesh_comm(&comm, 1, pb_cluster_num_in_row());

	// Make sure row-0 clusters arrive on the row-0 barrier only after the
	// other clusters have arrived on the global barrier. This ensures that
	// the global barrier, arriving first, takes ownership of the router,
	// preventing the row-0 clusters from ever reaching the global barrier
	// and consequently deadlocking the system.
	if (pb_cluster_row_idx() == 0) {
		for (int j = 0; j < 100; j++) snrt_nop();
		snrt_global_barrier(comm);
		snrt_global_barrier();
	} else {
		snrt_global_barrier();
	}

	return 0;
}
