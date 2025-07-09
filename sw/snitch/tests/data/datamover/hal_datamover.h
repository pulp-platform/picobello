// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Francesco Conti <f.conti@unibo.it>
//

#pragma once

#define DATAMOVER_ADDR_BASE DATAMOVER_BASE_ADD
#define DATAMOVER_ADDR_SPACE 0x00000100

#define HWPE_WRITE(value, offset) *(volatile int *)(DATAMOVER_ADDR_BASE + offset) = value
#define HWPE_READ(offset) *(volatile int *)(DATAMOVER_ADDR_BASE + offset)

static inline void datamover_in_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_IN_PTR);
}

static inline void datamover_out_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_OUT_PTR);
}

static inline void datamover_len0_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_LEN0);
}

static inline void datamover_len1_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_LEN1);
}

static inline void datamover_in_d0_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_IN_D0_STRIDE);
}

static inline void datamover_in_d1_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_IN_D1_STRIDE);
}

static inline void datamover_in_d2_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_IN_D2_STRIDE);
}

static inline void datamover_out_d0_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_OUT_D0_STRIDE);
}

static inline void datamover_out_d1_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_OUT_D1_STRIDE);
}

static inline void datamover_out_d2_stride_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_OUT_D2_STRIDE);
}

static inline void datamover_transp_mode_set(unsigned int value) {
  HWPE_WRITE(value, DATAMOVER_REG_OFFS + DATAMOVER_REG_TRANSP_MODE);
}

static inline void hwpe_trigger_job() { HWPE_WRITE(0, DATAMOVER_TRIGGER); }

static inline int hwpe_acquire_job() { return HWPE_READ(DATAMOVER_ACQUIRE); }

static inline unsigned int hwpe_get_status() { return HWPE_READ(DATAMOVER_STATUS); }

static inline void hwpe_soft_clear() {
  volatile int i;
  HWPE_WRITE(0, DATAMOVER_SOFT_CLEAR);
}

static inline void hwpe_evt_clear(int value) {
  HWPE_WRITE(value, HWPE_EVT_OFFS);
}

static inline void datamover_cg_enable() { HWPE_WRITE(2, CK_GATE_OFFS); }

static inline void datamover_cg_disable() { HWPE_WRITE(0, CK_GATE_OFFS); }

static inline void datamover_mux_enable() { HWPE_WRITE(1, MUX_SEL_OFFS); }