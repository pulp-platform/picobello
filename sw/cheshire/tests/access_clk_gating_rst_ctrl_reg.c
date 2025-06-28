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

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    // uart_write_str(&__base_uart, "Testing ctrl regs: tile_clk_en and tile_rst_n\r\n", 47);
    uart_write_str(&__base_uart, "Testing ctrl regs\r\n", 19);

    uint32_t n_errors = 0;

    // Write all 0s and check
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts = 0x00000000;

    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts == 0x00000000);

    // Write all 1s and check again
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables = 0x0000FFFF;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables = 0x000000FF;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables = 0x00000001;
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts = 0x0000FFFF;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts = 0x000000FF;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts = 0x00000001;

    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables == 0x0000FFFF);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables == 0x000000FF);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables == 0x00000001);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts == 0x0000FFFF);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts == 0x000000FF);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts == 0x00000001);

    // Write all 1s and check again
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables = 0x0000AAAA;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables = 0x000000AA;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables = 0x00000000;
    picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts = 0x00005555;
    picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts = 0x00000055;
    picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts = 0x00000000;

    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_clk_enables == 0x0000AAAA);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_clk_enables == 0x000000AA);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_clk_enables == 0x00000000);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.cluster_rsts == 0x00005555);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.mem_tile_rsts == 0x00000055);
    n_errors += (picobello_addrmap.cheshire_internal.pb_soc_regs.fhg_spu_rsts == 0x00000000);

    if (n_errors > 0) {
        uart_write_str(&__base_uart, "ERROR: Control register access failed!\r\n", 40);
        uart_write_flush(&__base_uart);
    }

    uart_write_str(&__base_uart, "CTRL REG test complete: No errors\r\n", 26);
    uart_write_flush(&__base_uart);
    return n_errors;
}
