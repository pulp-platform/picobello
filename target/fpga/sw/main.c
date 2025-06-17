// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

#include "picobello_sw_pkg.h"

///////////////
// Functions //
///////////////

// Program traffic generator
void picobello_tg_cfg(
    tg_cfg_t tg_cfg
) {
    // Set destination address of narrow port
	picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x00000010, (u64)tg_cfg.MemAddrBase);
    
    // Set destination address of wide port
    picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x0000001c, (u64)tg_cfg.MemAddrBase);

    // Set traffic dimension
    picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x00000028, (u64)tg_cfg.TrafficGenTrafficDim);

    // Set compute dimension
    picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x00000034, (u64)tg_cfg.TrafficGenComputeDim);

    // Set traffic index
    picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x00000040, (u64)tg_cfg.TrafficGenIdx);
}

// Run traffic generator
void picobello_tg_start(
    tg_cfg_t tg_cfg
) {
    u64 _read_data;
    u64 _tg_start;

    // Read control register
	_read_data = picobello_read(tg_cfg.TrafficGenAddrBase, (u64)0x00000000);

    // Run traffic generator
    _tg_start = (_read_data & 0x0000000000000080) | 0x0000000000000001;
    picobello_write(tg_cfg.TrafficGenAddrBase, (u64)0x00000000, (u64)_tg_start);
}

// Wait for traffic generator to terminate execution
void picobello_tg_polling(
    tg_cfg_t tg_cfg
) {
    u64 _read_data;
    u64 _tg_idle;

    // Check traffic generator idleness  
    _tg_idle = 0;  
    while (~_tg_idle[0]){
      _read_data = picobello_read(tg_cfg.TrafficGenAddrBase, (u64)0x00000000);
      _tg_idle = (_read_data >> 2) & 0x0000000000000001;
    }
}

//////////
// Main //
//////////

int main()
{
    xil_printf("Hello Picobello!\n\r");

    // Setup
    init_platform();

    // Traffic generator configuration
    tg_cfg_t tg_cfg;

    //////////////////////////////////
    // Test: ClusterX0Y0 <-> L2Spm0 //
    //////////////////////////////////

    xil_printf("Test: [ClusterX0Y0 <-> L2Spm0]\n\r");

    xil_printf(">> START\n\r");

    // Set address map
    tg_cfg.TrafficGenPortID       = ClusterX0Y0;
    tg_cfg.MemPortID               = L2Spm0 - L2Spm0;
    tg_cfg.TrafficGenAddrBase     = cluster_x0_y0.start_addr + tg_cfg.TrafficGenPortID + 0x00040000; 
    tg_cfg.MemAddrBase             = l2_spm_0.start_addr + tg_cfg.MemPortID * 0x00100000;

    // Set traffic generator parameters
    tg_cfg.TrafficGenTrafficDim      = 0x00000100;
    tg_cfg.TrafficGenComputeDim      = 0x00000100;
    tg_cfg.TrafficGenIdx             = 0x00000001;

    // Program traffic generator
    picobello_tg_cfg(tg_cfg);

    // Run traffic generator
    picobello_tg_start(tg_cfg);

    // Wait for termination
    picobello_tg_polling(tg_cfg);

    xil_printf(">> END\n\r");

    ////////////////////////
    // Test: Run Them All //
    ////////////////////////

    xil_printf("Test: Run Them All\n\r");

    // TBD

    cleanup_platform();
    return 0;
}
