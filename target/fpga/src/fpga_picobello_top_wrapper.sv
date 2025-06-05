// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module fpga_picobello_top_wrapper
  import fpga_picobello_pkg::*; (
  // Clocks and Resets
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // AXI4 host slave interface
  input  fpga_picobello_pkg::axi_host_id_t      axi_host_in_aw_id_i,
  input  fpga_picobello_pkg::axi_host_addr_t    axi_host_in_aw_addr_i,
  input  axi_pkg::len_t                         axi_host_in_aw_len_i,
  input  axi_pkg::size_t                        axi_host_in_aw_size_i,
  input  axi_pkg::burst_t                       axi_host_in_aw_burst_i,
  input  logic                                  axi_host_in_aw_lock_i,
  input  axi_pkg::cache_t                       axi_host_in_aw_cache_i,
  input  axi_pkg::prot_t                        axi_host_in_aw_prot_i,
  input  axi_pkg::qos_t                         axi_host_in_aw_qos_i,
  input  axi_pkg::region_t                      axi_host_in_aw_region_i,
  input  axi_pkg::atop_t                        axi_host_in_aw_atop_i,
  input  fpga_picobello_pkg::axi_host_user_t    axi_host_in_aw_user_i,
  input  logic                                  axi_host_in_aw_valid_i,
  output logic                                  axi_host_in_aw_ready_o,
  input  fpga_picobello_pkg::axi_host_data_t    axi_host_in_w_data_i,
  input  fpga_picobello_pkg::axi_host_strb_t    axi_host_in_w_strb_i,
  input  logic                                  axi_host_in_w_last_i,
  input  fpga_picobello_pkg::axi_host_user_t    axi_host_in_w_user_i,
  input  logic                                  axi_host_in_w_valid_i,
  output logic                                  axi_host_in_w_ready_o,
  output fpga_picobello_pkg::axi_host_id_t      axi_host_in_b_id_o,
  output axi_pkg::resp_t                        axi_host_in_b_resp_o,
  output fpga_picobello_pkg::axi_host_user_t    axi_host_in_b_user_o,
  output logic                                  axi_host_in_b_valid_o,
  input  logic                                  axi_host_in_b_ready_i,
  input  fpga_picobello_pkg::axi_host_id_t      axi_host_in_ar_id_i,
  input  fpga_picobello_pkg::axi_host_addr_t    axi_host_in_ar_addr_i,
  input  axi_pkg::len_t                         axi_host_in_ar_len_i,
  input  axi_pkg::size_t                        axi_host_in_ar_size_i,
  input  axi_pkg::burst_t                       axi_host_in_ar_burst_i,
  input  logic                                  axi_host_in_ar_lock_i,
  input  axi_pkg::cache_t                       axi_host_in_ar_cache_i,
  input  axi_pkg::prot_t                        axi_host_in_ar_prot_i,
  input  axi_pkg::qos_t                         axi_host_in_ar_qos_i,
  input  axi_pkg::region_t                      axi_host_in_ar_region_i,
  input  fpga_picobello_pkg::axi_host_user_t    axi_host_in_ar_user_i,
  input  logic                                  axi_host_in_ar_valid_i,
  output logic                                  axi_host_in_ar_ready_o,
  output fpga_picobello_pkg::axi_host_id_t      axi_host_in_r_id_o,
  output fpga_picobello_pkg::axi_host_data_t    axi_host_in_r_data_o,
  output axi_pkg::resp_t                        axi_host_in_r_resp_o,
  output logic                                  axi_host_in_r_last_o,
  output fpga_picobello_pkg::axi_host_user_t    axi_host_in_r_user_o,
  output logic                                  axi_host_in_r_valid_o,
  input  logic                                  axi_host_in_r_ready_i
);
  // Host signals
  fpga_picobello_pkg::axi_host_req_t axi_host_in_req_i;
  fpga_picobello_pkg::axi_host_rsp_t axi_host_in_rsp_o;

  fpga_picobello_top #(
    // SoC parameters
    .NumFpgaHostPorts         (fpga_picobello_pkg::NumFpgaHostPorts),   
    .NumFpgaDummyTiles        (fpga_picobello_pkg::NumFpgaDummyTiles),   
    .NumTrafficGenerators     (fpga_picobello_pkg::NumTrafficGenerators),
    // Host AXI4 parameters
    .HostAxiAddrWidth         (fpga_picobello_pkg::HostAxiAddrWidth),
    .HostAxiDataWidth         (fpga_picobello_pkg::HostAxiDataWidth),
    .HostAxiUserWidth         (fpga_picobello_pkg::HostAxiUserWidth),
    .HostAxiIdWidth           (fpga_picobello_pkg::HostAxiIdWidth),
    // Host AXI4-Lite parameters
    .HostAxiLiteAddrWidth     (fpga_picobello_pkg::HostAxiLiteAddrWidth),
    .HostAxiLiteDataWidth     (fpga_picobello_pkg::HostAxiLiteDataWidth),
    // AXI4 channel types
    .axi_host_req_t           (fpga_picobello_pkg::axi_host_req_t),
    .axi_host_rsp_t           (fpga_picobello_pkg::axi_host_rsp_t),
    .axi_host_aw_chan_t       (fpga_picobello_pkg::axi_host_aw_chan_t),
    .axi_host_w_chan_t        (fpga_picobello_pkg::axi_host_w_chan_t),
    .axi_host_b_chan_t        (fpga_picobello_pkg::axi_host_b_chan_t),
    .axi_host_ar_chan_t       (fpga_picobello_pkg::axi_host_ar_chan_t),
    .axi_host_r_chan_t        (fpga_picobello_pkg::axi_host_r_chan_t),
    // AXI4-Lite channel types
    .axi_lite_host_req_t      (fpga_picobello_pkg::axi_lite_host_req_t),
    .axi_lite_host_rsp_t      (fpga_picobello_pkg::axi_lite_host_rsp_t),
    .axi_lite_host_aw_chan_t  (fpga_picobello_pkg::axi_lite_host_aw_chan_t),
    .axi_lite_host_w_chan_t   (fpga_picobello_pkg::axi_lite_host_w_chan_t),
    .axi_lite_host_b_chan_t   (fpga_picobello_pkg::axi_lite_host_b_chan_t),
    .axi_lite_host_ar_chan_t  (fpga_picobello_pkg::axi_lite_host_ar_chan_t),
    .axi_lite_host_r_chan_t   (fpga_picobello_pkg::axi_lite_host_r_chan_t)
  ) i_picobello_top (
    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni),
    .test_mode_i              (1'b0),
    .ext_axi_host_req_i       (axi_host_in_req_i),
    .ext_axi_host_rsp_o       (axi_host_in_rsp_o)
  );

  assign axi_host_in_req_i.aw.id        = axi_host_in_aw_id_i;
  assign axi_host_in_req_i.aw.addr      = axi_host_in_aw_addr_i;
  assign axi_host_in_req_i.aw.len       = axi_host_in_aw_len_i;
  assign axi_host_in_req_i.aw.size      = axi_host_in_aw_size_i;
  assign axi_host_in_req_i.aw.burst     = axi_host_in_aw_burst_i;
  assign axi_host_in_req_i.aw.lock      = axi_host_in_aw_lock_i;
  assign axi_host_in_req_i.aw.cache     = axi_host_in_aw_cache_i;
  assign axi_host_in_req_i.aw.prot      = axi_host_in_aw_prot_i;
  assign axi_host_in_req_i.aw.qos       = axi_host_in_aw_qos_i;
  assign axi_host_in_req_i.aw.region    = axi_host_in_aw_region_i;
  assign axi_host_in_req_i.aw.atop      = axi_host_in_aw_atop_i;
  assign axi_host_in_req_i.aw.user      = axi_host_in_aw_user_i;
  assign axi_host_in_req_i.aw_valid     = axi_host_in_aw_valid_i;
  assign axi_host_in_aw_ready_o         = axi_host_in_rsp_o.aw_ready;
  assign axi_host_in_req_i.w.data       = axi_host_in_w_data_i;
  assign axi_host_in_req_i.w.strb       = axi_host_in_w_strb_i;
  assign axi_host_in_req_i.w.last       = axi_host_in_w_last_i;
  assign axi_host_in_req_i.w.user       = axi_host_in_w_user_i;
  assign axi_host_in_req_i.w_valid      = axi_host_in_w_valid_i;
  assign axi_host_in_w_ready_o          = axi_host_in_rsp_o.w_ready;
  assign axi_host_in_b_id_o             = axi_host_in_rsp_o.b.id;
  assign axi_host_in_b_resp_o           = axi_host_in_rsp_o.b.resp;
  assign axi_host_in_b_user_o           = axi_host_in_rsp_o.b.user;
  assign axi_host_in_b_valid_o          = axi_host_in_rsp_o.b_valid;
  assign axi_host_in_req_i.b_ready      = axi_host_in_b_ready_i;
  assign axi_host_in_req_i.ar.id        = axi_host_in_ar_id_i;
  assign axi_host_in_req_i.ar.addr      = axi_host_in_ar_addr_i;
  assign axi_host_in_req_i.ar.len       = axi_host_in_ar_len_i;
  assign axi_host_in_req_i.ar.size      = axi_host_in_ar_size_i;
  assign axi_host_in_req_i.ar.burst     = axi_host_in_ar_burst_i;
  assign axi_host_in_req_i.ar.lock      = axi_host_in_ar_lock_i;
  assign axi_host_in_req_i.ar.cache     = axi_host_in_ar_cache_i;
  assign axi_host_in_req_i.ar.prot      = axi_host_in_ar_prot_i;
  assign axi_host_in_req_i.ar.qos       = axi_host_in_ar_qos_i;
  assign axi_host_in_req_i.ar.region    = axi_host_in_ar_region_i;
  assign axi_host_in_req_i.ar.user      = axi_host_in_ar_user_i;
  assign axi_host_in_req_i.ar_valid     = axi_host_in_ar_valid_i;
  assign axi_host_in_ar_ready_o         = axi_host_in_rsp_o.ar_ready;
  assign axi_host_in_r_id_o             = axi_host_in_rsp_o.r.id;
  assign axi_host_in_r_data_o           = axi_host_in_rsp_o.r.data;
  assign axi_host_in_r_last_o           = axi_host_in_rsp_o.r.last;
  assign axi_host_in_r_resp_o           = axi_host_in_rsp_o.r.resp;
  assign axi_host_in_r_user_o           = axi_host_in_rsp_o.r.user;
  assign axi_host_in_r_valid_o          = axi_host_in_rsp_o.r_valid;
  assign axi_host_in_req_i.r_ready      = axi_host_in_r_ready_i;

endmodule