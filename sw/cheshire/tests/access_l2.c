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

#define NUM_L2_MEM_TILES 8
#define L2_BANK_SIZE 0x4000 // 16 KiB

int main() {

  const uint32_t L2_MEM_TILE_SIZE = sizeof(picobello_addrmap__l2_spm_t);
  const uint32_t NUM_BANKS_PER_L2_MEM_TILE = L2_MEM_TILE_SIZE / L2_BANK_SIZE; // 64 banks

  uint32_t n_errors = 2 * NUM_L2_MEM_TILES * NUM_BANKS_PER_L2_MEM_TILE;

  // Write TESTVAL to each physical bank:
  for (uint32_t i = 0; i < NUM_L2_MEM_TILES; i++) {
    for (uint32_t j = 0; j < NUM_BANKS_PER_L2_MEM_TILE; j++) {
      volatile uint32_t *ptr = &picobello_addrmap.l2_spm[i].mem[j * (L2_BANK_SIZE / sizeof(uint32_t))];
      // Write to aligned and miss-aligned location
      *(ptr) = i + j;
      *(ptr + 1) = i + j + 1;
    }
  }

  for (uint32_t i = 0; i < NUM_L2_MEM_TILES; i++) {
    for (uint32_t j = 0; j < NUM_BANKS_PER_L2_MEM_TILE; j++) {
      volatile uint32_t *ptr = &picobello_addrmap.l2_spm[i].mem[j * (L2_BANK_SIZE / sizeof(uint32_t))];
      // Reade from aligned and miss-aligned location
      n_errors -= (*(ptr) == i + j);
      n_errors -= (*(ptr + 1) == i + j + 1);
    }
  }

  return n_errors;
}
