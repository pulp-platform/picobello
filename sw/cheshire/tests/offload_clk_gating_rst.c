// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

#include <stdint.h>
#include "picobello_addrmap.h"

// This needs to be in a region which is not cached
volatile uint32_t (*return_code_array)[CFG_CLUSTER_NR_CORES] = (uint32_t (*)[CFG_CLUSTER_NR_CORES])0x70008000;

int main() {
  // Control register addresses for clock gating and reset
  volatile uint32_t *cluster_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_CLUSTER_CLK_EN_ADDR;    // 16b
  volatile uint32_t *mem_tile_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_MEM_TILE_CLK_EN_ADDR;  // 8b
  volatile uint32_t *fhg_spu_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_FHG_SPU_CLK_EN_ADDR;    // 1b
  volatile uint32_t *cluster_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_CLUSTER_RST_N_ADDR;      // 16b
  volatile uint32_t *mem_tile_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_MEM_TILE_RST_N_ADDR;    // 8b
  volatile uint32_t *fhg_spu_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_FHG_SPU_RST_N_ADDR;      // 1b

  // Enable clock gating and disable reset for all tiles
  *(cluster_clk_en_reg_ptr) = 0x0000FFFF;
  *(mem_tile_clk_en_reg_ptr) = 0x000000FF;
  *(fhg_spu_clk_en_reg_ptr) = 0x00000001;
  *(cluster_rst_n_reg_ptr) = 0x0000FFFF;
  *(mem_tile_rst_n_reg_ptr) = 0x000000FF;
  *(fhg_spu_rst_n_reg_ptr) = 0x00000001;

  // TODO cdurrer: delete (test bypass for clk gating and reset)
  //   *(cluster_clk_en_reg_ptr) = 0x00000000;
  // *(mem_tile_clk_en_reg_ptr) = 0x00000000;
  // *(fhg_spu_clk_en_reg_ptr) = 0x00000000;
  // *(cluster_rst_n_reg_ptr) = 0x0000FFFF;
  // *(mem_tile_rst_n_reg_ptr) = 0x000000FF;
  // *(fhg_spu_rst_n_reg_ptr) = 0x00000001;

  // Write entry point to scratch register 1
  // and return code address to scratch register 0
  // Initalize return address loaction before offloading.
  for (int i = 0; i < SNRT_CLUSTER_NUM; i++) {
    *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_SCRATCH_ADDR(i, 1)) = PB_L2_BASE_ADDR;
    *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_SCRATCH_ADDR(i, 0)) =
        (uintptr_t)&return_code_array[i];
    for (int j = 0; j < CFG_CLUSTER_NR_CORES; j++) {
      return_code_array[i][j] = 0;
    }
  }

  // Start all cores by setting the clint interrupt
  for (int i = 0; i < SNRT_CLUSTER_NUM; i++) {
    *(volatile uint32_t *)((uintptr_t)PB_SNITCH_CL_CLINT_SET_ADDR(i)) = (1 << CFG_CLUSTER_NR_CORES) - 1;
  }

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
