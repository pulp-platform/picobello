// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

#ifndef PICOBELLO_SW_PKG_H
#define PICOBELLO_SW_PKG_H

#include "xil_io.h"

static inline u64 picobello_read(u64 addr, u64 offset) {
    u64 data;
    data = Xil_In64((addr) + (offset));
    // data += (u64)Xil_In32((addr) + (offset + 4)) << 32;
    return data;
}

static inline void picobello_write(u64 addr, u64 offset, u64 data) {
    Xil_Out64((addr) + (offset), (data));
    // Xil_Out32((addr) + (offset + 4), (u32)(data >> 32));
}

typedef enum {
    ClusterX0Y0,
    ClusterX0Y1,
    ClusterX0Y2,
    ClusterX0Y3,
    ClusterX1Y0,
    ClusterX1Y1,
    ClusterX1Y2,
    ClusterX1Y3,
    Cheshire,
    FhgSpu,
    L2Spm0,
    L2Spm1,
    L2Spm2,
    L2Spm3,
    NumEndpoints
} ep_id_e;

typedef enum {
    ClusterX0Y0SamIdx,
    ClusterX0Y1SamIdx,
    ClusterX0Y2SamIdx,
    ClusterX0Y3SamIdx,
    ClusterX1Y0SamIdx,
    ClusterX1Y1SamIdx,
    ClusterX1Y2SamIdx,
    ClusterX1Y3SamIdx,
    CheshireSamIdx,
    FhgSpuSamIdx,
    L2Spm0SamIdx,
    L2Spm1SamIdx,
    L2Spm2SamIdx,
    L2Spm3SamIdx
} sam_idx_e;

typedef struct {
    // Port IDs
    u32 TrafficGenPortID;
    u32 MemPortID;
    // Addresses
    u64 TrafficGenAddrBase; // Traffic generator base address
    u64 MemAddrBase; // Memory base address
    // Traffic generator parameters
    u32 TrafficGenTrafficDim; // Traffic dimension
    u32 TrafficGenComputeDim; // Compute dimension
    u32 TrafficGenIdx; // Index
} tg_cfg_t;

typedef struct {
    u32 x;
    u32 y;
    u32 port_id;
} idx_t;

typedef struct {
    idx_t   idx;
    u64     start_addr;
    u64     end_addr;
} sam_rule_t;

// Defs
#define SamNumRules 15

// Tiles address mapping        
const sam_rule_t fhg_spu            = { {3, 0, 0}, 0x00000000e0000000, 0x00000000e0040000 };
const sam_rule_t cheshire_internal  = { {3, 3, 0}, 0x00000000a0000000, 0x00000000c0000000 };
const sam_rule_t cheshire_external  = { {3, 3, 0}, 0x0000000080000000, 0x0000000090000000 };
const sam_rule_t cluster_x1_y3      = { {2, 3, 0}, 0x00000000c01c0000, 0x00000000c0200000 };
const sam_rule_t cluster_x1_y2      = { {2, 2, 0}, 0x00000000c0180000, 0x00000000c01c0000 };
const sam_rule_t cluster_x1_y1      = { {2, 1, 0}, 0x00000000c0140000, 0x00000000c0180000 };
const sam_rule_t cluster_x1_y0      = { {2, 0, 0}, 0x00000000c0100000, 0x00000000c0140000 };
const sam_rule_t cluster_x0_y3      = { {1, 3, 0}, 0x00000000c00c0000, 0x00000000c0100000 };
const sam_rule_t cluster_x0_y2      = { {1, 2, 0}, 0x00000000c0080000, 0x00000000c00c0000 };
const sam_rule_t cluster_x0_y1      = { {1, 1, 0}, 0x00000000c0040000, 0x00000000c0080000 };
const sam_rule_t cluster_x0_y0      = { {1, 0, 0}, 0x00000000c0000000, 0x00000000c0040000 };
const sam_rule_t l2_spm_3           = { {0, 3, 0}, 0x00000000d0300000, 0x00000000d0400000 };
const sam_rule_t l2_spm_2           = { {0, 2, 0}, 0x00000000d0200000, 0x00000000d0300000 };
const sam_rule_t l2_spm_1           = { {0, 1, 0}, 0x00000000d0100000, 0x00000000d0200000 };
const sam_rule_t l2_spm_0           = { {0, 0, 0}, 0x00000000d0000000, 0x00000000d0100000 }; 

#endif