// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This test simply read and write from some L2 locations.
// It will read the first uint32 data from each memory bank.
// Each memeory tile is organized as follow:
// - L2Size = 1 MiB
// - NumWordsPerBank = 512
// - DataWidth = 256 bit
// - BankSize = (NumWordsPerBank x DataWidth)/8 = 16 kiB [14 bits shift]
// - NumBanks = L2Size/BankSize = 64 banks (Physical Banks)


#include <stdint.h>
#include "picobello_addrmap.h"

#define WIDE_WORD_WIDTH 512
#define NARROW_WORD_WIDTH sizeof(uint32_t) * 8
#define NUM_L2_MEM_TILES 8
#define L2_MEM_TILE_SIZE sizeof(picobello_addrmap__l2_spm_t) // 1 MiB
#define L2_SRAM_DATA_WIDTH 128
#define L2_SRAM_NUM_WORDS 1024
#define L2_BANKS_PER_WORD (WIDE_WORD_WIDTH / L2_SRAM_DATA_WIDTH) // 4 banks per 512-bit word
#define L2_BANK_ROWS ((L2_MEM_TILE_SIZE / (WIDE_WORD_WIDTH / 8)) / L2_SRAM_NUM_WORDS) // 16 rows per bank

typedef uint32_t l2_mem_t[NUM_L2_MEM_TILES][L2_BANK_ROWS][L2_BANKS_PER_WORD][L2_SRAM_DATA_WIDTH / NARROW_WORD_WIDTH];

int main() {

  volatile l2_mem_t *l2_mem = (volatile l2_mem_t *)&picobello_addrmap.l2_spm;

  uint32_t n_errors = NUM_L2_MEM_TILES * L2_BANK_ROWS * L2_BANKS_PER_WORD * 2; // Total number of writes

  // Write to each physical bank
  // One aligned access, one unaligned access
  for (uint32_t i = 0; i < NUM_L2_MEM_TILES; i++) {
    for (uint32_t j = 0; j < L2_BANK_ROWS; j++) {
      for (uint32_t k = 0; k < L2_BANKS_PER_WORD; k++) {
          (*l2_mem)[i][j][k][0] = i * j * k;
          (*l2_mem)[i][j][k][1] = i * j * k + 1;
      }
    }
  }

  // Read from each physical bank and check if the value is correct:
  for (uint32_t i = 0; i < NUM_L2_MEM_TILES; i++) {
    for (uint32_t j = 0; j < L2_BANK_ROWS; j++) {
      for (uint32_t k = 0; k < L2_BANKS_PER_WORD; k++) {
          n_errors -= ((*l2_mem)[i][j][k][0] == i * j * k);
          n_errors -= ((*l2_mem)[i][j][k][1] == i * j * k + 1);
      }
    }
  }

  return n_errors;
}
