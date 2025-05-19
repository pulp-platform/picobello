// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This testbench aims to test the multicast feature in the narrow interconnect.
// It exploits the snrt_inter_cluster_barrier() function to synchronize all the cores
// in the system. The wakeup signal is sent using the multicast feature.

#include <stdint.h>
#include "picobello_addrmap.h"
#include "snrt.h"

int main (void) {

snrt_int_clr_mcip();
uint32_t core_id = snrt_cluster_core_idx();
	if (core_id != 0) {
		return 0;
	}

	if (snrt_cluster_idx() != 0) {
		snrt_wfi();
		return 0;
	}

	// TODO(lleone): Can you simply do addr `uintptr_t addr = (uintptr_t) CLUSTER_CLINT_SET_ADDR`
	uintptr_t addr = (uintptr_t)snrt_cluster_clint_set_ptr() - SNRT_CLUSTER_OFFSET * snrt_cluster_idx();
	// TODO(lleone): Can you remove the if condition?
  if (snrt_cluster_idx() == 0) addr += SNRT_CLUSTER_OFFSET;
 	snrt_enable_multicast(BCAST_MASK_ALL);
  *((uint32_t *)addr) = 1;
  snrt_disable_multicast();
	// if (core_id == 0) {
	// 	snrt_inter_cluster_barrier();
	// }
	return 0;
}