// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Francesco Conti <f.conti@unibo.it>
//

#pragma once

#define ARCHI_CL_EVT_ACC0 0
#define ARCHI_CL_EVT_ACC1 1

// Base address
#define DATAMOVER_BASE_ADD (unsigned long)snrt_cluster()->zeromem.mem+sizeof(snrt_cluster()->zeromem.mem)+0x100

// Commands
#define DATAMOVER_TRIGGER 0x00
#define DATAMOVER_ACQUIRE 0x04
#define DATAMOVER_FINISHED 0x08
#define DATAMOVER_STATUS 0x0C
#define DATAMOVER_RUNNING_JOB 0x10
#define DATAMOVER_SOFT_CLEAR 0x14

// Registers
#define DATAMOVER_REG_OFFS 0x40

// Input pointer
#define DATAMOVER_REG_IN_PTR         0x00
// Output pointer
#define DATAMOVER_REG_OUT_PTR        0x04
// Length register 0
#define DATAMOVER_REG_LEN0           0x08
// Length register 1
#define DATAMOVER_REG_LEN1           0x0C
// Input dimension 0 stride
#define DATAMOVER_REG_IN_D0_STRIDE   0x10
// Input dimension 1 stride
#define DATAMOVER_REG_IN_D1_STRIDE   0x14
// Input dimension 2 stride
#define DATAMOVER_REG_IN_D2_STRIDE   0x18
// Output dimension 0 stride
#define DATAMOVER_REG_OUT_D0_STRIDE  0x1C
// Output dimension 1 stride
#define DATAMOVER_REG_OUT_D1_STRIDE  0x20
// Output dimension 2 stride
#define DATAMOVER_REG_OUT_D2_STRIDE  0x24
// Transposition mode (LSB: 000=none, 001=8b, 010=16b, 100=32b) + Leftover (MSB 31:16)
#define DATAMOVER_REG_TRANSP_MODE    0x28

#define HWPE_EVT_OFFS 0x94
#define MUX_SEL_OFFS 0x98
#define CK_GATE_OFFS 0x9C

// Transposition formats
#define DATAMOVER_TRANSP_NONE 0x0
#define DATAMOVER_TRANSP_8B   0x1
#define DATAMOVER_TRANSP_16B  0x2
#define DATAMOVER_TRANSP_32B  0x4

// FP Formats encoding
#define FP16 0x2
#define FP8 0x3
#define FP16ALT 0x4
#define FP8ALT 0x5
