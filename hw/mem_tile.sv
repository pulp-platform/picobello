// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

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

  localparam int unsigned NarrowNumWords = 4096; // 128kB
  localparam int unsigned WideNumWords = 16384; // 1MB

  typedef logic [$clog2(NarrowNumWords)-1:0] narrow_mem_addr_t;
  typedef logic [AxiCfgN.DataWidth-1:0] narrow_mem_data_t;
  typedef logic [AxiCfgN.DataWidth/8-1:0] narrow_mem_be_t;

  typedef logic [$clog2(WideNumWords)-1:0] wide_mem_addr_t;
  typedef logic [AxiCfgW.DataWidth-1:0] wide_mem_data_t;
  typedef logic [AxiCfgW.DataWidth/8-1:0] wide_mem_be_t;


  logic narrow_mem_req, narrow_mem_req_q;
  logic narrow_mem_we;
  narrow_mem_addr_t narrow_mem_addr;
  narrow_mem_data_t narrow_mem_wdata;
  narrow_mem_be_t narrow_mem_be;
  narrow_mem_data_t narrow_mem_rdata;

  logic wide_mem_req, wide_mem_req_q;
  logic wide_mem_we;
  wide_mem_addr_t wide_mem_addr;
  wide_mem_data_t wide_mem_wdata;
  wide_mem_be_t wide_mem_be;
  wide_mem_data_t wide_mem_rdata;

  tc_sram #(
    .NumWords   (NarrowNumWords), // 128kB
    .DataWidth  (AxiCfgN.DataWidth),
    .NumPorts   (1)
  ) i_narrow_mem (
    .clk_i,
    .rst_ni,
    .req_i  (narrow_mem_req),
    .we_i   (narrow_mem_we),
    .addr_i (narrow_mem_addr),
    .wdata_i(narrow_mem_wdata),
    .be_i   (narrow_mem_be),
    .rdata_o(narrow_mem_rdata)
  );

  tc_sram #(
    .NumWords   (WideNumWords), // 128kB
    .DataWidth  (AxiCfgW.DataWidth),
    .NumPorts   (1)
  ) i_wide_mem (
    .clk_i,
    .rst_ni,
    .req_i  (wide_mem_req),
    .we_i   (wide_mem_we),
    .addr_i (wide_mem_addr),
    .wdata_i(wide_mem_wdata),
    .be_i   (wide_mem_be),
    .rdata_o(wide_mem_rdata)
  );

  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_narrow_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_narrow_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t   axi_wide_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t   axi_wide_rsp;

  // TODO: filter ATOPs
  axi_to_mem #(
    .AddrWidth   ($clog2(NarrowNumWords)),
    .DataWidth   (AxiCfgN.DataWidth),
    .IdWidth     (AxiCfgN.OutIdWidth),
    .NumBanks    (1),
    .axi_req_t   (axi_narrow_out_req_t),
    .axi_resp_t  (axi_narrow_out_rsp_t)
  ) i_narrow_axi_to_mem (
    .clk_i,
    .rst_ni,
    .busy_o      (),
    .axi_req_i   (axi_narrow_req),
    .axi_resp_o  (axi_narrow_rsp),
    .mem_req_o   (narrow_mem_req),
    .mem_gnt_i   (1'b1),
    .mem_addr_o  (narrow_mem_addr),
    .mem_wdata_o (narrow_mem_wdata),
    .mem_strb_o  (narrow_mem_be),
    .mem_atop_o  (), // We need to filter ATOPs previously
    .mem_we_o    (narrow_mem_we),
    .mem_rvalid_i(narrow_mem_req_q),
    .mem_rdata_i (narrow_mem_rdata)
  );

  axi_to_mem #(
    .AddrWidth   ($clog2(WideNumWords)),
    .DataWidth   (AxiCfgW.DataWidth),
    .IdWidth     (AxiCfgW.OutIdWidth),
    .NumBanks    (1),
    .axi_req_t   (axi_wide_out_req_t),
    .axi_resp_t  (axi_wide_out_rsp_t)
  ) i_wide_axi_to_mem (
    .clk_i,
    .rst_ni,
    .busy_o      (),
    .axi_req_i   (axi_wide_req),
    .axi_resp_o  (axi_wide_rsp),
    .mem_req_o   (wide_mem_req),
    .mem_gnt_i   (1'b1),
    .mem_addr_o  (wide_mem_addr),
    .mem_wdata_o (wide_mem_wdata),
    .mem_strb_o  (wide_mem_be),
    .mem_atop_o  (), // No atops on wide
    .mem_we_o    (wide_mem_we),
    .mem_rvalid_i(wide_mem_req_q),
    .mem_rdata_i (wide_mem_rdata)
  );

  `FF(narrow_mem_req_q, narrow_mem_req, '0)
  `FF(wide_mem_req_q, wide_mem_req, '0)

  floo_req_t  [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t  [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

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

endmodule
