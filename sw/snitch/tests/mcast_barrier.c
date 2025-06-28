// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This testbench aims to test the multicast feature in the narrow interconnect.
// It exploits the snrt_gloabl_barrier() function to synchronize all the cores
// in the system. Each cluster CLINT reg is written using multicast.

#include <stdint.h>
#include "pb_addrmap.h"
#include "snrt.h"

int main (void) {

	snrt_global_barrier();
	return 0;
}
