// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

#include <stdint.h>
#include "picobello_addrmap.h"

// TODO(fischeti): Replace with snitch cluster RDL for this once merged.
#include "snitch_peripheral_addrmap.h"

// This needs to be in a region which is not cached
volatile uint32_t (*return_code_array)[CFG_CLUSTER_NR_CORES] = (uint32_t (*)[CFG_CLUSTER_NR_CORES])0x707FF000;

int main() {

  // Write entry point to scratch register 1
  // and return code address to scratch register 0
  // Initalize return address loaction before offloading.
  for (int i = 0; i < SNRT_CLUSTER_NUM; i++) {
    *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_SCRATCH_ADDR(i, 1)) = picobello_addrmap.l2_spm;
    *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_SCRATCH_ADDR(i, 0)) =
        (uintptr_t)&return_code_array[i];
    for (int j = 0; j < CFG_CLUSTER_NR_CORES; j++) {
      return_code_array[i][j] = 0;
    }
  }

  // Start only Cluster 0 core 0 which will wake up all other clusters
  *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_CLINT_SET_ADDR(0)) = (1 << CFG_CLUSTER_NR_CORES) - 1;

  // Wait until all cores have finished
  int all_finished = 0;
  while (!all_finished) {
    all_finished = 1;
    for (int i = 0; i < SNRT_CLUSTER_NUM; i++) {
      for (int j = 0; j < CFG_CLUSTER_NR_CORES; j++) {
        if ((return_code_array[i][j] & 1) == 0) {
          all_finished = 0;
          break;
        }
      }
    }
  }

  // Sum up the return codes
  uint32_t sum = 0;
  for (int i = 0; i < SNRT_CLUSTER_NUM; i++) {
    for (int j = 0; j < CFG_CLUSTER_NR_CORES; j++) {
      sum += (return_code_array[i][j] >> 1);
    }
  }

  return sum;
}
