// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

module tb_picobello_top;

  `define L2_SRAM_PATH fix.dut.gen_memtile[i].i_mem_tile.\
                       gen_sram_banks[j].gen_sram_macros[k].i_mem.sram

  `include "tb_picobello_tasks.svh"
  `include "pb_soc_regs_addrmap.svh"

  // Instantiate the fixture
  fixture_picobello_top fix ();

  string        preload_elf;
  string        boot_hex;
  logic  [ 1:0] boot_mode;
  logic  [ 1:0] preload_mode;
  bit    [31:0] exit_code;
  bit           snitch_preload;
  string        snitch_elf;
  logic  [63:0] snitch_entry;
  int           snitch_fn;
  int           chs_fn;

  bit [63:0] CTRL_REGS_BASE_ADDR = 64'h18001000;    // TODO(cdurrer): take from global addrmap after rdl-branch merge
  bit [63:0] cluster_clk_en_addr;
  bit [63:0] mem_tile_clk_en_addr;
  bit [63:0] fhg_spu_clk_en_addr;
  bit [63:0] cluster_rst_n_addr;
  bit [63:0] mem_tile_rst_n_addr;
  bit [63:0] fhg_spu_rst_n_addr;

  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("BOOTMODE=%d", boot_mode)) boot_mode = 0;
    if (!$value$plusargs("PRELMODE=%d", preload_mode)) preload_mode = 1;
    if (!$value$plusargs("IMAGE=%s", boot_hex)) boot_hex = "";

    if ($value$plusargs("CHS_BINARY=%s", preload_elf)) begin
      chs_fn = $fopen(".chsbinary", "w");
      $fwrite(chs_fn, preload_elf);
    end else begin
      preload_elf = "";
    end

    if ($value$plusargs("SN_BINARY=%s", snitch_elf)) begin
      snitch_fn = $fopen(".rtlbinary", "w");
      $fwrite(snitch_fn, snitch_elf);
      snitch_preload = 1;
    end else begin
      snitch_preload = 0;
    end

    // Set boot mode and preload boot image if there is one
    fix.vip.set_boot_mode(boot_mode);
    fix.vip.i2c_eeprom_preload(boot_hex);
    fix.vip.spih_norflash_preload(boot_hex);

    // Wait for reset
    fix.vip.wait_for_reset();

    // Write control registers
    cluster_clk_en_addr    = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_CLUSTER_CLK_ENABLES_REG_OFFSET;
    mem_tile_clk_en_addr   = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_MEM_TILE_CLK_ENABLES_REG_OFFSET;
    fhg_spu_clk_en_addr    = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_FHG_SPU_CLK_ENABLES_REG_OFFSET;
    cluster_rst_n_addr     = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_CLUSTER_RSTS_REG_OFFSET;
    mem_tile_rst_n_addr    = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_MEM_TILE_RSTS_REG_OFFSET;
    fhg_spu_rst_n_addr     = CTRL_REGS_BASE_ADDR + `PB_SOC_REGS_FHG_SPU_RSTS_REG_OFFSET;

    $display("Turning on clock (tile_clk_en = 1, default: 1 (ON)) and deactivate reset (tile_rst_n = 1, default: 0 (in reset)) for all tiles...");
    fix.vip.jtag_init();
    fix.vip.jtag_write_reg32(cluster_clk_en_addr, 32'h0000FFFF, 1'b1);
    fix.vip.jtag_write_reg32(mem_tile_clk_en_addr, 32'h000000FF, 1'b1);
    fix.vip.jtag_write_reg32(fhg_spu_clk_en_addr, 32'h00000001, 1'b1);
    fix.vip.jtag_write_reg32(cluster_rst_n_addr, 32'h0000FFFF, 1'b1);
    fix.vip.jtag_write_reg32(mem_tile_rst_n_addr, 32'h000000FF, 1'b1);
    fix.vip.jtag_write_reg32(fhg_spu_rst_n_addr, 32'h00000001, 1'b1);

    // Preload in idle mode or wait for completion in autonomous boot
    if (boot_mode == 0) begin
      // Idle boot: preload with the specified mode
      case (preload_mode)
        0: begin  // JTAG
          if (snitch_preload) fix.vip.jtag_elf_preload(snitch_elf, snitch_entry);
          fix.vip.jtag_elf_run(preload_elf);
          fix.vip.jtag_wait_for_eoc(exit_code);
        end
        1: begin  // Serial Link
          if (snitch_preload) fix.vip.slink_elf_preload(snitch_elf, snitch_entry);
          fix.vip.slink_elf_run(preload_elf);
          fix.vip.slink_wait_for_eoc(exit_code);
        end
        2: begin  // UART
          if (snitch_preload)
            $fatal(1, "Unsupported snitch binary preload mode %d (UART)!", preload_mode);
          fix.vip.uart_debug_elf_run_and_wait(preload_elf, exit_code);
        end
        3: begin  // Fast Mode
          if (snitch_preload) fastmode_elf_preload(snitch_elf, snitch_entry);
          // TODO(fischeti): Implement fast mode for Cheshire binary
          fix.vip.jtag_elf_run(preload_elf);
          fix.vip.jtag_wait_for_eoc(exit_code);
          if (snitch_preload) fastmode_read();
        end
        default: begin
          $fatal(1, "Unsupported preload mode %d (reserved)!", boot_mode);
        end
      endcase
    end else if (boot_mode == 1) begin
      $fatal(1, "Unsupported boot mode %d (SD Card)!", boot_mode);
    end else begin
      // Autonomous boot: Only poll return code
      fix.vip.jtag_wait_for_eoc(exit_code);
    end

    // Wait for the UART to finish reading the current byte
    wait (fix.vip.uart_reading_byte == 0);

    $finish;
  end

endmodule
