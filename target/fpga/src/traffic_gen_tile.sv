// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"

module traffic_gen_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*; #(
    parameter int unsigned AxiLiteAddrWidth = 32,
    parameter int unsigned AxiLiteDataWidth = 32
) (
  input  logic                                    clk_i,
  input  logic                                    rst_ni,
  input  logic                                    test_enable_i,
  // Chimney ports
  input  id_t                                     id_i,
  // Router ports
  output floo_req_t                 [ West:North] floo_req_o,
  input  floo_rsp_t                 [ West:North] floo_rsp_i,
  output floo_wide_t                [ West:North] floo_wide_o,
  input  floo_req_t                 [ West:North] floo_req_i,
  output floo_rsp_t                 [ West:North] floo_rsp_o,
  input  floo_wide_t                [ West:North] floo_wide_i,
  // Host control port
  AXI_LITE.Slave                                  traffic_gen_progr
);

  ////////////
  // Router //
  ////////////

  floo_req_t [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN     (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW     (floo_picobello_noc_pkg::AxiCfgW),
    .RouteAlgo   (floo_picobello_noc_pkg::RouteCfg.RouteAlgo),
    .NumRoutes   (5),
    .InFifoDepth (2),
    .OutFifoDepth(2),
    .id_t        (floo_picobello_noc_pkg::id_t),
    .hdr_t       (floo_picobello_noc_pkg::hdr_t),
    .floo_req_t  (floo_req_t),
    .floo_rsp_t  (floo_rsp_t),
    .floo_wide_t (floo_wide_t)
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
    .floo_wide_o   (router_floo_wide_out)
  );

  assign floo_req_o                      = router_floo_req_out[West:North];
  assign router_floo_req_in[West:North]  = floo_req_i;
  assign floo_rsp_o                      = router_floo_rsp_out[West:North];
  assign router_floo_rsp_in[West:North]  = floo_rsp_i;
  assign floo_wide_o                     = router_floo_wide_out[West:North];
  assign router_floo_wide_in[West:North] = floo_wide_i;

  /////////////
  // Chimney //
  /////////////

  floo_picobello_noc_pkg::axi_narrow_in_req_t  chimney_narrow_in_req;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t  chimney_narrow_in_rsp;
  floo_picobello_noc_pkg::axi_wide_in_req_t    chimney_wide_in_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t    chimney_wide_in_rsp;

  floo_nw_chimney #(
    .AxiCfgN             (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW             (floo_picobello_noc_pkg::AxiCfgW),
    .ChimneyCfgN         (floo_pkg::set_ports(ChimneyDefaultCfg, 1'b0, 1'b1)),
    .ChimneyCfgW         (floo_pkg::set_ports(ChimneyDefaultCfg, 1'b0, 1'b1)),
    .RouteCfg            (floo_picobello_noc_pkg::RouteCfg),
    .AtopSupport         (1'b1),
    .MaxAtomicTxns       (1),
    .Sam                 (floo_picobello_noc_pkg::Sam),
    .id_t                (floo_picobello_noc_pkg::id_t),
    .rob_idx_t           (floo_picobello_noc_pkg::rob_idx_t),
    .hdr_t               (floo_picobello_noc_pkg::hdr_t),
    .sam_rule_t          (floo_picobello_noc_pkg::sam_rule_t),
    .axi_narrow_in_req_t (floo_picobello_noc_pkg::axi_narrow_in_req_t),
    .axi_narrow_in_rsp_t (floo_picobello_noc_pkg::axi_narrow_in_rsp_t),
    .axi_narrow_out_req_t(floo_picobello_noc_pkg::axi_narrow_out_req_t),
    .axi_narrow_out_rsp_t(floo_picobello_noc_pkg::axi_narrow_out_rsp_t),
    .axi_wide_in_req_t   (floo_picobello_noc_pkg::axi_wide_in_req_t),
    .axi_wide_in_rsp_t   (floo_picobello_noc_pkg::axi_wide_in_rsp_t),
    .axi_wide_out_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
    .axi_wide_out_rsp_t  (floo_picobello_noc_pkg::axi_wide_out_rsp_t),
    .floo_req_t          (floo_picobello_noc_pkg::floo_req_t),
    .floo_rsp_t          (floo_picobello_noc_pkg::floo_rsp_t),
    .floo_wide_t         (floo_picobello_noc_pkg::floo_wide_t),
    .sram_cfg_t          (snitch_cluster_pkg::sram_cfg_t)
  ) i_chimney (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .route_table_i       ('0),
    .sram_cfg_i          ('0),
    .axi_narrow_in_req_i (chimney_narrow_in_req),
    .axi_narrow_in_rsp_o (chimney_narrow_in_rsp),
    .axi_narrow_out_req_o(),
    .axi_narrow_out_rsp_i('0),
    .axi_wide_in_req_i   (chimney_wide_in_req),
    .axi_wide_in_rsp_o   (chimney_wide_in_rsp),
    .axi_wide_out_req_o  (),
    .axi_wide_out_rsp_i  ('0),
    .floo_req_o          (router_floo_req_in[Eject]),
    .floo_rsp_o          (router_floo_rsp_in[Eject]),
    .floo_wide_o         (router_floo_wide_in[Eject]),
    .floo_req_i          (router_floo_req_out[Eject]),
    .floo_rsp_i          (router_floo_rsp_out[Eject]),
    .floo_wide_i         (router_floo_wide_out[Eject])
  );

  ///////////////////////
  // Traffic Generator //
  ///////////////////////

  floo_picobello_noc_pkg::axi_narrow_out_req_t     traffic_gen_narrow_out_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t     traffic_gen_narrow_out_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t       traffic_gen_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t       traffic_gen_wide_out_rsp;

  axi_hls_tg_wrapper #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
    .AXI_LOCK (1),
    .AXI_LITE_ADDR_WIDTH (AxiLiteAddrWidth),
    .AXI_LITE_DATA_WIDTH (AxiLiteDataWidth)
  ) i_axi_hls_tg_wrapper (
    .clk_i,
    .rst_ni,
    .traffic_gen_narrow_out_req,
    .traffic_gen_narrow_out_rsp,
    .traffic_gen_wide_out_req,
    .traffic_gen_wide_out_rsp,
    .traffic_gen_progr
  );

  `AXI_ASSIGN_REQ_STRUCT(chimney_narrow_in_req, traffic_gen_narrow_out_req);
  `AXI_ASSIGN_RESP_STRUCT(traffic_gen_narrow_out_rsp, chimney_narrow_in_rsp);
  `AXI_ASSIGN_REQ_STRUCT(chimney_wide_in_req, traffic_gen_wide_out_req);
  `AXI_ASSIGN_RESP_STRUCT(traffic_gen_wide_out_rsp, chimney_wide_in_rsp);

endmodule
