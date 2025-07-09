// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This test simply read and write from some SPM locations.
// It will read the first uint32 data from each memory bank.

#include <stdint.h>
#include "pb_addrmap.h"

#define NARROW_WORD_WIDTH 64
#define NARROW_WORD_SIZE (sizeof(uint32_t) * 8)

#define SPM_MEM_TILE_SIZE sizeof(picobello_addrmap__top_spm_narrow_t) // 256 kiB
#define SPM_SRAM_DATA_WIDTH 64
#define SPM_SRAM_NUM_WORDS 2048
#define SPM_BANKS_PER_WORD (NARROW_WORD_WIDTH / SPM_SRAM_DATA_WIDTH) // 4 banks per 512-bit word
#define SPM_BANK_ROWS (SPM_MEM_TILE_SIZE / (NARROW_WORD_WIDTH / 8)) / SPM_SRAM_NUM_WORDS

typedef uint32_t spm_mem_t[SPM_BANK_ROWS][SPM_SRAM_NUM_WORDS][SPM_BANKS_PER_WORD][SPM_SRAM_DATA_WIDTH / NARROW_WORD_SIZE];

static_assert((sizeof(spm_mem_t)) == sizeof(picobello_addrmap__top_spm_narrow_t), "Packing error");

int main() {

  volatile spm_mem_t *spm_mem = (volatile spm_mem_t *)&picobello_addrmap.top_spm_narrow;

  uint32_t n_errors = SPM_BANK_ROWS * SPM_BANKS_PER_WORD * 4; // Total number of writes

  // Write to each physical bank
  // One aligned access, one unaligned access

  for (uint32_t j = 0; j < SPM_BANK_ROWS; j++) {
      for (uint32_t k = 0; k < SPM_BANKS_PER_WORD; k++) {
        (*spm_mem)[j][0][k][0] = j * k;
        (*spm_mem)[j][0][k][1] = j * k + 1;
        (*spm_mem)[j][1][k][0] = j * k + 2;
        (*spm_mem)[j][1][k][1] = j * k + 3;
    }
  }


  // Read from each physical bank and check if the value is correct
  for (uint32_t j = 0; j < SPM_BANK_ROWS; j++) {
    for (uint32_t k = 0; k < SPM_BANKS_PER_WORD; k++) {
        n_errors -= ((*spm_mem)[j][0][k][0] == j * k);
        n_errors -= ((*spm_mem)[j][0][k][1] == j * k + 1);
        n_errors -= ((*spm_mem)[j][1][k][0] == j * k + 2);
        n_errors -= ((*spm_mem)[j][1][k][1] == j * k + 3);
    }
  }

  return n_errors;
}
