// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

import "DPI-C" function byte read_elf(input string filename);
import "DPI-C" function byte get_entry(output longint entry);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

// Write a 32-bit word into an `tc_sram` at a given address
task automatic fastmode_write_word(input longint addr, input logic [31:0] data);
  import floo_picobello_noc_pkg::*;
  // TODO(fischeti): Make this better parametrizable
  if (addr >= Sam[L2Spm+1].start_addr && addr < Sam[L2Spm+1].end_addr) begin
    automatic int word_offset = (addr - Sam[L2Spm+1].start_addr) / (AxiCfgW.DataWidth / 8);
    automatic int byte_offset = (addr - Sam[L2Spm+1].start_addr) % (AxiCfgW.DataWidth / 8);
    fix.dut.i_mem_tile.i_mem.sram[word_offset][byte_offset*8 +: 32] = data;
  end else if (addr >= Sam[Cheshire+1].start_addr && addr < Sam[Cheshire+1].end_addr) begin
    // TODO(fischeti): Implement Cheshire SPM fast preload
    $fatal(1, "[FAST_PRELOAD] Cheshire memory region not supported yet");
  end else begin
    $fatal(1, "[FAST_PRELOAD] Address 0x%h not in any supported memory region", addr);
  end

endtask

// Instantly preload an ELF binary
task automatic fastmode_elf_preload(input string binary, output cheshire_pkg::doub_bt entry);
  longint sec_addr, sec_len, bus_offset, write_addr;
  $display("[FAST_PRELOAD] Preloading ELF binary: %s", binary);
  if (read_elf(binary))
    $fatal(1, "[FAST_PRELOAD] Failed to load ELF!");
  while (get_section(sec_addr, sec_len)) begin
    byte bf[] = new [sec_len];
    $display("[FAST_PRELOAD] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
    if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[SLINK] Failed to read ELF section!");
    if (sec_addr % 4 != 0 || sec_len % 4 != 0) $fatal(1, "[FAST_PRELOAD] Section address or length not word-aligned");
    for (int i = 0; i < sec_len; i += 4) begin
      write_addr = sec_addr + i;
      fastmode_write_word(write_addr, {bf[i+3], bf[i+2], bf[i+1], bf[i]});
    end
  end
  void'(get_entry(entry));
  $display("[FAST_PRELOAD] Preload complete");
endtask
