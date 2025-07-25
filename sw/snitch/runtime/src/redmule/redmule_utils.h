// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

#pragma once

#define ERR 0x0011

static inline int redmule16_compare_int(uint32_t *actual_z, uint32_t *golden_z, int len) {
  uint32_t actual_word = 0;
  uint16_t actual_MSHWord, actual_LSHWord;
  uint32_t golden_word = 0;
  uint16_t golden_MSHWord, golden_LSHWord;
  uint32_t actual = 0;
  uint32_t golden = 0;

  int errors = 0;
  int error;

  for (int i = 0; i < len; i++) {
    error = 0;
    actual_word = *(actual_z + i);
    golden_word = *(golden_z + i);

    // int error = ((actual_word ^ golden_word) & ~IGNORE_BITS_COMPARE) ? 1 : 0;
    uint16_t diff = 0;

    // Chechink Least Significant Half-Word
    actual_LSHWord = (uint16_t)(actual_word & 0x0000FFFF);
    golden_LSHWord = (uint16_t)(golden_word & 0x0000FFFF);

    diff = (actual_LSHWord > golden_LSHWord)   ? (actual_LSHWord - golden_LSHWord)
           : (actual_LSHWord < golden_LSHWord) ? (golden_LSHWord - actual_LSHWord)
                                               : 0;

    if (diff > ERR) {
      error = 1;
    }

    // Checking Most Significant Half-Word
    actual_MSHWord = (uint16_t)((actual_word >> 16) & 0x0000FFFF);
    golden_MSHWord = (uint16_t)((golden_word >> 16) & 0x0000FFFF);

    diff = (actual_MSHWord > golden_MSHWord)   ? (actual_MSHWord - golden_MSHWord)
           : (actual_MSHWord < golden_MSHWord) ? (golden_MSHWord - actual_MSHWord)
                                               : 0;

    if (diff > ERR) {
      error = 1;
    }

    errors += error;
  }

  return errors;
}

static inline int redmule8_compare_int(uint32_t *actual_z, uint32_t *golden_z, int len) {
  uint32_t actual_word = 0;
  uint8_t actual_Byte0, actual_Byte1, actual_Byte2, actual_Byte3;
  uint32_t golden_word = 0;
  uint8_t golden_Byte0, golden_Byte1, golden_Byte2, golden_Byte3;
  uint32_t actual = 0;
  uint32_t golden = 0;

  int errors = 0;
  int error;

  for (int i = 0; i < len; i++) {
    error = 0;
    actual_word = *(actual_z + i);
    golden_word = *(golden_z + i);

    // int error = ((actual_word ^ golden_word) & ~IGNORE_BITS_COMPARE) ? 1 : 0;
    uint8_t diff = 0;

    // Cheching Byte0
    actual_Byte0 = (uint8_t)(actual_word & 0x000000FF);
    golden_Byte0 = (uint8_t)(golden_word & 0x000000FF);

    diff = (actual_Byte0 > golden_Byte0)   ? (actual_Byte0 - golden_Byte0)
           : (actual_Byte0 < golden_Byte0) ? (golden_Byte0 - actual_Byte0)
                                           : 0;

    if (diff > ERR) {
      error = 1;
    }

    // Cheching Byte1
    actual_Byte1 = (uint8_t)((actual_word >> 8) & 0x000000FF);
    golden_Byte1 = (uint8_t)((golden_word >> 8) & 0x000000FF);

    diff = (actual_Byte1 > golden_Byte1)   ? (actual_Byte1 - golden_Byte1)
           : (actual_Byte1 < golden_Byte1) ? (golden_Byte1 - actual_Byte1)
                                           : 0;

    if (diff > ERR) {
      error = 1;
    }

    // Cheching Byte2
    actual_Byte2 = (uint8_t)((actual_word >> 16) & 0x000000FF);
    golden_Byte2 = (uint8_t)((golden_word >> 16) & 0x000000FF);

    diff = (actual_Byte2 > golden_Byte2)   ? (actual_Byte2 - golden_Byte2)
           : (actual_Byte2 < golden_Byte2) ? (golden_Byte2 - actual_Byte2)
                                           : 0;

    if (diff > ERR) {
      error = 1;
    }

    // Cheching Byte3
    actual_Byte3 = (uint8_t)((actual_word >> 24) & 0x000000FF);
    golden_Byte3 = (uint8_t)((golden_word >> 24) & 0x000000FF);

    diff = (actual_Byte3 > golden_Byte3)   ? (actual_Byte3 - golden_Byte3)
           : (actual_Byte3 < golden_Byte3) ? (golden_Byte3 - actual_Byte3)
                                           : 0;

    if (diff > ERR) {
      error = 1;
    }

    errors += error;
  }

  return errors;
}
