// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

import "DPI-C" function byte read_elf(input string filename);
import "DPI-C" function byte get_entry(output longint entry);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

// FAST_PRELOAD mode trick with virtual class to write directly to L2 sram module inside various for generate
virtual class virtual_class_fastmode_write_l2;
  pure virtual task write_word(input int sram_addr, input int byte_offset, input logic [31:0] data);
endclass

virtual_class_fastmode_write_l2 l2_sram_class_writer_list[NumMemTiles][NumBanksPerWord][NumBankRows];

for(genvar i = 0; i < NumMemTiles; i++) begin : gen_fastmode_writer_class_per_l2_tile
  for(genvar j = 0; j < NumBanksPerWord; j++) begin : gen_fastmode_writer_class_per_l2_col
    for(genvar k = 0; k < NumBankRows; k++) begin : gen_fastmode_writer_class_per_l2_row
      class class_fastmode_write_l2 extends virtual_class_fastmode_write_l2;
        function new;
          l2_sram_class_writer_list[i][j][k] = this;
        endfunction
        task write_word(input int sram_addr, input int byte_offset, input logic [31:0] data);
          fix.dut.gen_memtile[i].i_mem_tile.gen_sram_banks[j].gen_sram_macros[k].i_mem.sram[sram_addr][byte_offset*8 +: 32] = data;
        endtask
      endclass
      class_fastmode_write_l2 w = new;
    end : gen_fastmode_writer_class_per_l2_row
  end : gen_fastmode_writer_class_per_l2_col
end : gen_fastmode_writer_class_per_l2_tile

// Write a 32-bit word into an `tc_sram` at a given address
task automatic fastmode_write_word(input longint addr, input logic [31:0] data);
  import floo_picobello_noc_pkg::*;
  if (addr >= Sam[L2Spm0SamIdx].start_addr && addr < Sam[L2Spm0SamIdx+NumMemTiles-1].end_addr) begin
    // Selecting the correct mem_tile, sram bank, sram address and byte offset inside sram word
    int byte_offset  = addr[0                   +: SramByteOffsetWidth ];
    int sel_bank_col = addr[SramBankSelOffset   +: SramBankSelWidth    ];
    int sram_addr    = addr[SramAddrWidthOffset +: SramAddrWidth       ];
    int sel_bank_row = addr[SramMacroSelOffset  +: SramMacroSelWidth   ];
    int sel_mem_tile = (addr - Sam[L2Spm0SamIdx].start_addr) / MemTileSize;
    l2_sram_class_writer_list[sel_mem_tile][sel_bank_col][sel_bank_row].write_word(sram_addr, byte_offset, data);
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
    if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[FAST_PRELOAD] Failed to read ELF section!");
    if (sec_addr % 4 != 0 || sec_len % 4 != 0) $fatal(1, "[FAST_PRELOAD] Section address or length not word-aligned");
    for (int i = 0; i < sec_len; i += 4) begin
      write_addr = sec_addr + i;
      fastmode_write_word(write_addr, {bf[i+3], bf[i+2], bf[i+1], bf[i]});
    end
  end
  void'(get_entry(entry));
  $display("[FAST_PRELOAD] Preload complete");
endtask
