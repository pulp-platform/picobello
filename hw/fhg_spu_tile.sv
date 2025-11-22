// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Riccardo Fiorani Gallotta <riccardo.fiorani3@unibo.it>

`include "axi/assign.svh"

module fhg_spu_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
(
  input  logic                            clk_i,
  input  logic                            rst_ni,
  input  logic                            test_enable_i,
  input  logic                            tile_clk_en_i,
  input  logic                            tile_rst_ni,
  input  logic                            clk_rst_bypass_i,
  // Cluster ports
  input  logic                      [8:0] debug_req_i,
  input  logic                      [8:0] meip_i,
  input  logic                      [8:0] mtip_i,
  input  logic                      [8:0] msip_i,
  input  logic                      [9:0] hart_base_id_i,
  input  snitch_cluster_pkg::addr_t       cluster_base_addr_i,
  // Chimney ports
  input  id_t                             id_i,
  // Router ports
  output floo_req_t                       floo_req_west_o,
  input  floo_rsp_t                       floo_rsp_west_i,
  output floo_wide_t                      floo_wide_west_o,
  input  floo_req_t                       floo_req_west_i,
  output floo_rsp_t                       floo_rsp_west_o,
  input  floo_wide_t                      floo_wide_west_i,
  output floo_req_t                       floo_req_north_o,
  input  floo_rsp_t                       floo_rsp_north_i,
  output floo_wide_t                      floo_wide_north_o,
  input  floo_req_t                       floo_req_north_i,
  output floo_rsp_t                       floo_rsp_north_o,
  input  floo_wide_t                      floo_wide_north_i
);

  ////////////
  // Router //
  ////////////

  floo_req_t [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_in;
  floo_wide_t [Eject:North] router_floo_wide_out;

  floo_nw_router #(
    .AxiCfgN     (AxiCfgN),
    .AxiCfgW     (AxiCfgW),
    .RouteAlgo   (RouteCfg.RouteAlgo),
    .NumRoutes   (5),
    .InFifoDepth (2),
    .OutFifoDepth(2),
    .id_t        (id_t),
    .hdr_t       (hdr_t),
    .floo_req_t  (floo_req_t),
    .floo_rsp_t  (floo_rsp_t),
    .floo_wide_t (floo_wide_t),
    // .floo_wide_out_t (floo_wide_double_t),
    .NumWideVirtChannels (2),
    .NumWidePhysChannels (2)
  ) i_router (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .id_route_map_i('0),
    .floo_req_i    (router_floo_req_in),
    .floo_rsp_o    (router_floo_rsp_out),
    .floo_req_o    (router_floo_req_out),
    .floo_rsp_i    (router_floo_rsp_in),
    .floo_wide_i   (router_floo_wide_in),
    .floo_wide_o   (router_floo_wide_out),
    // Wide Reduction offload port
    .offload_wide_req_op_o          (),
    .offload_wide_req_operand1_o    (),
    .offload_wide_req_operand2_o    (),
    .offload_wide_req_valid_o       (),
    .offload_wide_req_ready_i       ('0),
    .offload_wide_resp_result_i     ('0),
    .offload_wide_resp_valid_i      ('0),
    .offload_wide_resp_ready_o      (),
    // Narrow Reduction offload port
    .offload_narrow_req_op_o        (),
    .offload_narrow_req_operand1_o  (),
    .offload_narrow_req_operand2_o  (),
    .offload_narrow_req_valid_o     (),
    .offload_narrow_req_ready_i     ('0),
    .offload_narrow_resp_result_i   ('0),
    .offload_narrow_resp_valid_i    ('0),
    .offload_narrow_resp_ready_o    ()
  );

  assign floo_req_west_o            = router_floo_req_out[West];
  assign floo_req_north_o           = router_floo_req_out[North];
  assign router_floo_req_in[West]   = floo_req_west_i;
  assign router_floo_req_in[South]  = '0;  // No South port in this tile
  assign router_floo_req_in[East]   = '0;  // No East port in this tile
  assign router_floo_req_in[North]  = floo_req_north_i;
  assign floo_rsp_west_o            = router_floo_rsp_out[West];
  assign floo_rsp_north_o           = router_floo_rsp_out[North];
  assign router_floo_rsp_in[West]   = floo_rsp_west_i;
  assign router_floo_rsp_in[South]  = '0;  // No South port in this tile
  assign router_floo_rsp_in[East]   = '0;  // No East port in this tile
  assign router_floo_rsp_in[North]  = floo_rsp_north_i;
  // assign floo_wide_west_o.valid     = router_floo_wide_out[West].valid;
  // assign floo_wide_west_o.ready     = router_floo_wide_out[West].ready;
  // assign floo_wide_west_o.wide      = router_floo_wide_out[West].wide[0];
  // assign floo_wide_north_o.valid    = router_floo_wide_out[North].valid;
  // assign floo_wide_north_o.ready    = router_floo_wide_out[North].ready;
  // assign floo_wide_north_o.wide     = router_floo_wide_out[North].wide[0];
  assign floo_wide_west_o           = router_floo_wide_out[West];
  assign floo_wide_north_o          = router_floo_wide_out[North];
  assign router_floo_wide_in[West]  = floo_wide_west_i;
  assign router_floo_wide_in[South] = '0;  // No South port in this tile
  assign router_floo_wide_in[East]  = '0;  // No East port in this tile
  assign router_floo_wide_in[North] = floo_wide_north_i;

  // It's actually a dummy tile: tie the router’s Eject input ports to 0
  assign router_floo_req_in[Eject]  = '0;
  assign router_floo_rsp_in[Eject]  = '0;
  assign router_floo_wide_in[Eject] = '0;

endmodule : fhg_spu_tile
