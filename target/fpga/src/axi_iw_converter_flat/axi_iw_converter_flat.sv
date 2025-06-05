// Copyright (c) 2014-2020 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Andreas Kurth <akurth@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>

`include "axi/typedef.svh"

/// Flat ports variant of [`axi_iw_converter`](module.axi_iw_converter).
///
/// See the documentation of the main module for the definition of ports and parameters.
module axi_iw_converter_flat #(
  parameter int unsigned AXI_SLV_PORT_ID_WIDTH = 32'd0,
  parameter int unsigned AXI_MST_PORT_ID_WIDTH = 32'd0,
  parameter int unsigned AXI_SLV_PORT_MAX_UNIQ_IDS = 32'd0,
  parameter int unsigned AXI_SLV_PORT_MAX_TXNS_PER_ID = 32'd0,
  parameter int unsigned AXI_SLV_PORT_MAX_TXNS = 32'd0,
  parameter int unsigned AXI_MST_PORT_MAX_UNIQ_IDS = 32'd0,
  parameter int unsigned AXI_MST_PORT_MAX_TXNS_PER_ID = 32'd0,
  parameter int unsigned AXI_ADDR_WIDTH = 32'd0,
  parameter int unsigned AXI_DATA_WIDTH = 32'd0,
  parameter int unsigned AXI_USER_WIDTH = 32'd0,
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type addr_t = logic [AXI_ADDR_WIDTH-1:0],
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type data_t = logic [AXI_DATA_WIDTH-1:0],
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type slv_port_id_t = logic [AXI_SLV_PORT_ID_WIDTH-1:0],
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type mst_port_id_t = logic [AXI_MST_PORT_ID_WIDTH-1:0],
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type strb_t = logic [AXI_DATA_WIDTH/8-1:0],
  /// Dependent parameter, DO NOT OVERRIDE!
  parameter type user_t = logic [AXI_USER_WIDTH-1:0]
) (
  input  logic              clk_i,
  input  logic              rst_ni,

  input  slv_port_id_t      slv_aw_id_i,
  input  addr_t             slv_aw_addr_i,
  input  axi_pkg::len_t     slv_aw_len_i,
  input  axi_pkg::size_t    slv_aw_size_i,
  input  axi_pkg::burst_t   slv_aw_burst_i,
  input  logic              slv_aw_lock_i,
  input  axi_pkg::cache_t   slv_aw_cache_i,
  input  axi_pkg::prot_t    slv_aw_prot_i,
  input  axi_pkg::qos_t     slv_aw_qos_i,
  input  axi_pkg::region_t  slv_aw_region_i,
  input  axi_pkg::atop_t    slv_aw_atop_i,
  input  user_t             slv_aw_user_i,
  input  logic              slv_aw_valid_i,
  output logic              slv_aw_ready_o,
  input  data_t             slv_w_data_i,
  input  strb_t             slv_w_strb_i,
  input  logic              slv_w_last_i,
  input  user_t             slv_w_user_i,
  input  logic              slv_w_valid_i,
  output logic              slv_w_ready_o,
  output slv_port_id_t      slv_b_id_o,
  output axi_pkg::resp_t    slv_b_resp_o,
  output user_t             slv_b_user_o,
  output logic              slv_b_valid_o,
  input  logic              slv_b_ready_i,
  input  slv_port_id_t      slv_ar_id_i,
  input  addr_t             slv_ar_addr_i,
  input  axi_pkg::len_t     slv_ar_len_i,
  input  axi_pkg::size_t    slv_ar_size_i,
  input  axi_pkg::burst_t   slv_ar_burst_i,
  input  logic              slv_ar_lock_i,
  input  axi_pkg::cache_t   slv_ar_cache_i,
  input  axi_pkg::prot_t    slv_ar_prot_i,
  input  axi_pkg::qos_t     slv_ar_qos_i,
  input  axi_pkg::region_t  slv_ar_region_i,
  input  user_t             slv_ar_user_i,
  input  logic              slv_ar_valid_i,
  output logic              slv_ar_ready_o,
  output slv_port_id_t      slv_r_id_o,
  output data_t             slv_r_data_o,
  output axi_pkg::resp_t    slv_r_resp_o,
  output logic              slv_r_last_o,
  output user_t             slv_r_user_o,
  output logic              slv_r_valid_o,
  input  logic              slv_r_ready_i,

  output mst_port_id_t      mst_aw_id_o,
  output addr_t             mst_aw_addr_o,
  output axi_pkg::len_t     mst_aw_len_o,
  output axi_pkg::size_t    mst_aw_size_o,
  output axi_pkg::burst_t   mst_aw_burst_o,
  output logic              mst_aw_lock_o,
  output axi_pkg::cache_t   mst_aw_cache_o,
  output axi_pkg::prot_t    mst_aw_prot_o,
  output axi_pkg::qos_t     mst_aw_qos_o,
  output axi_pkg::region_t  mst_aw_region_o,
  output axi_pkg::atop_t    mst_aw_atop_o,
  output user_t             mst_aw_user_o,
  output logic              mst_aw_valid_o,
  input  logic              mst_aw_ready_i,
  output data_t             mst_w_data_o,
  output strb_t             mst_w_strb_o,
  output logic              mst_w_last_o,
  output user_t             mst_w_user_o,
  output logic              mst_w_valid_o,
  input  logic              mst_w_ready_i,
  input  mst_port_id_t      mst_b_id_i,
  input  axi_pkg::resp_t    mst_b_resp_i,
  input  user_t             mst_b_user_i,
  input  logic              mst_b_valid_i,
  output logic              mst_b_ready_o,
  output mst_port_id_t      mst_ar_id_o,
  output addr_t             mst_ar_addr_o,
  output axi_pkg::len_t     mst_ar_len_o,
  output axi_pkg::size_t    mst_ar_size_o,
  output axi_pkg::burst_t   mst_ar_burst_o,
  output logic              mst_ar_lock_o,
  output axi_pkg::cache_t   mst_ar_cache_o,
  output axi_pkg::prot_t    mst_ar_prot_o,
  output axi_pkg::qos_t     mst_ar_qos_o,
  output axi_pkg::region_t  mst_ar_region_o,
  output user_t             mst_ar_user_o,
  output logic              mst_ar_valid_o,
  input  logic              mst_ar_ready_i,
  input  mst_port_id_t      mst_r_id_i,
  input  data_t             mst_r_data_i,
  input  axi_pkg::resp_t    mst_r_resp_i,
  input  logic              mst_r_last_i,
  input  user_t             mst_r_user_i,
  input  logic              mst_r_valid_i,
  output logic              mst_r_ready_o
);

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH   (AXI_SLV_PORT_ID_WIDTH),
    .AXI_USER_WIDTH (AXI_USER_WIDTH)
  ) slv ();
  assign slv.aw_id = slv_aw_id_i;
  assign slv.aw_addr = slv_aw_addr_i;
  assign slv.aw_len = slv_aw_len_i;
  assign slv.aw_size = slv_aw_size_i;
  assign slv.aw_burst = slv_aw_burst_i;
  assign slv.aw_lock = slv_aw_lock_i;
  assign slv.aw_cache = slv_aw_cache_i;
  assign slv.aw_prot = slv_aw_prot_i;
  assign slv.aw_qos = slv_aw_qos_i;
  assign slv.aw_region = slv_aw_region_i;
  assign slv.aw_atop = slv_aw_atop_i;
  assign slv.aw_user = slv_aw_user_i;
  assign slv.aw_valid = slv_aw_valid_i;
  assign slv_aw_ready_o = slv.aw_ready;
  assign slv.w_data = slv_w_data_i;
  assign slv.w_strb = slv_w_strb_i;
  assign slv.w_last = slv_w_last_i;
  assign slv.w_user = slv_w_user_i;
  assign slv.w_valid = slv_w_valid_i;
  assign slv_w_ready_o = slv.w_ready;
  assign slv_b_id_o = slv.b_id;
  assign slv_b_resp_o = slv.b_resp;
  assign slv_b_user_o = slv.b_user;
  assign slv_b_valid_o = slv.b_valid;
  assign slv.b_ready = slv_b_ready_i;
  assign slv.ar_id = slv_ar_id_i;
  assign slv.ar_addr = slv_ar_addr_i;
  assign slv.ar_len = slv_ar_len_i;
  assign slv.ar_size = slv_ar_size_i;
  assign slv.ar_burst = slv_ar_burst_i;
  assign slv.ar_lock = slv_ar_lock_i;
  assign slv.ar_cache = slv_ar_cache_i;
  assign slv.ar_prot = slv_ar_prot_i;
  assign slv.ar_qos = slv_ar_qos_i;
  assign slv.ar_region = slv_ar_region_i;
  assign slv.ar_user = slv_ar_user_i;
  assign slv.ar_valid = slv_ar_valid_i;
  assign slv_ar_ready_o = slv.ar_ready;
  assign slv_r_id_o = slv.r_id;
  assign slv_r_data_o = slv.r_data;
  assign slv_r_resp_o = slv.r_resp;
  assign slv_r_last_o = slv.r_last;
  assign slv_r_user_o = slv.r_user;
  assign slv_r_valid_o = slv.r_valid;
  assign slv.r_ready = slv_r_ready_i;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH   (AXI_MST_PORT_ID_WIDTH),
    .AXI_USER_WIDTH (AXI_USER_WIDTH)
  ) mst ();
  assign mst_aw_id_o = mst.aw_id;
  assign mst_aw_addr_o = mst.aw_addr;
  assign mst_aw_len_o = mst.aw_len;
  assign mst_aw_size_o = mst.aw_size;
  assign mst_aw_burst_o = mst.aw_burst;
  assign mst_aw_lock_o = mst.aw_lock;
  assign mst_aw_cache_o = mst.aw_cache;
  assign mst_aw_prot_o = mst.aw_prot;
  assign mst_aw_qos_o = mst.aw_qos;
  assign mst_aw_region_o = mst.aw_region;
  assign mst_aw_atop_o = mst.aw_atop;
  assign mst_aw_user_o = mst.aw_user;
  assign mst_aw_valid_o = mst.aw_valid;
  assign mst.aw_ready = mst_aw_ready_i;
  assign mst_w_data_o = mst.w_data;
  assign mst_w_strb_o = mst.w_strb;
  assign mst_w_last_o = mst.w_last;
  assign mst_w_user_o = mst.w_user;
  assign mst_w_valid_o = mst.w_valid;
  assign mst.w_ready = mst_w_ready_i;
  assign mst.b_id = mst_b_id_i;
  assign mst.b_resp = mst_b_resp_i;
  assign mst.b_user = mst_b_user_i;
  assign mst.b_valid = mst_b_valid_i;
  assign mst_b_ready_o = mst.b_ready;
  assign mst_ar_id_o = mst.ar_id;
  assign mst_ar_addr_o = mst.ar_addr;
  assign mst_ar_len_o = mst.ar_len;
  assign mst_ar_size_o = mst.ar_size;
  assign mst_ar_burst_o = mst.ar_burst;
  assign mst_ar_lock_o = mst.ar_lock;
  assign mst_ar_cache_o = mst.ar_cache;
  assign mst_ar_prot_o = mst.ar_prot;
  assign mst_ar_qos_o = mst.ar_qos;
  assign mst_ar_region_o = mst.ar_region;
  assign mst_ar_user_o = mst.ar_user;
  assign mst_ar_valid_o = mst.ar_valid;
  assign mst.ar_ready = mst_ar_ready_i;
  assign mst.r_id = mst_r_id_i;
  assign mst.r_data = mst_r_data_i;
  assign mst.r_resp = mst_r_resp_i;
  assign mst.r_last = mst_r_last_i;
  assign mst.r_user = mst_r_user_i;
  assign mst.r_valid = mst_r_valid_i;
  assign mst_r_ready_o = mst.r_ready;

  axi_iw_converter_intf #(
    .AXI_SLV_PORT_ID_WIDTH        (AXI_SLV_PORT_ID_WIDTH),
    .AXI_MST_PORT_ID_WIDTH        (AXI_MST_PORT_ID_WIDTH),
    .AXI_SLV_PORT_MAX_UNIQ_IDS    (AXI_SLV_PORT_MAX_UNIQ_IDS),
    .AXI_SLV_PORT_MAX_TXNS_PER_ID (AXI_SLV_PORT_MAX_TXNS_PER_ID),
    .AXI_SLV_PORT_MAX_TXNS        (AXI_SLV_PORT_MAX_TXNS),
    .AXI_MST_PORT_MAX_UNIQ_IDS    (AXI_MST_PORT_MAX_UNIQ_IDS),
    .AXI_MST_PORT_MAX_TXNS_PER_ID (AXI_MST_PORT_MAX_TXNS_PER_ID),
    .AXI_ADDR_WIDTH               (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH               (AXI_DATA_WIDTH),
    .AXI_USER_WIDTH               (AXI_USER_WIDTH)
  ) i_resize (
    .clk_i,
    .rst_ni,
    .slv  (slv),
    .mst  (mst)
  );

endmodule
