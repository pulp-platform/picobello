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

  // TODO: make this better parametrizable
  localparam int unsigned NumXMesh = 3;
  localparam int unsigned NumYMesh = 2;
  localparam int unsigned NumClusters = Cheshire - ClusterX0Y0;
  localparam int unsigned NumTiles = NumXMesh * NumYMesh;

  // Whether the connection is a tie-off or a valid neighbor
  function automatic bit is_tie_off(int x, int y, route_direction_e dir);
    return (x == 0 && dir == West) || (x == NumXMesh-1 && dir == East) ||
           (y == 0 && dir == South) || (y == NumYMesh-1 && dir == North);
  endfunction

  // Returns the X-coordinate of the neighbor in the given direction
  function automatic int neighbor_x(int x, route_direction_e dir);
    return (dir == West) ? x-1 : (dir == East) ? x+1 : x;
  endfunction

  // Returns the Y-coordinate of the neighbor in the given direction
  function automatic int neighbor_y(int y, route_direction_e dir);
    return (dir == South) ? y-1 : (dir == North) ? y+1 : y;
  endfunction

  // Returns the opposite direction
  function automatic route_direction_e opposite_dir(route_direction_e dir);
    return (dir == West) ? East : (dir == East) ? West : (dir == South) ? North : South;
  endfunction

  // Returns the address size of a FlooNoC endpoint
  function automatic int unsigned ep_addr_size(ep_id_e ep);
    return Sam[ep].end_addr - Sam[ep].start_addr;
  endfunction

  ////////////////
  //  Cheshire  //
  ////////////////

  // Define function to derive configuration from Cheshire defaults.
  function automatic cheshire_pkg::cheshire_cfg_t gen_cheshire_cfg();
    cheshire_pkg::cheshire_cfg_t ret = cheshire_pkg::DefaultCfg;
    // Enable the external AXI master and slave interfaces
    ret.AxiExtNumMst = 1;
    ret.AxiExtNumSlv = 1;
    ret.AxiExtNumRules = 1;
    ret.AxiExtRegionIdx[0] = 0;
    ret.AxiExtRegionStart[0] = 'h2000_0000;
    ret.AxiExtRegionEnd[0] = 'h8000_0000;
    // TODO(fischeti): Currently, I don't see a reason to have a CIE region
    // Which is why we just put the CIE region after the on-chip region for now
    ret.Cva6ExtCieOnTop = 1;
    ret.Cva6ExtCieLength = 'h2000_0000;
    ret.AddrWidth = aw_bt'(AxiCfgN.AddrWidth);
    ret.AxiDataWidth = dw_bt'(AxiCfgN.DataWidth);
    ret.AxiUserWidth = dw_bt'(max(AxiCfgN.UserWidth, AxiCfgW.UserWidth));
    ret.AxiMstIdWidth = aw_bt'(max(AxiCfgN.OutIdWidth, AxiCfgW.OutIdWidth));
    // TODO(fischeti): Check if we need external interrupts for each hart/cluster
    ret.NumExtIrqHarts = doub_bt'(NumClusters);
    // TODO(fischeti): Check if we need/want VGA
    ret.Vga = 1'b0;
    // TODO(fischeti): Check if we need/want USB
    ret.Usb = 1'b0;
    // TODO(fischeti): Check if we need/want an AXI to DRAM
    ret.LlcOutRegionStart = 'h8000_0000;
    ret.LlcOutRegionEnd = 48'h1_0000_0000;
    return ret;
  endfunction

  localparam cheshire_cfg_t CheshireCfg = gen_cheshire_cfg();

  ////////////////
  //  Mem Tile  //
  ////////////////

  // TODO(fischeti): Fix the index in FlooGen
  // The L2 SPM memory size of every mem tile
  localparam int unsigned MemTileSize = ep_addr_size(ep_id_e'(L2Spm+1));

endpackage
