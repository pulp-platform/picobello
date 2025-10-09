// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

`include "axi/assign.svh"

module dummy_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
(
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    test_enable_i,
  input  id_t                     id_i,
  output floo_req_t  [West:North] floo_req_o,
  input  floo_rsp_t  [West:North] floo_rsp_i,
  output floo_wide_t [West:North] floo_wide_o,
  input  floo_req_t  [West:North] floo_req_i,
  output floo_rsp_t  [West:North] floo_rsp_o,
  input  floo_wide_t [West:North] floo_wide_i
);

  ////////////
  // Router //
  ////////////

  floo_req_t [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN     (AxiCfgN),
    .AxiCfgW     (AxiCfgW),
    .RouteAlgo   (RouteCfgNoMcast.RouteAlgo),
    .NumRoutes   (5),
    .InFifoDepth (2),
    .OutFifoDepth(2),
    .id_t        (id_t),
    .hdr_t       (hdr_t),
    .floo_req_t  (floo_req_t),
    .floo_rsp_t  (floo_rsp_t),
    .floo_wide_t (floo_wide_t),
    .EnDecoupledRW (1'b1)
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

  assign floo_req_o                      = router_floo_req_out[West:North];
  assign router_floo_req_in[West:North]  = floo_req_i;
  assign floo_rsp_o                      = router_floo_rsp_out[West:North];
  assign router_floo_rsp_in[West:North]  = floo_rsp_i;
  assign floo_wide_o                     = router_floo_wide_out[West:North];
  assign router_floo_wide_in[West:North] = floo_wide_i;

  // Tie the router’s Eject input ports to 0
  assign router_floo_req_in[Eject]       = '0;
  assign router_floo_rsp_in[Eject]       = '0;


endmodule : dummy_tile
