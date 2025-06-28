// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "picobello_addrmap.h"

int main(void) {

    uint32_t n_errors = 3 * 6; // 3 tests, 6 registers each

    volatile pb_soc_regs_t *pb_soc_regs = &picobello_addrmap.cheshire_internal.pb_soc_regs;

    // Write all 0s and check
    pb_soc_regs->cluster_clk_enables = 0x00000000;
    pb_soc_regs->mem_tile_clk_enables = 0x00000000;
    pb_soc_regs->fhg_spu_clk_enables = 0x00000000;
    pb_soc_regs->cluster_rsts = 0x00000000;
    pb_soc_regs->mem_tile_rsts = 0x00000000;
    pb_soc_regs->fhg_spu_rsts = 0x00000000;

    n_errors -= (pb_soc_regs->cluster_clk_enables == 0x00000000);
    n_errors -= (pb_soc_regs->mem_tile_clk_enables == 0x00000000);
    n_errors -= (pb_soc_regs->fhg_spu_clk_enables == 0x00000000);
    n_errors -= (pb_soc_regs->cluster_rsts == 0x00000000);
    n_errors -= (pb_soc_regs->mem_tile_rsts == 0x00000000);
    n_errors -= (pb_soc_regs->fhg_spu_rsts == 0x00000000);

    // Write all 1s and check again
    pb_soc_regs->cluster_clk_enables = 0x0000FFFF;
    pb_soc_regs->mem_tile_clk_enables = 0x000000FF;
    pb_soc_regs->fhg_spu_clk_enables = 0x00000001;
    pb_soc_regs->cluster_rsts = 0x0000FFFF;
    pb_soc_regs->mem_tile_rsts = 0x000000FF;
    pb_soc_regs->fhg_spu_rsts = 0x00000001;

    n_errors -= (pb_soc_regs->cluster_clk_enables == 0x0000FFFF);
    n_errors -= (pb_soc_regs->mem_tile_clk_enables == 0x000000FF);
    n_errors -= (pb_soc_regs->fhg_spu_clk_enables == 0x00000001);
    n_errors -= (pb_soc_regs->cluster_rsts == 0x0000FFFF);
    n_errors -= (pb_soc_regs->mem_tile_rsts == 0x000000FF);
    n_errors -= (pb_soc_regs->fhg_spu_rsts == 0x00000001);

    // Write all 1s and check again
    pb_soc_regs->cluster_clk_enables = 0x0000AAAA;
    pb_soc_regs->mem_tile_clk_enables = 0x000000AA;
    pb_soc_regs->fhg_spu_clk_enables = 0x00000000;
    pb_soc_regs->cluster_rsts = 0x00005555;
    pb_soc_regs->mem_tile_rsts = 0x00000055;
    pb_soc_regs->fhg_spu_rsts = 0x00000000;

    n_errors -= (pb_soc_regs->cluster_clk_enables == 0x0000AAAA);
    n_errors -= (pb_soc_regs->mem_tile_clk_enables == 0x000000AA);
    n_errors -= (pb_soc_regs->fhg_spu_clk_enables == 0x00000000);
    n_errors -= (pb_soc_regs->cluster_rsts == 0x00005555);
    n_errors -= (pb_soc_regs->mem_tile_rsts == 0x00000055);
    n_errors -= (pb_soc_regs->fhg_spu_rsts == 0x00000000);

    return n_errors;
}
