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
                                                  sam_rule_t [SamNumRules-1:0] sam_to_convert,
                                                  bit [MaxId.x:0] empty_cols);
    sam_rule_t [SamNumRules-1:0] ret_sam;
    int unsigned left_empty_cols;
    int unsigned current_x;

    for (int rule = 0; rule < SamNumRules; rule++) begin
      current_x = int'(sam_to_convert[rule].idx.x);
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
      ret_sam[rule].idx.y = sam_to_convert[rule].idx.y;
      ret_sam[rule].idx.port_id = sam_to_convert[rule].idx.port_id;
      ret_sam[rule].start_addr = sam_to_convert[rule].start_addr;
      ret_sam[rule].end_addr = sam_to_convert[rule].end_addr;
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
  localparam sam_rule_t [SamNumRules-1:0] SamShifted = align_x_coordinate(floo_picobello_noc_pkg::Sam, EmptyCols);

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
          break; // No more empty tiles in this column
        end
      end
    end
    return dummy_idx;
  endfunction

  // localparam dummy_idx_t DummyIdx = get_dummy_idx(MeshMap, MeshDim.x, MeshDim.y);
  localparam dummy_idx_t DummyIdx = '{
    '{x: 9, y: 2, port_id: 1},
    '{x: 9, y: 1, port_id: 0}
  };
  localparam dummy_idx_t DummyShiftedIdx = '{
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

  typedef struct packed {
    logic [5:0] offset;
    logic [2:0] len;
    logic [2:0] grp_base_id;
  } mask_sel_t;

  typedef struct packed {
    id_t       id;
    mask_sel_t mask_x;
    mask_sel_t mask_y;
  } sam_idx_t;

  typedef struct packed {
    sam_idx_t                             idx;
    logic [aw_bt'(AxiCfgN.AddrWidth)-1:0] start_addr;
    logic [aw_bt'(AxiCfgN.AddrWidth)-1:0] end_addr;
  } sam_multicast_rule_t;


  // Packed original SAM with extra information necessary for multicast handling
  function automatic sam_multicast_rule_t [SamNumRules-1:0] get_sam_multicast();
    sam_multicast_rule_t [SamNumRules-1:0] sam_multicast;

    int unsigned tileSize;
    int unsigned len_id_x, len_id_y;
    int unsigned offset_id_x, offset_id_y;
    int unsigned empty_cols, empty_rows;

    // Evaluate where the X and Y node coordinate associated with the multicast endpoints
    // are actaully located
    // clog2 returns 0 when idx.x = 1. To workaround this problem, separate the case where max idx is 1
    len_id_x    = (Sam[NumClusters-1].idx.x == 1) ? 1 : $clog2(Sam[NumClusters-1].idx.x);
    len_id_y    = (Sam[NumClusters-1].idx.y == 1) ? 1 : $clog2(Sam[NumClusters-1].idx.y);
    tileSize    = ep_addr_size(sam_idx_e'(NumClusters - 1));
    offset_id_y = $clog2(tileSize);
    offset_id_x = $clog2(tileSize) + len_id_y;

    // Evaluate the number of empty columns in the artificial MeshMap.
    // From this information calculate the base ID of the first cluster
    // in the mutlicast group.

    // TODO(lleone): This is a temporary solution. In a fully configurable system,
    // the base ID doesn't match with the number of empty rows/columns. This is
    // true only in the 7x4 mesh.
    empty_cols = $countones(get_empty_cols(MeshMap) + 1);
    empty_rows = $countones(get_empty_rows(MeshMap));

    for (int rule = 0; rule < SamNumRules; rule++) begin
      sam_multicast[rule].idx.id     = Sam[rule].idx;
      sam_multicast[rule].start_addr = Sam[rule].start_addr;
      sam_multicast[rule].end_addr   = Sam[rule].end_addr;

      // Only Cluster tiles can be target of multicast request.
      if (rule < NumMcastEndPoints) begin

        // Fill new Sam struct with the extra multicast info
        sam_multicast[rule].idx.mask_x = '{offset: offset_id_x, len: len_id_x,
                                          grp_base_id: empty_cols};
        sam_multicast[rule].idx.mask_y = '{offset: offset_id_y, len: len_id_y,
                                          grp_base_id: empty_rows};
      end else begin
        sam_multicast[rule].idx.mask_x = '{offset: '0, len: '0, grp_base_id: 0};
        sam_multicast[rule].idx.mask_y = '{offset: '0, len: '0, grp_base_id: 0};
      end

    end
    return sam_multicast;
  endfunction

  localparam sam_multicast_rule_t [SamNumRules-1:0] SamMcast = get_sam_multicast();

  function automatic floo_pkg::route_cfg_t gen_nomcast_route_cfg();
    floo_pkg::route_cfg_t ret = floo_picobello_noc_pkg::RouteCfg;
    // Disable multicast for non-cluster tiles
    ret.EnMultiCast = 1'b0;
    return ret;
  endfunction

  // Define no multicast RouteCfg for Memory tiles, Chehsihre and FhG
  localparam floo_pkg::route_cfg_t RouteCfg_NoMcast = gen_nomcast_route_cfg();

  // Print the system address map for th emulticast rules.
  // TODO(lleone): Generalize for normal address map
  function automatic print_sam_multicast(sam_multicast_rule_t [SamNumRules-1:0] sam_multicast);
    $display("\n--- [SAM] System Address Map (%0d entries) ---", SamNumRules);
    $display("[");
    for (int i = 0; i < SamNumRules; i++) begin
      $write("  { idx: { id: {x: %0d, y: %0d, port: %0d},",
             SamMcast[i].idx.id.x,
             SamMcast[i].idx.id.y,
             SamMcast[i].idx.id.port_id);
      $write("  mask_x: {offset: %0d, len: %0d, base_id: %0d},",
             SamMcast[i].idx.mask_x.offset,
             SamMcast[i].idx.mask_x.len,
             SamMcast[i].idx.mask_x.grp_base_id);
      $write("  mask_y: {offset: %0d, len: %0d, base_id: %0d} },",
             SamMcast[i].idx.mask_y.offset,
             SamMcast[i].idx.mask_y.len,
             SamMcast[i].idx.mask_y.grp_base_id);
      $write("start: 0x%0h, end: 0x%0h }\n",
             SamMcast[i].start_addr,
             SamMcast[i].end_addr);
    end
    $display("]");
    $display("----------------------------------------------------------");
    $display("NumDummyTiles: %0d", NumDummyTiles);
    $display("Mesh DIm X: %0d", MeshDim.x);
    $display("Mesh DIm Y: %0d", MeshDim.y);
    $display("MaxId: {x: %0d, y: %0d}", MaxId.x, MaxId.y);
    $display("MinId: {x: %0d, y: %0d}", MinId.x, MinId.y);
    for (int row = 0; row <= MaxId.y; row++) begin
      for (int col = 0; col <= MaxId.x; col++) begin
        $write("%0d ", MeshMap[row][col]);
      end
      $display("");
    end
    $display("\n--- SHIFTED System Address Map (%0d entries) ---", SamNumRules);
    $display("[");
    for (int i = 0; i < SamNumRules; i++) begin
      $write("  { idx: { id: {x: %0d, y: %0d, port: %0d},",
             SamShifted[i].idx.x,
             SamShifted[i].idx.y,
             SamShifted[i].idx.port_id);
      $write("start: 0x%0h, end: 0x%0h }\n",
             SamShifted[i].start_addr,
             SamShifted[i].end_addr);
    end
    $display("]");
    $display("----------------------------------------------------------");
  endfunction

  ////////////////
  //  Cheshire  //
  ////////////////

  localparam int unsigned CshRegExtDramSerialLink = 0;
  localparam int unsigned CshNumRegExt = 1;

  // Define function to derive configuration from Cheshire defaults.
  function automatic cheshire_pkg::cheshire_cfg_t gen_cheshire_cfg();
    cheshire_pkg::cheshire_cfg_t ret = cheshire_pkg::DefaultCfg;
    // Enable the external AXI master and slave interfaces
    ret.AxiExtNumMst         = 1;
    ret.AxiExtNumSlv         = 1;
    ret.AxiExtNumRules       = 1;
    ret.RegExtNumSlv         = CshNumRegExt;
    ret.RegExtNumRules       = CshNumRegExt;
    ret.AxiExtRegionIdx[0]   = 0;
    ret.AxiExtRegionStart[0] = 'h2000_0000;
    ret.AxiExtRegionEnd[0]   = 'h8000_0000;
    ret.RegExtRegionIdx[0]   = CshRegExtDramSerialLink;
    ret.RegExtRegionStart[0] = 'h1800_0000;
    ret.RegExtRegionEnd[0]   = 'h1800_1000;
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

  ////////////////
  //  Mem Tile  //
  ////////////////

  // The L2 SPM memory size of every mem tile
  localparam int unsigned MemTileSize = ep_addr_size(L2Spm0SamIdx);

endpackage
