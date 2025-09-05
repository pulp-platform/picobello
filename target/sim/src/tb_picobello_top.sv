// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

module tb_picobello_top;

  `define L2_SRAM_PATH fix.dut.gen_memtile[i].i_mem_tile.\
                       gen_sram_banks[j].gen_sram_macros[k].i_mem.sram

  `include "tb_picobello_tasks.svh"
  `include "cheshire/typedef.svh"

  `CHESHIRE_TYPEDEF_ALL(, fix.vip.DutCfg)

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

  // Load Snitch binary
  task automatic jtag_32b_elf_preload(input string binary, output bit [63:0] entry);
    longint sec_addr, sec_len;
    dm::sbcs_t sbcs = dm::sbcs_t
'{sbautoincrement: 1'b1, sbreadondata: 1'b1, sbaccess: 2, default: '0};
    $display("[JTAG] Preloading ELF binary: %s", binary);
    if (fix.vip.read_elf(binary)) $fatal(1, "[JTAG] Failed to load ELF!");
    while (fix.vip.get_section(
        sec_addr, sec_len
    )) begin
      byte bf[] = new[sec_len];
      $display("[JTAG] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (fix.vip.read_section(sec_addr, bf, sec_len))
        $fatal(1, "[JTAG] Failed to read ELF section!");
      fix.vip.jtag_write(dm::SBCS, sbcs, 1, 1);
      // Write address as 64-bit double
      fix.vip.jtag_write(dm::SBAddress1, sec_addr[63:32]);
      fix.vip.jtag_write(dm::SBAddress0, sec_addr[31:0]);
      for (longint i = 0; i <= sec_len; i += 4) begin
        bit checkpoint = (i != 0 && i % 512 == 0);
        if (checkpoint)
          $display(
              "[JTAG] - %0d/%0d bytes (%0d%%)",
              i,
              sec_len,
              i * 100 / (sec_len > 1 ? sec_len - 1 : 1)
          );
        fix.vip.jtag_write(dm::SBData0, {bf[i+3], bf[i+2], bf[i+1], bf[i]}, checkpoint, checkpoint);
      end
    end
    void'(get_entry(entry));
    $display("[JTAG] Preload complete");
  endtask

  // Handles misalignments, burst limits and 4KiB crossings
  task automatic slink_write_generic(input addr_t addr, input longint size, ref byte bytes[]);
    // Using `slink_write_beats`, writes must be beat-aligned and beat-sized (strobing is not
    // possible). If we have a misaligned transfer of arbitrary size we may have at most two
    // incomplete beats (start and end) and one misaligned beat (start). In case of an incomplete
    // beat we read-modify-write the full beat.

    // Burst and beat geometry
    const int  beat_bytes = fix.vip.AxiStrbWidth;
    const int  beat_mask = beat_bytes - 1;
    const int  SlinkBurstBeats = fix.vip.SlinkBurstBytes / beat_bytes;

    // Iterate beat-by-beat over the address range [addr, addr+size)
    addr_t     first_aligned = addr_t'(addr) & ~addr_t'(beat_mask);
    addr_t     end_addr = addr_t'(addr + size);
    addr_t     last_aligned = addr_t'((end_addr - 1) & ~addr_t'(beat_mask));

    // Running index into bytes[]: "how many bytes have we already consumed?"
    longint    base_idx = 0;

    // Group beats in a burst
    addr_t     batch_addr = first_aligned;
    axi_data_t burst                                                        [$];
    burst = {};

    for (addr_t beat_addr = first_aligned; beat_addr <= last_aligned; beat_addr += beat_bytes) begin
      addr_t next_addr;
      bit crosses_4k_next, exceeds_burst_length, last_beat_in_section;

      // Window of the current beat that has to be written
      int start_off = (beat_addr == first_aligned) ? int'(addr & beat_mask) : 0;
      int end_off_excl = (beat_addr == last_aligned) ? int'(end_addr - last_aligned) : beat_bytes;
      int win_len = end_off_excl - start_off;

      // Compose beat
      axi_data_t beat = '0;
      if (win_len == beat_bytes && start_off == 0) begin
        // FULL BEAT: write directly, no RMW
        for (int e = 0; e < beat_bytes; e++) begin
          beat[8*e+:8] = bytes[base_idx+e];
        end
      end else begin
        // PARTIAL BEAT: RMW
        axi_data_t rd[$];
        fix.vip.slink_read_beats(beat_addr, fix.vip.AxiStrbBits, 0, rd);
        beat = rd[0];
        for (int i = 0; i < win_len; i++) begin
          beat[8*(start_off+i)+:8] = bytes[base_idx+i];
        end
      end

      // Accumulate and advance
      burst.push_back(beat);
      base_idx += win_len;

      // Decide if the next beat would cross a 4 KiB boundary, exceed the maximum burst length
      // or this is the last beat
      next_addr            = beat_addr + win_len;
      crosses_4k_next      = ((next_addr & 12'hFFF) == 12'h000);  // next beat starts a new page
      exceeds_burst_length = (burst.size() == SlinkBurstBeats);
      last_beat_in_section = (beat_addr == last_aligned);

      if (crosses_4k_next || exceeds_burst_length || last_beat_in_section) begin
        // Flush accumulated beats for this page
        fix.vip.slink_write_beats(batch_addr, fix.vip.AxiStrbBits, burst);
        burst      = {};
        batch_addr = next_addr;
      end
    end
  endtask

  task automatic slink_32b_elf_preload(input string binary, output bit [63:0] entry);
    longint sec_addr, sec_len;

    $display("[SLINK] Preloading ELF binary: %s", binary);
    if (fix.vip.read_elf(binary)) $fatal(1, "[SLINK] Failed to load ELF!");

    while (fix.vip.get_section(
        sec_addr, sec_len
    )) begin
      byte bf[] = new[sec_len];
      $display("[SLINK] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (fix.vip.read_section(sec_addr, bf, sec_len))
        $fatal(1, "[SLINK] Failed to read ELF section!");
      slink_write_generic(sec_addr, sec_len, bf);
    end

    void'(fix.vip.get_entry(entry));
    $display("[SLINK] Preload complete");
  endtask

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

    // Preload in idle mode or wait for completion in autonomous boot
    if (boot_mode == 0) begin
      // Idle boot: preload with the specified mode
      case (preload_mode)
        0: begin  // JTAG
          jtag_enable_tiles();  // Write control registers
          if (snitch_preload) jtag_32b_elf_preload(snitch_elf, snitch_entry);
          fix.vip.jtag_elf_run(preload_elf);
          fix.vip.jtag_wait_for_eoc(exit_code);
        end
        1: begin  // Serial Link
          slink_enable_tiles();  // Write control registers
          if (snitch_preload) slink_32b_elf_preload(snitch_elf, snitch_entry);
          fix.vip.slink_elf_run(preload_elf);
          fix.vip.slink_wait_for_eoc(exit_code);
        end
        2: begin  // UART
          jtag_enable_tiles();  // Write control registers
          if (snitch_preload)
            $fatal(1, "Unsupported snitch binary preload mode %d (UART)!", preload_mode);
          fix.vip.uart_debug_elf_run_and_wait(preload_elf, exit_code);
        end
        3: begin  // Fast Mode
          jtag_enable_tiles();  // Write control registers
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
      fix.vip.jtag_init();
      fix.vip.jtag_wait_for_eoc(exit_code);
    end

    // Wait for the UART to finish reading the current byte
    wait (fix.vip.uart_reading_byte == 0);

    $finish;
  end

endmodule
