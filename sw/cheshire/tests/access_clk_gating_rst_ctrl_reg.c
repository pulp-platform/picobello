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
    volatile uint32_t *cluster_clk_en_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_CLUSTER_CLK_ENABLES_REG_OFFSET);    // 16b
    volatile uint32_t *mem_tile_clk_en_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_MEM_TILE_CLK_ENABLES_REG_OFFSET);  // 8b
    volatile uint32_t *fhg_spu_clk_en_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_FHG_SPU_CLK_ENABLES_REG_OFFSET);    // 1b
    volatile uint32_t *cluster_rst_n_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_CLUSTER_RSTS_REG_OFFSET);      // 16b
    volatile uint32_t *mem_tile_rst_n_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_MEM_TILE_RSTS_REG_OFFSET);    // 8b
    volatile uint32_t *fhg_spu_rst_n_reg_ptr = (volatile uint32_t *)(PB_CHS_CLK_GATING_RST_BASE_ADDR + PB_SOC_REGS_FHG_SPU_RSTS_REG_OFFSET);      // 1b

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    uart_write_str(&__base_uart, "Testing control registers: tile_clk_en and tile_rst_n\r\n", 55);

    // Write all 0s and check
    *(cluster_clk_en_reg_ptr) = 0x00000000;
    *(mem_tile_clk_en_reg_ptr) = 0x00000000;
    *(fhg_spu_clk_en_reg_ptr) = 0x00000000;
    *(cluster_rst_n_reg_ptr) = 0x00000000;
    *(mem_tile_rst_n_reg_ptr) = 0x00000000;
    *(fhg_spu_rst_n_reg_ptr) = 0x00000000;

    if(*cluster_clk_en_reg_ptr==0x00000000 && *mem_tile_clk_en_reg_ptr==0x00000000 && *fhg_spu_clk_en_reg_ptr==0x00000000 && *cluster_rst_n_reg_ptr==0x00000000 && *mem_tile_rst_n_reg_ptr==0x00000000 && *fhg_spu_rst_n_reg_ptr==0x00000000) {
        uart_write_str(&__base_uart, "Write all 0s: OK\r\n", 18);
        // uart_write_flush(&__base_uart);
    } else {
        uart_write_str(&__base_uart, "ERROR: Control register access failed! (all 0s)\r\n", 49);
        uart_write_flush(&__base_uart);
        return 1;
    }

    // Write all 1s and check
    *(cluster_clk_en_reg_ptr) = 0x0000FFFF;
    *(mem_tile_clk_en_reg_ptr) = 0x000000FF;
    *(fhg_spu_clk_en_reg_ptr) = 0x00000001;
    *(cluster_rst_n_reg_ptr) = 0x0000FFFF;
    *(mem_tile_rst_n_reg_ptr) = 0x000000FF;
    *(fhg_spu_rst_n_reg_ptr) = 0x00000001;

    if(*cluster_clk_en_reg_ptr==0x0000FFFF && *mem_tile_clk_en_reg_ptr==0x000000FF && *fhg_spu_clk_en_reg_ptr==0x00000001 && *cluster_rst_n_reg_ptr==0x0000FFFF && *mem_tile_rst_n_reg_ptr==0x000000FF && *fhg_spu_rst_n_reg_ptr==0x00000001) {
        uart_write_str(&__base_uart, "Write all 1s: OK\r\n", 18);
        // uart_write_flush(&__base_uart);
    } else {
        uart_write_str(&__base_uart, "ERROR: Control register access failed! (all 1s)\r\n", 49);
        uart_write_flush(&__base_uart);
        return 1;
    }

    // Write checkerboard pattern and check
    *(cluster_clk_en_reg_ptr) = 0x0000AAAA;
    *(mem_tile_clk_en_reg_ptr) = 0x000000AA;
    *(fhg_spu_clk_en_reg_ptr) = 0x00000000;
    *(cluster_rst_n_reg_ptr) = 0x00005555;
    *(mem_tile_rst_n_reg_ptr) = 0x00000055;
    *(fhg_spu_rst_n_reg_ptr) = 0x00000000;

    if(*cluster_clk_en_reg_ptr==0x0000AAAA && *mem_tile_clk_en_reg_ptr==0x000000AA && *fhg_spu_clk_en_reg_ptr==0x00000000 && *cluster_rst_n_reg_ptr==0x00005555 && *mem_tile_rst_n_reg_ptr==0x00000055 && *fhg_spu_rst_n_reg_ptr==0x00000000) {
        uart_write_str(&__base_uart, "Write checkerboard pattern: OK\r\n", 32);
    } else {
        uart_write_str(&__base_uart, "ERROR: Control register access failed! (checkerboard)\r\n", 55);
        uart_write_flush(&__base_uart);
        return 1;
    }
    uart_write_str(&__base_uart, "Tests complete: No errors\r\n", 27);
    uart_write_flush(&__base_uart);
    return 0;
}
