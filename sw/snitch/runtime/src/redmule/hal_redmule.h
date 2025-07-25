// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

#pragma once

#define REDMULE_ADDR_BASE REDMULE_BASE_ADD
#define REDMULE_ADDR_SPACE 0x00000100

#define REDMULE_WRITE(value, offset) *(volatile int *)(REDMULE_ADDR_BASE + offset) = value
#define REDMULE_READ(offset) *(volatile int *)(REDMULE_ADDR_BASE + offset)

static inline void redmule_x_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_X_PTR);
}

static inline void redmule_w_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_W_PTR);
}

static inline void redmule_z_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_Z_PTR);
}

static inline void redmule_g_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_G_PTR);
}

static inline void redmule_s_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_S_PTR);
}

static inline void redmule_b_add_set(unsigned int value) {
  REDMULE_WRITE(value, REDMULE_REG_OFFS + REDMULE_REG_B_PTR);
}

static inline void redmule_mcfg_set(uint32_t mcfg0, uint32_t mcfg1) {
  REDMULE_WRITE(mcfg0, REDMULE_REG_OFFS + REDMULE_MCFG0_PTR);
  REDMULE_WRITE(mcfg1, REDMULE_REG_OFFS + REDMULE_MCFG1_PTR);
}

static inline void redmule_arith_set(uint32_t arith) {
  REDMULE_WRITE(arith, REDMULE_REG_OFFS + REDMULE_ARITH_PTR);
}

static inline void redmule_trigger_job() { REDMULE_WRITE(0, REDMULE_TRIGGER); }

static inline int redmule_acquire_job() { return REDMULE_READ(REDMULE_ACQUIRE); }

static inline unsigned int redmule_get_status() { return REDMULE_READ(REDMULE_STATUS); }

static inline void redmule_soft_clear() {
  volatile int i;
  REDMULE_WRITE(0, REDMULE_SOFT_CLEAR);
}

static inline void redmule_evt_clear(int value) {
  REDMULE_WRITE(value, REDMULE_EVT_OFFS);
}

static inline void redmule_cg_enable() { REDMULE_WRITE(1, REDMULE_CK_GATE_OFFS); }

static inline void redmule_cg_disable() { REDMULE_WRITE(0, REDMULE_CK_GATE_OFFS); }

static inline void redmule_cfg(unsigned int x, unsigned int w, unsigned int z, uint16_t m_size, uint16_t n_size,
                 uint16_t k_size, uint8_t gemm_op, uint8_t gemm_fmt) {

  uint32_t mcfg_reg0 = 0;
  uint32_t mcfg_reg1 = 0;
  uint32_t arith_reg = 0;

  mcfg_reg0 = (k_size << 16) | (m_size << 0);
  mcfg_reg1 = n_size << 0;

  arith_reg = (gemm_op << 10) | (gemm_fmt << 7);

  redmule_x_add_set((unsigned int)x);
  redmule_w_add_set((unsigned int)w);
  redmule_z_add_set((unsigned int)z);
  redmule_mcfg_set((unsigned int)mcfg_reg0, (unsigned int)mcfg_reg1);
  redmule_arith_set((unsigned int)arith_reg);
}

static inline void redmule_cfg(unsigned int x, unsigned int w, unsigned int z, unsigned int g, unsigned int s, unsigned int b, uint16_t m_size, uint16_t n_size,
                 uint16_t k_size, uint8_t gemm_op, uint8_t gemm_fmt, uint8_t dequant_en, uint8_t q_fmt) {

  uint32_t mcfg_reg0 = 0;
  uint32_t mcfg_reg1 = 0;
  uint32_t arith_reg = 0;

  mcfg_reg0 = (k_size << 16) | (m_size << 0);
  mcfg_reg1 = n_size << 0;

  arith_reg =  (q_fmt << 17) | (dequant_en << 16) | (gemm_op << 10) | (gemm_fmt << 7);

  redmule_x_add_set((unsigned int)x);
  redmule_w_add_set((unsigned int)w);
  redmule_z_add_set((unsigned int)z);
  redmule_g_add_set((unsigned int)g);
  redmule_s_add_set((unsigned int)s);
  redmule_b_add_set((unsigned int)b);
  redmule_mcfg_set((unsigned int)mcfg_reg0, (unsigned int)mcfg_reg1);
  redmule_arith_set((unsigned int)arith_reg);
}