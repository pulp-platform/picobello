// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "axi/typedef.svh"

module mem_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,
  input logic test_enable_i,
  // Chimney ports
  input  id_t id_i,
  // Router ports
  output floo_req_t [West:North]    floo_req_o,
  input  floo_rsp_t [West:North]    floo_rsp_i,
  output floo_wide_t [West:North]   floo_wide_o,
  input  floo_req_t [West:North]    floo_req_i,
  output floo_rsp_t [West:North]    floo_rsp_o,
  input  floo_wide_t [West:North]   floo_wide_i
);

  // The total memory size in bytes
  localparam int unsigned MemSize = 1024 * 1024; // 1MB
  // The maximum word size of the SRAM
  localparam int unsigned SramWordSize = 32; // in bytes
  // The maximum number of words in the SRAM
  localparam int unsigned SramNumWords = 512; // in #words
  // The number of bytes per word
  localparam int unsigned BytesPerWord = AxiCfgW.DataWidth / 8;
  // The number of banks per word
  localparam int unsigned NumBanksPerWord = BytesPerWord / SramWordSize;
  // The size of a bank row in bytes
  localparam int unsigned SizePerBankRow = NumBanksPerWord * SramWordSize * SramNumWords;
  // The number of bank rows
  localparam int unsigned NumBankRows = (MemSize / BytesPerWord) / SramNumWords;

  ////////////
  // Router //
  ////////////

  floo_req_t  [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t  [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN      ( AxiCfgN             ),
    .AxiCfgW      ( AxiCfgW             ),
    .RouteAlgo    ( RouteCfg.RouteAlgo  ),
    .NumRoutes    ( 5                   ),
    .InFifoDepth  ( 2                   ),
    .OutFifoDepth ( 2                   ),
    .id_t         ( id_t                ),
    .hdr_t        ( hdr_t               ),
    .floo_req_t   ( floo_req_t          ),
    .floo_rsp_t   ( floo_rsp_t          ),
    .floo_wide_t  ( floo_wide_t         )
  ) i_router (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .id_route_map_i ( '0                    ),
    .floo_req_i     ( router_floo_req_in    ),
    .floo_rsp_o     ( router_floo_rsp_out   ),
    .floo_req_o     ( router_floo_req_out   ),
    .floo_rsp_i     ( router_floo_rsp_in    ),
    .floo_wide_i    ( router_floo_wide_in   ),
    .floo_wide_o    ( router_floo_wide_out  )
  );

  assign floo_req_o = router_floo_req_out[West:North];
  assign router_floo_req_in[West:North] = floo_req_i;
  assign floo_rsp_o = router_floo_rsp_out[West:North];
  assign router_floo_rsp_in[West:North] = floo_rsp_i;
  assign floo_wide_o = router_floo_wide_out[West:North];
  assign router_floo_wide_in[West:North] = floo_wide_i;

  /////////////
  // Chimney //
  /////////////

  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_narrow_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_narrow_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t   axi_wide_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t   axi_wide_rsp;

  floo_nw_chimney #(
    .AxiCfgN              ( AxiCfgN                                   ),
    .AxiCfgW              ( AxiCfgW                                   ),
    .ChimneyCfgN          ( set_ports(ChimneyDefaultCfg, 1'b1, 1'b0)  ),
    .ChimneyCfgW          ( set_ports(ChimneyDefaultCfg, 1'b1, 1'b0)  ),
    .RouteCfg             ( RouteCfg                                  ),
    .AtopSupport          ( 1'b1                                      ),
    .MaxAtomicTxns        ( 1                                         ),
    .Sam                  ( Sam                                       ),
    .id_t                 ( id_t                                      ),
    .rob_idx_t            ( rob_idx_t                                 ),
    .hdr_t                ( hdr_t                                     ),
    .sam_rule_t           ( sam_rule_t                                ),
    .axi_narrow_in_req_t  ( axi_narrow_in_req_t                       ),
    .axi_narrow_in_rsp_t  ( axi_narrow_in_rsp_t                       ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t                      ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t                      ),
    .axi_wide_in_req_t    ( axi_wide_in_req_t                         ),
    .axi_wide_in_rsp_t    ( axi_wide_in_rsp_t                         ),
    .axi_wide_out_req_t   ( axi_wide_out_req_t                        ),
    .axi_wide_out_rsp_t   ( axi_wide_out_rsp_t                        ),
    .floo_req_t           ( floo_req_t                                ),
    .floo_rsp_t           ( floo_rsp_t                                ),
    .floo_wide_t          ( floo_wide_t                               )
  ) i_chimney (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .route_table_i        ( '0                          ),
    .sram_cfg_i           ( '0                          ),
    .axi_narrow_in_req_i  ( '0                          ),
    .axi_narrow_in_rsp_o  (                             ),
    .axi_narrow_out_req_o ( axi_narrow_req              ),
    .axi_narrow_out_rsp_i ( axi_narrow_rsp              ),
    .axi_wide_in_req_i    ( '0                          ),
    .axi_wide_in_rsp_o    (                             ),
    .axi_wide_out_req_o   ( axi_wide_req                ),
    .axi_wide_out_rsp_i   ( axi_wide_rsp                ),
    .floo_req_o           ( router_floo_req_in[Eject]   ),
    .floo_rsp_o           ( router_floo_rsp_in[Eject]   ),
    .floo_wide_o          ( router_floo_wide_in[Eject]  ),
    .floo_req_i           ( router_floo_req_out[Eject]  ),
    .floo_rsp_i           ( router_floo_rsp_out[Eject]  ),
    .floo_wide_i          ( router_floo_wide_out[Eject] )
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
    .AxiCfgN          ( axi_cfg_swap_iw(AxiCfgN)    ),
    .AxiCfgW          ( axi_cfg_swap_iw(AxiCfgW)    ),
    .AxiCfgJoin       ( axi_cfg_swap_iw(AxiCfgJoin) ),
    .AtopUserAsId     ( 1'b1 ),
    .axi_narrow_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_req_t   ( axi_wide_out_req_t   ),
    .axi_wide_rsp_t   ( axi_wide_out_rsp_t   ),
    .axi_req_t        ( axi_nw_join_req_t    ),
    .axi_rsp_t        ( axi_nw_join_rsp_t    )
  ) i_floo_nw_join (
    .clk_i            ( clk_i  ),
    .rst_ni           ( rst_ni ),
    .test_enable_i    ( test_enable_i  ),
    .axi_narrow_req_i ( axi_narrow_req ),
    .axi_narrow_rsp_o ( axi_narrow_rsp ),
    .axi_wide_req_i   ( axi_wide_req   ),
    .axi_wide_rsp_o   ( axi_wide_rsp   ),
    .axi_req_o        ( axi_req ),
    .axi_rsp_i        ( axi_rsp )
  );

  ///////////////////////
  // axi2mem converter //
  ///////////////////////

  typedef logic [$clog2(MemSize)-1:0] mem_addr_t;
  typedef logic [AxiCfgW.DataWidth/NumBanksPerWord-1:0] mem_data_t;
  typedef logic [AxiCfgW.DataWidth/NumBanksPerWord/8-1:0] mem_be_t;

  logic [NumBanksPerWord-1:0] mem_req, mem_req_q;
  logic [NumBanksPerWord-1:0] mem_we;
  mem_addr_t [NumBanksPerWord-1:0] mem_addr;
  mem_data_t [NumBanksPerWord-1:0] mem_wdata;
  mem_be_t [NumBanksPerWord-1:0] mem_be;
  mem_data_t [NumBanksPerWord-1:0] mem_rdata;

  axi_to_mem #(
    .AddrWidth  ( $clog2(MemSize)       ),
    .DataWidth  ( AxiCfgJoin.DataWidth  ),
    .IdWidth    ( AxiCfgJoin.OutIdWidth ),
    .NumBanks   ( NumBanksPerWord   ),
    .axi_req_t  ( axi_nw_join_req_t ),
    .axi_resp_t ( axi_nw_join_rsp_t )
  ) i_axi_to_mem (
    .clk_i,
    .rst_ni,
    .busy_o       ( ),
    .axi_req_i    ( axi_req ),
    .axi_resp_o   ( axi_rsp ),
    .mem_req_o    ( mem_req ),
    .mem_gnt_i    ( {NumBanksPerWord{1'b1}} ),
    .mem_addr_o   ( mem_addr  ),
    .mem_wdata_o  ( mem_wdata ),
    .mem_strb_o   ( mem_be    ),
    .mem_atop_o   ( ), // No atops on wide
    .mem_we_o     ( mem_we    ),
    .mem_rvalid_i ( mem_req_q ),
    .mem_rdata_i  ( mem_rdata )
  );

  `FF(mem_req_q, mem_req, '0)

  /////////////////
  // SRAM macros //
  /////////////////

  logic [NumBanksPerWord-1:0][$clog2(NumBankRows)-1:0] row_idx, row_idx_q;
  logic [NumBanksPerWord-1:0][$clog2(SramNumWords)-1:0] col_idx;
  mem_data_t [NumBankRows-1:0][NumBanksPerWord-1:0] mem_rdata_split;

  for (genvar j = 0; j < NumBanksPerWord; j++) begin : gen_sram_banks

    assign row_idx[j] = mem_addr[j][$clog2(SizePerBankRow)+:$clog2(NumBankRows)];
    assign col_idx[j] = mem_addr[j][$clog2(BytesPerWord)+:$clog2(SramNumWords)];

    assign mem_rdata[j] = mem_rdata_split[row_idx_q[j]][j];

    for (genvar i = 0; i < NumBankRows; i++) begin : gen_sram_rows

      logic mem_split_req, mem_split_we;

      assign mem_split_req = mem_req[j] && (row_idx == i);
      assign mem_split_we = mem_we[j] && (row_idx == i);

      tc_sram #(
        .NumWords  ( SramNumWords   ),
        .DataWidth ( SramWordSize*8 ),
        .NumPorts  ( 1 ),
        .Latency   ( 1 )
      ) i_mem (
        .clk_i,
        .rst_ni,
        .req_i   ( mem_split_req ),
        .we_i    ( mem_split_we  ),
        .addr_i  ( col_idx[j]    ),
        .wdata_i ( mem_wdata[j]  ),
        .be_i    ( mem_be[j]     ),
        .rdata_o ( mem_rdata_split[i][j] )
      );
    end
  end

  `FF(row_idx_q, row_idx, '0)

endmodule
