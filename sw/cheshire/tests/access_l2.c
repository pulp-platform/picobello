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

#define TESTVAL 0xABCD9876
#define BANKS_SIZE 0x00004000
#define NUM_L2_LOG_BANKS 2
#define NUM_L2_BANK_PER_ROW 32
#define MISALIGNED_ADDR 0x04
#define L2_WRITE_ADDR (PB_L2_BASE_ADDR + MISALIGNED_ADDR)

int main() {
  volatile uint32_t *l2ptr = (volatile uint32_t *)L2_WRITE_ADDR;
  volatile uint32_t result;

  // Write TESTVAL to each physical bank:
  for (int phyBank = 0; phyBank < NUM_L2_BANK_PER_ROW; phyBank++) {
    for (int logBank = 0; logBank < NUM_L2_LOG_BANKS; logBank++) {
      l2ptr = (volatile uint32_t *)((uintptr_t)L2_WRITE_ADDR +
                                    (phyBank << 15) + (logBank << 5));
      *(l2ptr ) = TESTVAL;
    }
  }

  // Read back and verify TESTVAL in each bank:
  l2ptr = (volatile uint32_t *)L2_WRITE_ADDR;
  for (int phyBank = 0; phyBank < NUM_L2_BANK_PER_ROW; phyBank++) {
    for (int logBank = 0; logBank < NUM_L2_LOG_BANKS; logBank++) {
      l2ptr = (volatile uint32_t *)((uintptr_t)L2_WRITE_ADDR +
                                    (phyBank << 15) + (logBank << 5));
      result = *(l2ptr);
      if (result != TESTVAL) {
        return 1;
      }
    }
  }

  return 0;
}
