// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

#pragma once

/*
 * |========================================================================|
 * ||                                                                      ||
 * ||Control and generic configuration register layout                     ||
 * |========================================================================|
 * || # reg |  offset  |  bits   |   bitmask    ||  content                ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    0  |  0x0000  |  31: 0  |  0xFFFFFFFF  ||  TRIGGER                ||
 * ||    1  |  0x0004  |  31: 0  |  0xFFFFFFFF  ||  ACQUIRE                ||
 * ||    2  |  0x0008  |  31: 0  |  0xFFFFFFFF  ||  EVT_ENABLE             ||
 * ||    3  |  0x000c  |  31: 0  |  0xFFFFFFFF  ||  STATUS                 ||
 * ||    4  |  0x0010  |  31: 0  |  0xFFFFFFFF  ||  RUNNING_JOB            ||
 * ||    5  |  0x0014  |  31: 0  |  0xFFFFFFFF  ||  SOFT_CLEAR             ||
 * |========================================================================|
 * ||                                                                      ||
 * ||Job-dependent registers layout                                        ||
 * |========================================================================|
 * || # reg |  offset  |  bits   |   bitmask    ||  content                ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    0  |  0x0040  |  31: 0  |  0xFFFFFFFF  ||  X_ADDR                 ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    1  |  0x0044  |  31: 0  |  0xFFFFFFFF  ||  W_ADDR                 ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    2  |  0x0048  |  31: 0  |  0xFFFFFFFF  ||  Z_ADDR                 ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    3  |  0x004C  |         |              ||  Matrix Config 0 Reg    ||
 * ||       |          |  31:16  |  0xFFFF0000  ||  K Size (W Columns)     ||
 * ||       |          |  15: 0  |  0x0000FFFF  ||  M Size (X Rows)        ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    4  |  0x0050  |         |              ||  Matrix Config 1 Reg    ||
 * ||       |          |  31:16  |  0xFFFFFFFF  ||  N Size (X Cols/W Rows) ||
 * ||-------+----------+---------+--------------++-------------------------||
 * ||    5  |  0x0054  |         |              ||  Matrix Arithmetic Reg  ||
 * ||       |          |  12:10  |  0x00001C00  ||  Operation selection    ||
 * ||       |          |   9: 7  |  0x00000380  ||  Input/Output format    ||
 * |========================================================================|
 *
 */

#define REDMULE_ARCHI_CL_EVT_ACC0 0
#define REDMULE_ARCHI_CL_EVT_ACC1 1

// Base address
#define REDMULE_BASE_ADD (unsigned long)snrt_cluster()->zeromem.mem+sizeof(snrt_cluster()->zeromem.mem)

// Commands
#define REDMULE_TRIGGER 0x00
#define REDMULE_ACQUIRE 0x04
#define REDMULE_FINISHED 0x08
#define REDMULE_STATUS 0x0C
#define REDMULE_RUNNING_JOB 0x10
#define REDMULE_SOFT_CLEAR 0x14

// Registers
#define REDMULE_REG_OFFS 0x40
#define REDMULE_REG_X_PTR 0x00
#define REDMULE_REG_W_PTR 0x04
#define REDMULE_REG_Z_PTR 0x08
#define REDMULE_MCFG0_PTR 0x0C
#define REDMULE_MCFG1_PTR 0x10
#define REDMULE_ARITH_PTR 0x14
#define REDMULE_REG_G_PTR 0x18
#define REDMULE_REG_S_PTR 0x1C
#define REDMULE_REG_B_PTR 0x20

#define REDMULE_EVT_OFFS 0x94
#define REDMULE_CK_GATE_OFFS 0x9C

// OPs definition
#define REDMULE_MATMUL 0x0
#define REDMULE_GEMM 0x1
#define REDMULE_ADDMAX 0x2
#define REDMULE_ADDMIN 0x3
#define REDMULE_MULMAX 0x4
#define REDMULE_MULMIN 0x5
#define REDMULE_MAXMIN 0x6
#define REDMULE_MINMAX 0x7
#define REDMULE_PACE 0x8

// GEMM formats
#define REDMULE_Float8 0x0
#define REDMULE_Float16 0x1
#define REDMULE_Float8Alt 0x2
#define REDMULE_Float16Alt 0x3

// FP Formats encoding
#define REDMULE_FP16 0x2
#define REDMULE_FP8 0x3
#define REDMULE_FP16ALT 0x4
#define REDMULE_FP8ALT 0x5

// Quantized formats
#define REDMULE_Q_INT2 0x0
#define REDMULE_Q_INT4 0x1
#define REDMULE_Q_INT8 0x2