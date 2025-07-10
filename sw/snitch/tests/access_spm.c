// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This test simply read and write from some SPM locations.
// It will read the first uint32 data from each memory bank (both aligned and not).
// The read will be performed only by cluster 0:
// The narrow SPM will be accessed by core 0, while teh wide SPM by teh DMA core.

#include <stdint.h>
#include "pb_addrmap.h"
#include "snrt.h"

// Narrow SPM parameters definitions
#define NARROW_WORD_WIDTH 64
#define NARROW_WORD_SIZE (sizeof(uint32_t) * 8)

#define SPM_MEM_TILE_SIZE sizeof(picobello_addrmap__top_spm_narrow_t) // 256 kiB
#define SPM_SRAM_DATA_WIDTH 64
#define SPM_SRAM_NUM_WORDS 2048
#define SPM_BANKS_PER_WORD (NARROW_WORD_WIDTH / SPM_SRAM_DATA_WIDTH) // 1 banks per 64-bit word
#define SPM_BANK_ROWS (SPM_MEM_TILE_SIZE / (NARROW_WORD_WIDTH / 8)) / SPM_SRAM_NUM_WORDS

// Wide SPM parameters definitions
#define WIDE_WORD_WIDTH 512
#define SPM_SRAM_WIDE_DATA_WIDTH 128
#define SPM_SRAM_WIDE_NUM_WORDS 1024
#define SPM_BANKS_PER_WIDE_WORD (WIDE_WORD_WIDTH / SPM_SRAM_WIDE_DATA_WIDTH) // 4 banks per 512-bit word
#define SPM_BANK_WIDE_ROWS (SPM_MEM_TILE_SIZE / (WIDE_WORD_WIDTH / 8)) / SPM_SRAM_WIDE_NUM_WORDS
#define WIDE_TRANSFER_LENGTH 2 * (WIDE_WORD_WIDTH / 8) / sizeof(uint32_t) // Number of 32-bit words in a wide word

// Array type definitions to map the SPM memory layout
typedef uint32_t spm_mem_t[SPM_BANK_ROWS][SPM_SRAM_NUM_WORDS][SPM_BANKS_PER_WORD][SPM_SRAM_DATA_WIDTH / NARROW_WORD_SIZE];

typedef uint32_t spm_wide_mem_t[SPM_BANK_WIDE_ROWS][SPM_SRAM_WIDE_NUM_WORDS][SPM_BANKS_PER_WIDE_WORD][SPM_SRAM_WIDE_DATA_WIDTH / NARROW_WORD_SIZE];

static_assert((sizeof(spm_mem_t)) == sizeof(picobello_addrmap__top_spm_narrow_t), "Packing error");
static_assert((sizeof(spm_wide_mem_t)) == sizeof(picobello_addrmap__top_spm_wide_t), "Packing error");


// Test accessability to the NARROW SPM Tile
uint32_t test_narrow_spm (){
  volatile spm_mem_t *spm_mem = (volatile spm_mem_t *)&picobello_addrmap.top_spm_narrow;
  uint32_t n_errors = SPM_BANK_ROWS * SPM_BANKS_PER_WORD * 4; // Total number of writes

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


// Test accessability to the WIDE SPM Tile
// Performs two write operations directed to the first and second word
// of each physical bank, and then reads them back to check if the values are correct.
uint32_t test_wide_spm (){
  volatile spm_wide_mem_t *spm_wide_mem = (volatile spm_wide_mem_t *)&picobello_addrmap.top_spm_wide;
  uint32_t* buf_src     = (uint32_t*) snrt_l1_alloc_cluster_local(WIDE_TRANSFER_LENGTH * sizeof(uint32_t), sizeof(uint32_t));
  uint32_t* buf_res_al  = (uint32_t*) snrt_l1_alloc_cluster_local(WIDE_TRANSFER_LENGTH * sizeof(uint32_t), sizeof(uint32_t));
  uint32_t* buf_res_nal = (uint32_t*) snrt_l1_alloc_cluster_local(WIDE_TRANSFER_LENGTH * sizeof(uint32_t), sizeof(uint32_t));
  uint32_t ret_val = 0;

  for (int i = 0; i < WIDE_TRANSFER_LENGTH; i++) {
    buf_src[i]      = i;
    buf_res_al[i]   = WIDE_TRANSFER_LENGTH;
    buf_res_nal[i]  = 2 * WIDE_TRANSFER_LENGTH;
  }
  // Write aligned and not data to the wide SPM
  for (int i = 0; i < SPM_BANK_WIDE_ROWS; i++) {
    snrt_dma_start_1d((volatile void*) &(*spm_wide_mem)[i][0][0][0], buf_src, WIDE_TRANSFER_LENGTH * sizeof(uint32_t));
    snrt_dma_wait_all();
    snrt_dma_start_1d((volatile void*) &(*spm_wide_mem)[i][2][1][0], buf_src, WIDE_TRANSFER_LENGTH * sizeof(uint32_t));
    snrt_dma_wait_all();
  }

  // Since there is not narrow slave port on the wide SPM tile,
  // read operations can be performed only using DMA transfer to local TCDM
  // and then checking from there.
  for (int i = 0; i < SPM_BANK_WIDE_ROWS; i++) {
    snrt_dma_start_1d(buf_res_al, (volatile void*) &(*spm_wide_mem)[i][0][0][0],  WIDE_TRANSFER_LENGTH * sizeof(uint32_t));
    snrt_dma_wait_all();
    snrt_dma_start_1d(buf_res_nal, (volatile void*) &(*spm_wide_mem)[i][2][1][0],  WIDE_TRANSFER_LENGTH * sizeof(uint32_t));
    snrt_dma_wait_all();
  }
  for (int i = 0; i < WIDE_TRANSFER_LENGTH; i++) {
    ret_val |= (buf_res_al[i]  ^ i);
    ret_val |= (buf_res_nal[i] ^ i);
  }
  return ret_val;
}


int main() {
  uint32_t ret_val = 0;

  if (snrt_cluster_idx() == 0) {
    // Test Narrow SPM: Core 0
    if (snrt_cluster_core_idx() == 0) {
      ret_val |= test_narrow_spm();
    }
    // Test Wide SPM: DMA Core
    else if (snrt_is_dm_core()) {
      ret_val = test_wide_spm();
    }
  }

  return ret_val;
}
