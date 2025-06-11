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

// #define PB_CHS_CLK_GATING_RST_BASE_ADDR 0x18001000
// #define PB_CHS_CLK_GATING_RST_END_ADDR 0x18002000

int main(void) {
    volatile uint32_t *cluster_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_CLUSTER_CLK_EN_ADDR;    // 16b
    volatile uint32_t *mem_tile_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_MEM_TILE_CLK_EN_ADDR;  // 8b
    volatile uint32_t *fhg_spu_clk_en_reg_ptr = (volatile uint32_t *)PB_CHS_FHG_SPU_CLK_EN_ADDR;    // 1b
    volatile uint32_t *cluster_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_CLUSTER_RST_N_ADDR;      // 16b
    volatile uint32_t *mem_tile_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_MEM_TILE_RST_N_ADDR;    // 8b
    volatile uint32_t *fhg_spu_rst_n_reg_ptr = (volatile uint32_t *)PB_CHS_FHG_SPU_RST_N_ADDR;      // 1b

    *(cluster_clk_en_reg_ptr) = 0x00001111;
    *(mem_tile_clk_en_reg_ptr) = 0x00000022;
    *(fhg_spu_clk_en_reg_ptr) = 0x00000000;
    *(cluster_rst_n_reg_ptr) = 0x00004444;
    *(mem_tile_rst_n_reg_ptr) = 0x00000055;
    *(fhg_spu_rst_n_reg_ptr) = 0x00000001;

    *(cluster_clk_en_reg_ptr) = 0x0000FFFF;
    *(mem_tile_clk_en_reg_ptr) = 0x000000FF;
    *(fhg_spu_clk_en_reg_ptr) = 0x00000001;
    *(cluster_rst_n_reg_ptr) = 0x0000FFFF;
    *(mem_tile_rst_n_reg_ptr) = 0x000000FF;
    *(fhg_spu_rst_n_reg_ptr) = 0x00000001;

    char str[] = "Hello World!\r\n";
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    uart_write_str(&__base_uart, str, sizeof(str));
    uart_write_flush(&__base_uart);
    return 0;
}
