// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "cheshire/typedef.svh"

package picobello_pkg;

  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import cheshire_pkg::*;
  import snitch_cluster_pkg::*;

  typedef axi_narrow_in_addr_t addr_t;

  ///////////////
  //  FlooNoC  //
  ///////////////

  typedef struct packed {
    int unsigned x;
    int unsigned y;
  } mesh_dim_t;

  // This function return the MAX X and Y coordinates, regardless of empty columns.
  function automatic mesh_dim_t get_max_id();
    mesh_dim_t tile_id_max = '{x: 0, y: 0};
    mesh_dim_t tile_id_min = '{x: '1, y: '1};
    for (int i = 0; i < SamNumRules; i++) begin
      tile_id_max.x = max(tile_id_max.x, int'(Sam[i].idx.x));
      tile_id_max.y = max(tile_id_max.y, int'(Sam[i].idx.y));
    end
    return '{x: tile_id_max.x, y: tile_id_max.y};
  endfunction

  function automatic mesh_dim_t get_min_id();
    mesh_dim_t tile_id_max = '{x: 0, y: 0};
    mesh_dim_t tile_id_min = '{x: '1, y: '1};
    for (int i = 0; i < SamNumRules; i++) begin
      tile_id_min.x = min(tile_id_min.x, int'(Sam[i].idx.x));
      tile_id_min.y = min(tile_id_min.y, int'(Sam[i].idx.y));
    end
    return '{x: tile_id_min.x, y: tile_id_min.y};
  endfunction

  localparam mesh_dim_t MaxId = get_max_id();
  localparam mesh_dim_t MinId = get_min_id();
  typedef logic [MaxId.y:0][MaxId.x:0] mesh_map_t;

  localparam mesh_map_t MeshMap = get_mesh_map();

  // Generate a bitmap of the NoC mesh.
  // Non existing tiles are set to 0.
  function automatic mesh_map_t get_mesh_map();
    mesh_map_t mesh_map = '0;
    for (int i = 0; i < SamNumRules; i++) begin
      mesh_map[Sam[i].idx.y][Sam[i].idx.x] = 1'b1;
    end
    return mesh_map;
  endfunction

  function automatic mesh_dim_t get_mesh_dim();
    int unsigned column_cnt = 0;
    int unsigned row_cnt = 0;
    // Count the number of columns that have at least one tile
    for (int col = 0; col <= MaxId.x; col++) begin
      for (int row = 0; row <= MaxId.y; row++) begin
        if (MeshMap[row][col] == 1'b1) begin
          column_cnt++;
          break;
        end
      end
    end
    // Count the number of rows that have at least one tile
    for (int row = 0; row <= MaxId.y; row++) begin
      if ($countones(MeshMap[row]) > 0) begin
        row_cnt++;
      end
    end
    return '{x: column_cnt, y: row_cnt};
  endfunction

  localparam mesh_dim_t MeshDim = get_mesh_dim();
  localparam int unsigned NumTiles = MeshDim.x * MeshDim.y;
  localparam int unsigned NumClusters = Cheshire - ClusterX0Y0;
  localparam int unsigned NumMemTiles = NumEndpoints - L2Spm0;

  localparam int unsigned NumDummyTiles = NumTiles - $countones(MeshMap);


  // This function will generate a bit map indicating which columns are empty.
  // An bit set to 1 in the map indicates an empty column.
  function automatic bit [MaxId.x:0] get_empty_cols(mesh_map_t MeshMap);
    bit [MaxId.x:0] empty_cols;
    // Initialize all columns as empty
    empty_cols = '1;
    // Loop over the mesh map and set the non empty columns to 0
    for (int col = 0; col <= MaxId.x; col++) begin
      for (int row = 0; row <= MaxId.y; row++) begin
        if (MeshMap[row][col] == 1'b1) begin
          empty_cols[col] = 1'b0;
          break;
        end
      end
    end
    return empty_cols;
  endfunction

  // This function will generate a bit map indicating which columns are empty.
  // An bit set to 1 in the map indicates an empty column.
  function automatic bit [MaxId.y:0] get_empty_rows(mesh_map_t MeshMap);
    bit [MaxId.y:0] empty_rows;
    // Initialize all columns as empty
    empty_rows = '1;
    // Loop over the mesh map and set the non empty columns to 0
    for (int row = 0; row <= MaxId.y; row++) begin
      for (int col = 0; col <= MaxId.x; col++) begin
        if (MeshMap[row][col] == 1'b1) begin
          empty_rows[row] = 1'b0;
          break;
        end
      end
    end
    return empty_rows;
  endfunction

  // This function loops over the System Address Map (SAM) and shifts the X coordinate
  // of each tile to the left if there are empty columns on its left. This adjustment
  // ensures that all tiles are properly connected, regardless of any XY coordinate offset.
  // It preserves all other fields of each SAM rule.
  function automatic sam_rule_t [SamNumRules-1:0] align_x_coordinate(
      sam_rule_t [SamNumRules-1:0] sam_to_convert, bit [MaxId.x:0] empty_cols);

    sam_rule_t   [SamNumRules-1:0] ret_sam;
    int unsigned                   left_empty_cols;
    int unsigned                   current_x;

    for (int rule = 0; rule < SamNumRules; rule++) begin
      current_x       = int'(sam_to_convert[rule].idx.x);
      left_empty_cols = 0;

      // Count how many empty columns are to the left of the current tile
      for (int col = 0; col < current_x; col++) begin
        if (empty_cols[col] == 1'b1) begin
          left_empty_cols++;
        end
      end

      // Shift the X coordinate if there are empty columns to the left
      if (left_empty_cols > 0) begin
        ret_sam[rule].idx.x = sam_to_convert[rule].idx.x - left_empty_cols;
      end else begin
        ret_sam[rule].idx.x = sam_to_convert[rule].idx.x;
      end

      // Copy the remaining fields of the rule
      ret_sam[rule].idx.y       = sam_to_convert[rule].idx.y;
      ret_sam[rule].idx.port_id = sam_to_convert[rule].idx.port_id;
      ret_sam[rule].start_addr  = sam_to_convert[rule].start_addr;
      ret_sam[rule].end_addr    = sam_to_convert[rule].end_addr;
    end
    return ret_sam;
  endfunction

  // To support multicast, the X and Y coordinates of the first tile in a multicast
  // group must be powers of two. For this reason, in the Picobello system, the second
  // column begins with an offset to associate X = 4 with Cluster 0.
  //
  // This offset introduces empty columns in the System Address Map (SAM). Therefore,
  // to properly connect all the tiles, we need to regenerate the SAM to reflect the
  // physical topology (i.e., 7×4), ensuring that the tiles are aligned and connected
  // correctly within the adjusted coordinate space.
  localparam bit [MaxId.x:0] EmptyCols = get_empty_cols(MeshMap);
  localparam sam_rule_t [SamNumRules-1:0] SamPhysical = align_x_coordinate(
      floo_picobello_noc_pkg::Sam, EmptyCols
  );

  // Dummy tiles X, Y coordinates
  typedef id_t [NumDummyTiles-1:0] dummy_idx_t;

  // This function is used to identify
  function automatic dummy_idx_t get_dummy_idx(mesh_map_t MeshMap, int Dim_x, int Dim_y);
    dummy_idx_t  dummy_idx;
    int unsigned empty_tile = 0;
    int unsigned found_tiles = 0;

    // Count the number of columns that have at least one tile
    for (int col = 0; col <= MaxId.x; col++) begin
      // Clear counter for the next column
      empty_tile = 0;
      for (int row = 0; row <= MaxId.y; row++) begin
        if (MeshMap[row][col] == 1'b1) begin
        end else if (empty_tile <= MaxId.y) begin
          // If the tile is empty, we can add it to the dummy index
          dummy_idx[found_tiles] = '{x : col, y : row, port_id: 0};
          found_tiles++;
          empty_tile++;
        end else begin
          // If the full column is empty, we don't need to insert dummy tiles
          found_tiles -= empty_tile;
          break;
        end
      end
    end
    return dummy_idx;
  endfunction

  // localparam dummy_idx_t DummyIdx = get_dummy_idx(MeshMap, MeshDim.x, MeshDim.y);
  localparam dummy_idx_t DummyIdx = '{'{x: 9, y: 2, port_id: 1}, '{x: 9, y: 1, port_id: 0}};
  localparam dummy_idx_t DummyPhysicalIdx = '{
      '{x: 6, y: 2, port_id: 1},
      '{x: 6, y: 1, port_id: 0}
  };


  // Whether the connection is a tie-off or a valid neighbor
  function automatic bit is_tie_off(int x, int y, route_direction_e dir);
    return (x == 0 && dir == West) || (x == MeshDim.x-1 && dir == East) ||
           (y == 0 && dir == South) || (y == MeshDim.y-1 && dir == North);
  endfunction

  // Returns the X-coordinate of the neighbor in the given direction
  function automatic int neighbor_x(int x, route_direction_e dir);
    return (dir == West) ? x - 1 : (dir == East) ? x + 1 : x;
  endfunction

  // Returns the Y-coordinate of the neighbor in the given direction
  function automatic int neighbor_y(int y, route_direction_e dir);
    return (dir == South) ? y - 1 : (dir == North) ? y + 1 : y;
  endfunction

  // Returns the opposite direction
  function automatic route_direction_e opposite_dir(route_direction_e dir);
    return (dir == West) ? East : (dir == East) ? West : (dir == South) ? North : South;
  endfunction

  // Returns the address size of a FlooNoC endpoint
  function automatic int unsigned ep_addr_size(sam_idx_e ep);
    return Sam[ep].end_addr - Sam[ep].start_addr;
  endfunction

  /////////////////////
  //   MULTICAST     //
  /////////////////////

  // Helper functions to support the multicast feature.
  //
  // The original System Address Map (SAM) must be modified to encode, within the `idx` field,
  // additional information needed to translate the address base mask into an X/Y coordinate-based mask.
  //
  // The additional fields are:
  // - `offset_id_x`: the offset in the tile address where the X coordinate encoding starts
  // - `len_id_x`:    the number of bits used to encode the X coordinate
  // - `offset_id_y`: the offset in the tile address where the Y coordinate encoding starts
  // - `len_id_y`:    the number of bits used to encode the Y coordinate

  // Support multicast only for cluster tiles.
  // TODO(lleone): Extend multicast feature for Memory tiles as well
  localparam int unsigned NumMcastEndPoints = NumClusters;

  typedef logic [aw_bt'(AxiCfgN.AddrWidth)-1:0] user_mask_t;

  typedef struct packed {
    user_mask_t                                   mcast_mask;
    logic [snitch_cluster_pkg::AtomicIdWidth-1:0] atomic;
  } mcast_user_t;

  function automatic floo_pkg::route_cfg_t gen_nomcast_route_cfg();
    floo_pkg::route_cfg_t ret = floo_picobello_noc_pkg::RouteCfg;
    // Disable multicast for non-cluster tiles
    ret.EnMultiCast = 1'b0;
    return ret;
  endfunction

  // Define no multicast RouteCfg for Memory tiles, Chehsihre and FhG
  localparam floo_pkg::route_cfg_t RouteCfgNoMcast = gen_nomcast_route_cfg();

  ////////////////
  //  Cheshire  //
  ////////////////

  typedef enum bit [MaxExtRegSlvWidth-1:0] {
    CshRegExtDramSerialLink = 0,  // Serial link to DRAM
    CshRegExtFLL            = 1,  // FLL registers
    CshRegExtChipCtrl       = 2,  // Chip-level registers
    CshRegExtClkGatingRst   = 3,  // Tile-specific clock gating and reset control
    CshRegExtNumSlv         = 4   // Number of external register slaves
  } cheshire_reg_ext_e;

  // Define function to derive configuration from Cheshire defaults.
  function automatic cheshire_pkg::cheshire_cfg_t gen_cheshire_cfg();
    cheshire_pkg::cheshire_cfg_t ret = cheshire_pkg::DefaultCfg;
    // Enable the external AXI master and slave interfaces
    ret.AxiExtNumMst         = 1;
    ret.AxiExtNumSlv         = 1;
    ret.AxiExtNumRules       = 1;
    ret.RegExtNumSlv         = CshRegExtNumSlv;
    ret.RegExtNumRules       = CshRegExtNumSlv;
    ret.AxiExtRegionIdx[0]   = 0;
    ret.AxiExtRegionStart[0] = 'h2000_0000;
    ret.AxiExtRegionEnd[0]   = 'h8000_0000;
    ret.RegExtRegionIdx[0]   = CshRegExtDramSerialLink;
    ret.RegExtRegionStart[0] = 'h1800_0000;
    ret.RegExtRegionEnd[0]   = 'h1800_1000;
    ret.RegExtRegionIdx[1]   = CshRegExtFLL;
    ret.RegExtRegionStart[1] = 'h1800_1000;
    ret.RegExtRegionEnd[1]   = 'h1800_2000;
    ret.RegExtRegionIdx[2]   = CshRegExtChipCtrl;
    ret.RegExtRegionStart[2] = 'h1800_2000;
    ret.RegExtRegionEnd[2]   = 'h1800_3000;
    ret.RegExtRegionIdx[3]   = CshRegExtClkGatingRst;
    ret.RegExtRegionStart[3] = 'h1800_3000;
    ret.RegExtRegionEnd[3]   = 'h1800_4000;
    // TODO(fischeti): Currently, I don't see a reason to have a CIE region
    // Which is why we just set the CIE region to size 0 for now
    ret.Cva6ExtCieOnTop      = 0;
    ret.Cva6ExtCieLength     = 'h0;
    ret.AddrWidth            = aw_bt'(AxiCfgN.AddrWidth);
    ret.AxiDataWidth         = dw_bt'(AxiCfgN.DataWidth);
    ret.AxiUserWidth         = dw_bt'(max(AxiCfgN.UserWidth, AxiCfgW.UserWidth));
    ret.AxiMstIdWidth        = aw_bt'(max(AxiCfgN.OutIdWidth, AxiCfgW.OutIdWidth));
    // TODO(fischeti): Check if we need external interrupts for each hart/cluster
    ret.NumExtIrqHarts       = doub_bt'(NumClusters);
    // We do not need/want VGA
    ret.Vga                  = 1'b0;
    // We do not need/want USB
    ret.Usb                  = 1'b0;
    ret.LlcOutRegionStart    = 'h8000_0000;
    ret.LlcOutRegionEnd      = 'h12_0000_0000;
    ret.SlinkRegionStart     = 'h100_0000_0000;
    ret.SlinkRegionEnd       = 'h200_0000_0000;
    return ret;
  endfunction

  localparam cheshire_cfg_t CheshireCfg = gen_cheshire_cfg();

  `CHESHIRE_TYPEDEF_ALL(csh_, CheshireCfg)

  ////////////////
  //  Mem Tile  //
  ////////////////

  // The L2 SPM memory size of every mem tile
  localparam int unsigned MemTileSize = ep_addr_size(L2Spm0SamIdx);
  // The maximum data width of the instantiated SRAMs
  localparam int unsigned SramDataWidth = 128;  // in bits
  // The number of words in the instantiated SRAMs
  localparam int unsigned SramNumWords = 1024;  // in #words

  // The number of banks required to store a wide word
  localparam int unsigned NumBanksPerWord = AxiCfgW.DataWidth / SramDataWidth;
  // The number of macros required to store the entire memory
  localparam int unsigned NumBankRows = (MemTileSize / (AxiCfgW.DataWidth / 8)) / SramNumWords;

  // The number of LSBs to address the bytes in an SRAM word
  localparam int unsigned SramByteOffsetWidth = $clog2(SramDataWidth / 8);
  // The number of bits required to select the subbank for a wide word
  localparam int unsigned SramBankSelWidth = $clog2(NumBanksPerWord);
  // The number of bits for the SRAM address
  localparam int unsigned SramAddrWidth = $clog2(SramNumWords);
  // The number of bits to index the SRAM macro
  localparam int unsigned SramMacroSelWidth = $clog2(NumBankRows);

  // Various offsets for the SRAM address
  localparam int unsigned SramBankSelOffset = SramByteOffsetWidth;
  localparam int unsigned SramAddrWidthOffset = SramBankSelOffset + SramBankSelWidth;
  localparam int unsigned SramMacroSelOffset = SramAddrWidthOffset + SramAddrWidth;

  ////////////////////////
  //  SPM Narrow Tiles  //
  ////////////////////////

  // Narrow SPM tile size
  localparam int unsigned SpmNarrowTileSize = ep_addr_size(TopSpmNarrowSamIdx);
  // Narrow SPM number words per bank
  localparam int unsigned SpmNarrowWordsPerBank = 2048;  // in #words
  // Narrow SPM dataWidth
  localparam int unsigned SpmNarrowDataWidth = 64;  // in bits

  // Narrow SPM number of banks per word
  localparam int unsigned SpmNarrowNumBanksPerWord = AxiCfgN.DataWidth / SpmNarrowDataWidth;
  // Narrow SPM number of bank rows
  localparam int unsigned SpmNarrowNumBankRows = (SpmNarrowTileSize / (AxiCfgN.DataWidth / 8)
                                                 / SpmNarrowWordsPerBank);

  // The number of LSBs to address the bytes in an SRAM word
  localparam int unsigned SpmNarrowByteOffsetWidth = $clog2(SpmNarrowDataWidth / 8);
  // The number of bits required to select the subbank for a Narrow word
  localparam int unsigned SpmNarrowBankSelWidth = $clog2(SpmNarrowNumBanksPerWord);
  // The number of bits for the SpmNarrow address
  localparam int unsigned SpmNarrowAddrWidth = $clog2(SpmNarrowWordsPerBank);
  // The number of bits to index the SpmNarrow macro
  localparam int unsigned SpmNarrowMacroSelWidth = $clog2(SpmNarrowNumBankRows);

  // Various offsets for the SpmNarrow address
  localparam int unsigned SpmNarrowBankSelOffset = SpmNarrowByteOffsetWidth;
  localparam int unsigned SpmNarrowAddrWidthOffset = SpmNarrowBankSelOffset + SpmNarrowBankSelWidth;
  localparam int unsigned SpmNarrowMacroSelOffset = SpmNarrowAddrWidthOffset + SpmNarrowAddrWidth;


  //////////////////////
  //  SPM Wide Tiles  //
  //////////////////////

  // Wide SPM tile
  localparam int unsigned SpmWideTileSize = ep_addr_size(TopSpmWideSamIdx);
  // Wide SPM number words per bank
  localparam int unsigned SpmWideWordsPerBank = 1024;  // in #words
  // Wide SPM dataWidth
  localparam int unsigned SpmWideDataWidth = 128;  // in bits

  // Wide SPM number of banks per word
  localparam int unsigned SpmWideNumBanksPerWord = AxiCfgW.DataWidth / SpmWideDataWidth;
  // Wide SPM number of bank rows
  localparam int unsigned SpmWideNumBankRows = (SpmWideTileSize / (AxiCfgW.DataWidth / 8)
                                               / SpmWideWordsPerBank);

  // The number of LSBs to address the bytes in an SRAM word
  localparam int unsigned SpmWideByteOffsetWidth = $clog2(SpmWideDataWidth / 8);
  // The number of bits required to select the subbank for a wide word
  localparam int unsigned SpmWideBankSelWidth = $clog2(SpmWideNumBanksPerWord);
  // The number of bits for the SpmWide address
  localparam int unsigned SpmWideAddrWidth = $clog2(SpmWideWordsPerBank);
  // The number of bits to index the SpmWide macro
  localparam int unsigned SpmWideMacroSelWidth = $clog2(SpmWideNumBankRows);

  // Various offsets for the SpmWide address
  localparam int unsigned SpmWideBankSelOffset = SpmWideByteOffsetWidth;
  localparam int unsigned SpmWideAddrWidthOffset = SpmWideBankSelOffset + SpmWideBankSelWidth;
  localparam int unsigned SpmWideMacroSelOffset = SpmWideAddrWidthOffset + SpmWideAddrWidth;


endpackage
