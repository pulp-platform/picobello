// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "axi/typedef.svh"
`include "obi/typedef.svh"

module mem_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
  import obi_pkg::*;
#(
  // The maximum data width of the instantiated SRAMs
  parameter int unsigned SramDataWidth  = 256,   // in bits
  // The number of words in the instantiated SRAMs
  parameter int unsigned SramNumWords   = 512,   // in #words
  parameter bit          AxiUserAtop    = 1'b1,
  parameter int unsigned AxiUserAtopMsb = 3,
  parameter int unsigned AxiUserAtopLsb = 0
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

  ////////////
  // Router //
  ////////////

  floo_req_t [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN     (AxiCfgN),
    .AxiCfgW     (AxiCfgW),
    .EnMultiCast (ENABLE_MULTICAST),
    .RouteAlgo   (RouteCfg.RouteAlgo),
    .NumRoutes   (5),
    .InFifoDepth (2),
    .OutFifoDepth(2),
    .id_t        (id_t),
    .hdr_t       (hdr_t),
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

  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_narrow_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_narrow_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t   axi_wide_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t   axi_wide_rsp;

  floo_nw_chimney #(
    .AxiCfgN             (AxiCfgN),
    .AxiCfgW             (AxiCfgW),
    .ChimneyCfgN         (set_ports(ChimneyDefaultCfg, 1'b1, 1'b0)),
    .ChimneyCfgW         (set_ports(ChimneyDefaultCfg, 1'b1, 1'b0)),
    .RouteCfg            (RouteCfg),
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
    .floo_wide_t         (floo_wide_t)
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

  /////////////
  // NW Join //
  /////////////

  localparam axi_cfg_t AxiCfgJoin = floo_pkg::axi_join_cfg(AxiCfgN, AxiCfgW);

  typedef logic [AxiCfgJoin.OutIdWidth-1:0] nw_join_id_t;
  typedef logic [AxiCfgJoin.UserWidth-1:0] nw_join_user_t;

  `AXI_TYPEDEF_ALL_CT(axi_nw_join, axi_nw_join_req_t, axi_nw_join_rsp_t, axi_wide_out_addr_t,
                      nw_join_id_t, axi_wide_out_data_t, axi_wide_out_strb_t, nw_join_user_t)

  axi_nw_join_req_t axi_req;
  axi_nw_join_rsp_t axi_rsp;

  floo_nw_join #(
    .AxiCfgN         (axi_cfg_swap_iw(AxiCfgN)),
    .AxiCfgW         (axi_cfg_swap_iw(AxiCfgW)),
    .AxiCfgJoin      (axi_cfg_swap_iw(AxiCfgJoin)),
    .EnAtopAdapter   (1'b0),
    .AtopUserAsId    (1'b1),
    .axi_narrow_req_t(axi_narrow_out_req_t),
    .axi_narrow_rsp_t(axi_narrow_out_rsp_t),
    .axi_wide_req_t  (axi_wide_out_req_t),
    .axi_wide_rsp_t  (axi_wide_out_rsp_t),
    .axi_req_t       (axi_nw_join_req_t),
    .axi_rsp_t       (axi_nw_join_rsp_t)
  ) i_floo_nw_join (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .test_enable_i   (test_enable_i),
    .axi_narrow_req_i(axi_narrow_req),
    .axi_narrow_rsp_o(axi_narrow_rsp),
    .axi_wide_req_i  (axi_wide_req),
    .axi_wide_rsp_o  (axi_wide_rsp),
    .axi_req_o       (axi_req),
    .axi_rsp_i       (axi_rsp)
  );

  ///////////////////////
  // axi2obi converter //
  ///////////////////////

  // typedef obi for atomic config
  localparam obi_pkg::obi_optional_cfg_t MgrObiOptionalCfg = '{
      UseAtop: 1'b1,
      UseMemtype: 1'b0,
      UseProt: 1'b0,
      UseDbg: 1'b0,
      AUserWidth: 0,
      WUserWidth: 0,
      RUserWidth: 0,
      MidWidth: 0,
      AChkWidth: 0,
      RChkWidth: 0
  };
  localparam obi_pkg::obi_cfg_t MgrObiCfg = obi_pkg::obi_default_cfg(
      AxiCfgJoin.AddrWidth,
      AxiCfgJoin.DataWidth,
      (AxiUserAtop ? AxiUserAtopMsb + 1 - AxiUserAtopLsb : AxiCfgJoin.OutIdWidth),
      MgrObiOptionalCfg
  );
  `OBI_TYPEDEF_ATOP_A_OPTIONAL(mgr_obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(mgr_obi_a_chan_t, MgrObiCfg.AddrWidth, MgrObiCfg.DataWidth,
                        MgrObiCfg.IdWidth, mgr_obi_a_optional_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(mgr_obi_req_t, mgr_obi_a_chan_t)
  typedef struct packed {logic exokay;} mgr_obi_r_optional_t;
  `OBI_TYPEDEF_R_CHAN_T(mgr_obi_r_chan_t, MgrObiCfg.DataWidth, MgrObiCfg.IdWidth,
                        mgr_obi_r_optional_t)
  `OBI_TYPEDEF_RSP_T(mgr_obi_rsp_t, mgr_obi_r_chan_t)


  // typedef obi for default config
  localparam obi_pkg::obi_optional_cfg_t SbrObiOptionalCfg = '{
      UseAtop: 1'b0,
      UseMemtype: 1'b0,
      UseProt: 1'b0,
      UseDbg: 1'b0,
      AUserWidth: 0,
      WUserWidth: 0,
      RUserWidth: 0,
      MidWidth: 0,
      AChkWidth: 0,
      RChkWidth: 0
  };
  localparam obi_pkg::obi_cfg_t SbrObiCfg = obi_pkg::obi_default_cfg(
      AxiCfgJoin.AddrWidth,
      AxiCfgJoin.DataWidth,
      (AxiUserAtop ? AxiUserAtopMsb + 1 - AxiUserAtopLsb : AxiCfgJoin.OutIdWidth),
      SbrObiOptionalCfg
  );
  `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(sbr_obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(sbr_obi_a_chan_t, SbrObiCfg.AddrWidth, SbrObiCfg.DataWidth,
                        SbrObiCfg.IdWidth, sbr_obi_a_optional_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(sbr_obi_req_t, sbr_obi_a_chan_t)
  `OBI_TYPEDEF_MINIMAL_R_OPTIONAL(sbr_obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(sbr_obi_r_chan_t, SbrObiCfg.DataWidth, SbrObiCfg.IdWidth,
                        sbr_obi_r_optional_t)
  `OBI_TYPEDEF_RSP_T(sbr_obi_rsp_t, sbr_obi_r_chan_t)


  logic [AxiCfgJoin.OutIdWidth-1:0] axi_in_aw_id, axi_in_ar_id;
  logic [AxiCfgJoin.UserWidth-1:0] axi_in_aw_user, axi_in_w_user, axi_in_ar_user;
  logic [MgrObiCfg.IdWidth-1:0] obi_in_write_aid, obi_in_read_aid;

  logic [AxiCfgJoin.UserWidth-1:0] axi_in_rsp_aw_user, axi_in_rsp_w_user, axi_in_rsp_ar_user;
  logic [AxiCfgJoin.UserWidth-1:0] axi_in_r_user, axi_in_b_user;
  logic axi_in_rsp_write_bank_strobe, axi_in_rsp_read_size_enable;

  logic [MgrObiCfg.IdWidth-1:0] obi_in_rsp_write_rid, obi_in_rsp_read_rid;

  mgr_obi_req_t obi_req;
  mgr_obi_rsp_t obi_rsp;
  sbr_obi_req_t mem_obi_req;
  sbr_obi_rsp_t mem_obi_rsp;

  if (AxiUserAtop) begin : gen_user_atop
    assign obi_in_write_aid = axi_in_aw_user[AxiUserAtopMsb-1:AxiUserAtopLsb];
    assign obi_in_read_aid  = axi_in_ar_user[AxiUserAtopMsb-1:AxiUserAtopLsb];
  end else begin : gen_plain_atop
    assign obi_in_write_aid = axi_in_aw_id;
    assign obi_in_read_aid  = axi_in_ar_id;
  end

  always_comb begin : proc_obi_user
    axi_in_r_user = '0;
    axi_in_b_user = '0;
    // Respond with same ATOP ID
    if (AxiUserAtop) begin
      axi_in_r_user[AxiUserAtopMsb-1:AxiUserAtopLsb] |= axi_in_rsp_read_size_enable ?
                                                        obi_in_rsp_read_rid : '0;
      // No need to buffer the ATOP ID
      axi_in_b_user[AxiUserAtopMsb-1:AxiUserAtopLsb] |= axi_in_rsp_write_bank_strobe ?
                                                        obi_in_rsp_write_rid : '0;
    end
  end

  axi_to_obi #(
    .ObiCfg      (MgrObiCfg),
    .obi_req_t   (mgr_obi_req_t),
    .obi_rsp_t   (mgr_obi_rsp_t),
    .obi_a_chan_t(mgr_obi_a_chan_t),
    .obi_r_chan_t(mgr_obi_r_chan_t),
    .AxiAddrWidth(AxiCfgJoin.AddrWidth),
    .AxiDataWidth(AxiCfgJoin.DataWidth),
    .AxiIdWidth  (AxiCfgJoin.OutIdWidth),
    .AxiUserWidth(AxiCfgJoin.UserWidth),
    .MaxTrans    (2),
    .axi_req_t   (axi_nw_join_req_t),
    .axi_rsp_t   (axi_nw_join_rsp_t)
  ) i_axi_to_obi (
    .clk_i,
    .rst_ni,
    .testmode_i(test_enable_i),
    .axi_req_i (axi_req),
    .axi_rsp_o (axi_rsp),
    .obi_req_o (obi_req),
    .obi_rsp_i (obi_rsp),

    .req_aw_id_o      (axi_in_aw_id),
    .req_aw_user_o    (axi_in_aw_user),
    .req_w_user_o     (axi_in_w_user),
    .req_write_aid_i  (obi_in_write_aid),
    .req_write_auser_i('0),
    .req_write_wuser_i('0),

    .req_ar_id_o     (axi_in_ar_id),
    .req_ar_user_o   (axi_in_ar_user),
    .req_read_aid_i  (obi_in_read_aid),
    .req_read_auser_i('0),

    .rsp_write_aw_user_o  (axi_in_rsp_aw_user),
    .rsp_write_w_user_o   (axi_in_rsp_w_user),
    .rsp_write_bank_strb_o(axi_in_rsp_write_bank_strobe),
    .rsp_write_rid_o      (obi_in_rsp_write_rid),
    .rsp_write_ruser_o    (  /* Unused */),
    .rsp_write_last_o     (  /* Unused */),
    .rsp_write_hs_o       (  /* Unused */),
    .rsp_b_user_i         (axi_in_b_user),

    .rsp_read_ar_user_o    (  /* Unused */),
    .rsp_read_size_enable_o(axi_in_rsp_read_size_enable),
    .rsp_read_rid_o        (obi_in_rsp_read_rid),
    .rsp_read_ruser_o      (  /* Unused */),
    .rsp_r_user_i          (axi_in_r_user)
  );

  /////////////////
  // SRAM macros //
  /////////////////

  logic                            mem_req;
  logic                            mem_we;
  logic [AxiCfgJoin.AddrWidth-1:0] mem_addr;
  logic [   AxiCfgW.DataWidth-1:0] mem_wdata;
  logic [ AxiCfgW.DataWidth/8-1:0] mem_be;
  logic [   AxiCfgW.DataWidth-1:0] mem_rdata;

  obi_atop_resolver #(
    .SbrPortObiCfg            (MgrObiCfg),
    .MgrPortObiCfg            (SbrObiCfg),
    .sbr_port_obi_req_t       (mgr_obi_req_t),
    .sbr_port_obi_rsp_t       (mgr_obi_rsp_t),
    .mgr_port_obi_req_t       (sbr_obi_req_t),
    .mgr_port_obi_rsp_t       (sbr_obi_rsp_t),
    .mgr_port_obi_a_optional_t(mgr_obi_a_optional_t),
    .mgr_port_obi_r_optional_t(mgr_obi_r_optional_t),
    .LrScEnable               (1'b1),
    .RegisterAmo              (1'b0),
    .RiscvWordWidth           (32)
  ) i_obi_atop_resolver (
    .clk_i,
    .rst_ni,
    .testmode_i    (test_enable_i),
    .sbr_port_req_i(obi_req),
    .sbr_port_rsp_o(obi_rsp),
    .mgr_port_req_o(mem_obi_req),
    .mgr_port_rsp_i(mem_obi_rsp)
  );

  obi_sram_shim #(
    .ObiCfg   (SbrObiCfg),
    .obi_req_t(sbr_obi_req_t),
    .obi_rsp_t(sbr_obi_rsp_t)
  ) i_sram_shim_bank (
    .clk_i,
    .rst_ni,
    .obi_req_i(mem_obi_req),
    .obi_rsp_o(mem_obi_rsp),
    .req_o    (mem_req),
    .we_o     (mem_we),
    .addr_o   (mem_addr),
    .wdata_o  (mem_wdata),
    .be_o     (mem_be),
    .gnt_i    (1'b1),
    .rdata_i  (mem_rdata)
  );

  logic [NumBanksPerWord-1:0][SramMacroSelWidth-1:0] sram_macro_sel, sram_macro_sel_q;
  logic [NumBanksPerWord-1:0][  SramAddrWidth-1:0]                    sram_addr;
  logic [    NumBankRows-1:0][NumBanksPerWord-1:0][SramDataWidth-1:0] sram_rdata_split;

  logic [NumBanksPerWord-1:0][  SramDataWidth-1:0]                    sram_wdata;
  logic [NumBanksPerWord-1:0][SramDataWidth/8-1:0]                    sram_be;

  for (genvar i = 0; i < NumBanksPerWord; i++) begin : gen_addresses
    // Calculate the addresses
    assign sram_addr[i]      = mem_addr[SramAddrWidthOffset+:SramAddrWidth];
    assign sram_macro_sel[i] = mem_addr[SramMacroSelOffset+:SramMacroSelWidth];
    // Register the macro selection to select the correct macro for the next cycle
    `FFL(sram_macro_sel_q[i], sram_macro_sel[i], mem_req & ~mem_we, '0);
    // Assign the data
    assign sram_wdata[i]                             = mem_wdata[i*SramDataWidth+:SramDataWidth];
    assign sram_be[i]                                = mem_be[i*SramDataWidth/8+:SramDataWidth/8];
    assign mem_rdata[i*SramDataWidth+:SramDataWidth] = sram_rdata_split[sram_macro_sel_q[i]][i];
  end

  for (genvar i = 0; i < NumBanksPerWord; i++) begin : gen_sram_banks
    for (genvar j = 0; j < NumBankRows; j++) begin : gen_sram_macros
      tc_sram #(
        .NumWords (SramNumWords),
        .DataWidth(SramDataWidth),
        .NumPorts (1),
        .Latency  (1)
      ) i_mem (
        .clk_i,
        .rst_ni,
        .req_i  (mem_req && (sram_macro_sel[i] == j)),
        .we_i   (mem_we && (sram_macro_sel[i] == j)),
        .addr_i (sram_addr[i]),
        .wdata_i(sram_wdata[i]),
        .be_i   (sram_be[i]),
        .rdata_o(sram_rdata_split[j][i])
      );
    end
  end

endmodule
