// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Lorenzo Leone <lleone@iis.ee.ethz.ch>

`include "axi/assign.svh"
`include "common_cells/registers.svh"

module spm_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
  import obi_pkg::*;
#(
  // Axi to memory interface types
  parameter type axi_aw_chan_t    = floo_picobello_noc_pkg::axi_narrow_out_aw_chan_t,
  parameter type axi_w_chan_t     = floo_picobello_noc_pkg::axi_narrow_out_w_chan_t,
  parameter type axi_b_chan_t     = floo_picobello_noc_pkg::axi_narrow_out_b_chan_t,
  parameter type axi_ar_chan_t    = floo_picobello_noc_pkg::axi_narrow_out_ar_chan_t,
  parameter type axi_r_chan_t     = floo_picobello_noc_pkg::axi_narrow_out_r_chan_t,
  parameter type axi_to_mem_req_t = floo_picobello_noc_pkg::axi_narrow_out_req_t,
  parameter type axi_to_mem_rsp_t = floo_picobello_noc_pkg::axi_narrow_out_rsp_t,

  /* Axi interface parameters */
  /// AXI ID width
  parameter int unsigned AxiIdWidth   = AxiCfgN.InIdWidth,
  /// AXI Data Width
  parameter int unsigned AxiDataWidth = AxiCfgN.DataWidth,

  /* Memory interface parameters */
  /// SPM tile size
  parameter int unsigned SpmTileSize        = 2 ^ 18,        // 256 kiB
  /// Number of words per bank in the SPM
  parameter int unsigned SpmWordsPerBank    = 1024,
  /// Data width of the SPM
  parameter int unsigned SpmDataWidth       = AxiDataWidth,
  /// Number of banks per word in the SPM
  parameter int unsigned SpmNumBanksPerWord = 1,
  /// Number of banks in the SPM
  parameter int unsigned SpmNumBankRows     = 1,

  /// DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  /// The number of LSBs to address the bytes in an SRAM word
  parameter int unsigned SpmByteOffsetWidth = $clog2(SpmDataWidth / 8),
  /// The number of bits required to select the subbank for a  word
  parameter int unsigned SpmBankSelWidth = (SpmNumBanksPerWord > 1) ? $clog2(
      SpmNumBanksPerWord
  ) : 32'd0,
  /// The number of bits for the Spm address
  parameter int unsigned SpmAddrWidth = $clog2(SpmWordsPerBank),
  /// The number of bits to index the Spm macro
  parameter int unsigned SpmRowSelWidth = (SpmNumBankRows > 1) ? $clog2(SpmNumBankRows) : 32'd0,

  /// Various offsets for the Spm address
  parameter int unsigned SpmBankSelOffset   = SpmByteOffsetWidth,
  parameter int unsigned SpmAddrWidthOffset = SpmBankSelOffset + SpmBankSelWidth,
  parameter int unsigned SpmRowSelOffset    = SpmAddrWidthOffset + SpmAddrWidth,

  /// Instantiate narrow or wide SPM tile
  parameter bit IsNarrow = 1'b1  // Narrow tile

) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    test_enable_i,
  // Chimney ports
  input  id_t                     id_i,
  // Router ports
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
    .EnMultiCast (1'b0),
    .EnParallelReduction      (1'b0),
    .EnOffloadWideReduction   (1'b0),
    .EnOffloadNarrowReduction (1'b0)
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

  /////////////
  // Chimney //
  /////////////

  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_narrow_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_narrow_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t   axi_wide_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t   axi_wide_rsp;

  axi_to_mem_req_t axi_from_chimney_req, axi_req, axi_req_cut;
  axi_to_mem_rsp_t axi_to_chimney_rsp, axi_rsp, axi_rsp_cut;

  floo_nw_chimney #(
    .AxiCfgN             (AxiCfgN),
    .AxiCfgW             (AxiCfgW),
    .ChimneyCfgN         (set_ports(ChimneyDefaultCfg, bit'(IsNarrow), 1'b0)),
    .ChimneyCfgW         (set_ports(ChimneyDefaultCfg, bit'(!IsNarrow), 1'b0)),
    .RouteCfg            (RouteCfgNoMcast),
    .AtopSupport         (1'b1),
    .MaxAtomicTxns       (1),
    .Sam                 (Sam),
    .id_t                (id_t),
    .rob_idx_t           (rob_idx_t),
    .hdr_t               (hdr_t),
    .sam_rule_t          (sam_rule_t),
    .axi_narrow_in_req_t (axi_narrow_in_req_t),
    .axi_narrow_in_rsp_t (axi_narrow_in_rsp_t),
    .axi_narrow_out_req_t(axi_narrow_out_req_t),
    .axi_narrow_out_rsp_t(axi_narrow_out_rsp_t),
    .axi_wide_in_req_t   (axi_wide_in_req_t),
    .axi_wide_in_rsp_t   (axi_wide_in_rsp_t),
    .axi_wide_out_req_t  (axi_wide_out_req_t),
    .axi_wide_out_rsp_t  (axi_wide_out_rsp_t),
    .floo_req_t          (floo_req_t),
    .floo_rsp_t          (floo_rsp_t),
    .floo_wide_t         (floo_wide_t),
    .user_narrow_struct_t             (collective_narrow_user_t),
    .user_wide_struct_t               (collective_wide_user_t)
  ) i_chimney (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .route_table_i       ('0),
    .sram_cfg_i          ('0),
    .axi_narrow_in_req_i ('0),
    .axi_narrow_in_rsp_o (),
    .axi_narrow_out_req_o(axi_narrow_req),
    .axi_narrow_out_rsp_i(axi_narrow_rsp),
    .axi_wide_in_req_i   ('0),
    .axi_wide_in_rsp_o   (),
    .axi_wide_out_req_o  (axi_wide_req),
    .axi_wide_out_rsp_i  (axi_wide_rsp),
    .floo_req_o          (router_floo_req_in[Eject]),
    .floo_rsp_o          (router_floo_rsp_in[Eject]),
    .floo_wide_o         (router_floo_wide_in[Eject]),
    .floo_req_i          (router_floo_req_out[Eject]),
    .floo_rsp_i          (router_floo_rsp_out[Eject]),
    .floo_wide_i         (router_floo_wide_out[Eject])
  );

  if (IsNarrow) begin : gen_narrow_spm
    // Connect the Narrow chimney ports downstream and tie off the Wide chimney ports
    assign axi_from_chimney_req = axi_narrow_req;
    assign axi_narrow_rsp       = axi_to_chimney_rsp;
    assign axi_wide_rsp         = '0;
  end else begin : gen_wide_spm
    // Connect the Wide chimney ports downstream and tie off the Narrow chimney ports
    assign axi_from_chimney_req = axi_wide_req;
    assign axi_wide_rsp         = axi_to_chimney_rsp;
    assign axi_narrow_rsp       = '0;
  end

  /////////////////
  // ATOP Filter //
  /////////////////

  axi_atop_filter #(
    .AxiIdWidth     (AxiIdWidth),
    .AxiMaxWriteTxns(1),                 // TODO(lleone): Check if need more ofr downstream cut
    .axi_req_t      (axi_to_mem_req_t),
    .axi_resp_t     (axi_to_mem_rsp_t)
  ) i_axi_atop_filter (
    .clk_i,
    .rst_ni,
    .slv_req_i (axi_from_chimney_req),
    .slv_resp_o(axi_to_chimney_rsp),
    .mst_req_o (axi_req),
    .mst_resp_i(axi_rsp)
  );

  axi_cut #(
    .aw_chan_t (axi_aw_chan_t),
    .w_chan_t  (axi_w_chan_t),
    .b_chan_t  (axi_b_chan_t),
    .ar_chan_t (axi_ar_chan_t),
    .r_chan_t  (axi_r_chan_t),
    .axi_req_t (axi_to_mem_req_t),
    .axi_resp_t(axi_to_mem_rsp_t)
  ) i_axi_cut (
    .clk_i,
    .rst_ni,
    .slv_req_i (axi_req),
    .slv_resp_o(axi_rsp),
    .mst_req_o (axi_req_cut),
    .mst_resp_i(axi_rsp_cut)
  );

  ////////////////
  // AXI to Mem //
  ////////////////

  typedef logic [$clog2(SpmTileSize)-1:0] mem_addr_t;
  typedef logic [SpmDataWidth-1:0] mem_data_t;
  typedef logic [SpmDataWidth/8-1:0] mem_strb_t;

  logic [SpmNumBanksPerWord-1:0] mem_req_d, mem_req_q;
  logic      [SpmNumBanksPerWord-1:0] mem_we;
  mem_addr_t [SpmNumBanksPerWord-1:0] mem_addr;
  mem_data_t [SpmNumBanksPerWord-1:0] mem_wdata, mem_rdata;
  mem_strb_t [SpmNumBanksPerWord-1:0] mem_strb;

  axi_to_mem #(
    .axi_req_t   (axi_to_mem_req_t),
    .axi_resp_t  (axi_to_mem_rsp_t),
    .AddrWidth   ($clog2(SpmTileSize)),
    .DataWidth   (AxiDataWidth),
    .IdWidth     (AxiIdWidth),
    .NumBanks    (SpmNumBanksPerWord),
    .BufDepth    (1),
    .HideStrb    (1'b0),
    .OutFifoDepth(1)
  ) i_axi_to_mem (
    .clk_i,
    .rst_ni,
    .busy_o      (),
    .axi_req_i   (axi_req_cut),
    .axi_resp_o  (axi_rsp_cut),
    .mem_req_o   (mem_req_d),
    .mem_gnt_i   ('1),
    .mem_addr_o  (mem_addr),
    .mem_wdata_o (mem_wdata),
    .mem_strb_o  (mem_strb),
    .mem_atop_o  (),
    .mem_we_o    (mem_we),
    .mem_rvalid_i(mem_req_q),
    .mem_rdata_i (mem_rdata)
  );

  `FF(mem_req_q, mem_req_d, '0)

  ///////////////
  // SPM SRAM //
  ///////////////
  typedef logic [SpmNumBanksPerWord-1:0][(SpmRowSelWidth > 0) ? SpmRowSelWidth-1 : 0:0] row_sel_t;

  logic      [SpmNumBanksPerWord-1:0]                         spm_req;
  logic      [SpmNumBanksPerWord-1:0]                         spm_we;
  mem_data_t [SpmNumBanksPerWord-1:0]                         spm_wdata;
  mem_strb_t [SpmNumBanksPerWord-1:0]                         spm_strb;
  mem_data_t [    SpmNumBankRows-1:0][SpmNumBanksPerWord-1:0] spm_rdata;
  logic      [SpmNumBanksPerWord-1:0][      SpmAddrWidth-1:0] spm_addr;

  row_sel_t spm_bank_row_sel_q, spm_bank_row_sel_d;

  for (genvar b = 0; b < SpmNumBanksPerWord; b++) begin : gen_spm_addressing
    // Select the SPM address bits
    assign spm_addr[b] = mem_addr[b][SpmAddrWidthOffset+:SpmAddrWidth];

    // Select the correct spm req rows
    if (SpmRowSelWidth > 0) begin : gen_spm_row_sel
      assign spm_bank_row_sel_d[b] = mem_addr[b][SpmRowSelOffset+:SpmRowSelWidth];
    end else begin : gen_no_spm_row_sel
      assign spm_bank_row_sel_d[b] = '0;  // No row selection, always select row 0
    end

    // Select the correct SPM bank row for read data
    assign mem_rdata[b] = spm_rdata[spm_bank_row_sel_q[b]][b];

    // 1-to-1 mapping for SPm signals coming from axi_to_mem
    assign spm_wdata[b] = mem_wdata[b];
    assign spm_strb[b]  = mem_strb[b];
    assign spm_we[b]    = mem_we[b];
    assign spm_req[b]   = mem_req_d[b];
  end
  `FF(spm_bank_row_sel_q, spm_bank_row_sel_d, '0)

  for (genvar c = 0; c < SpmNumBanksPerWord; c++) begin : gen_spm_bank_col
    for (genvar r = 0; r < SpmNumBankRows; r++) begin : gen_spm_bank_row
      tc_sram #(
        .NumWords (SpmWordsPerBank),
        .DataWidth(SpmDataWidth),
        .NumPorts (1),
        .Latency  (1)
      ) i_spm (
        .clk_i,
        .rst_ni,
        .req_i  (spm_req[c] && (spm_bank_row_sel_d[c] == r)),
        .we_i   (spm_we[c]),
        .addr_i (spm_addr[c]),
        .wdata_i(spm_wdata[c]),
        .be_i   (spm_strb[c]),
        .rdata_o(spm_rdata[r][c])
      );
    end
  end

endmodule
