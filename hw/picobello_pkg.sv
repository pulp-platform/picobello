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

  function automatic mesh_dim_t get_mesh_dim();
    mesh_dim_t tile_id_max = '{x: 0, y: 0};
    mesh_dim_t tile_id_min = '{x: '1, y: '1};
    for (int i = 0; i < SamNumRules; i++) begin
      tile_id_max.x = max(tile_id_max.x, int'(Sam[i].idx.x));
      tile_id_max.y = max(tile_id_max.y, int'(Sam[i].idx.y));
      tile_id_min.x = min(tile_id_min.x, int'(Sam[i].idx.x));
      tile_id_min.y = min(tile_id_min.y, int'(Sam[i].idx.y));
    end
    return '{x: tile_id_max.x - tile_id_min.x + 1, y: tile_id_max.y - tile_id_min.y + 1};
  endfunction

  localparam mesh_dim_t MeshDim = get_mesh_dim();
  localparam int unsigned NumTiles = MeshDim.x * MeshDim.y;
  localparam int unsigned NumClusters = Cheshire - ClusterX0Y0;
  localparam int unsigned NumMemTiles = NumEndpoints - L2Spm0;

  // Generate a bitmap for existing tiles.
  // Fill non-existent tiles with dummy tiles.
  typedef logic [MeshDim.x-1:0][MeshDim.y-1:0] mesh_map_t;

  function automatic mesh_map_t get_mesh_map();
    mesh_map_t mesh_map = '0;
    for (int i = 0; i < SamNumRules; i++) begin
      mesh_map[Sam[i].idx.x][Sam[i].idx.y] = 1'b1;
    end
    return mesh_map;
  endfunction

  localparam mesh_map_t MeshMap = get_mesh_map();
  localparam int unsigned NumDummyTiles = NumTiles - $countones(MeshMap);

  // Generate location map for Dummy tiles
  typedef id_t [NumDummyTiles-1:0] dummy_idx_t;

  function automatic dummy_idx_t get_dummy_idx(mesh_map_t MeshMap, int Dim_x, int Dim_y);
    dummy_idx_t  dummy_idx;
    int unsigned cnt = 0;

    for (int i = 0; i < Dim_x; i++) begin
      for (int j = 0; j < Dim_y; j++) begin
        if (MeshMap[i][j] == 1'b0) begin
          dummy_idx[cnt] = '{x : i, y : j, port_id: 0};
          cnt++;
        end
      end
    end
    return dummy_idx;
  endfunction

  localparam dummy_idx_t DummyIdx = get_dummy_idx(MeshMap, MeshDim.x, MeshDim.y);

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

  ////////////////
  //  Cheshire  //
  ////////////////

  // Define function to derive configuration from Cheshire defaults.
  function automatic cheshire_pkg::cheshire_cfg_t gen_cheshire_cfg();
    cheshire_pkg::cheshire_cfg_t ret = cheshire_pkg::DefaultCfg;
    // Enable the external AXI master and slave interfaces
    ret.AxiExtNumMst         = 1;
    ret.AxiExtNumSlv         = 1;
    ret.AxiExtNumRules       = 1;
    ret.AxiExtRegionIdx[0]   = 0;
    ret.AxiExtRegionStart[0] = 'h2000_0000;
    ret.AxiExtRegionEnd[0]   = 'h8000_0000;
    // TODO(fischeti): Currently, I don't see a reason to have a CIE region
    // Which is why we just put the CIE region after the on-chip region for now
    ret.Cva6ExtCieOnTop      = 1;
    ret.Cva6ExtCieLength     = 'h2000_0000;
    ret.AddrWidth            = aw_bt'(AxiCfgN.AddrWidth);
    ret.AxiDataWidth         = dw_bt'(AxiCfgN.DataWidth);
    ret.AxiUserWidth         = dw_bt'(max(AxiCfgN.UserWidth, AxiCfgW.UserWidth));
    ret.AxiMstIdWidth        = aw_bt'(max(AxiCfgN.OutIdWidth, AxiCfgW.OutIdWidth));
    // TODO(fischeti): Check if we need external interrupts for each hart/cluster
    ret.NumExtIrqHarts       = doub_bt'(NumClusters);
    // TODO(fischeti): Check if we need/want VGA
    ret.Vga                  = 1'b0;
    // TODO(fischeti): Check if we need/want USB
    ret.Usb                  = 1'b0;
    // TODO(fischeti): Add Serial Link to LLC AXI port
    ret.LlcOutRegionStart    = 'h8000_0000;
    ret.LlcOutRegionEnd      = dw_bt'('h12_0000_0000);
    ret.SlinkRegionStart     = dw_bt'('h100_0000_0000);
    ret.SlinkRegionEnd       = dw_bt'('h200_0000_0000);
    return ret;
  endfunction

  localparam cheshire_cfg_t CheshireCfg = gen_cheshire_cfg();

  ////////////////
  //  Mem Tile  //
  ////////////////

  // The L2 SPM memory size of every mem tile
  localparam int unsigned MemTileSize = ep_addr_size(L2Spm0SamIdx);

endpackage
