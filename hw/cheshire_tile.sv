// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "cheshire/typedef.svh"
`include "floo_noc/typedef.svh"
`include "axi/assign.svh"

module cheshire_tile
  import cheshire_pkg::*;
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_mode_i,
  input  logic [1:0] boot_mode_i,
  input  logic rtc_i,
  // Interrupt requests to external harts
  output logic [iomsb(NumIrqCtxts*CheshireCfg.NumExtIrqHarts):0] xeip_ext_o,
  output logic [iomsb(CheshireCfg.NumExtIrqHarts):0]             mtip_ext_o,
  output logic [iomsb(CheshireCfg.NumExtIrqHarts):0]             msip_ext_o,
  // JTAG
  input  logic jtag_tck_i,
  input  logic jtag_trst_ni,
  input  logic jtag_tms_i,
  input  logic jtag_tdi_i,
  output logic jtag_tdo_o,
  output logic jtag_tdo_oe_o,
    // UART interface
  output logic  uart_tx_o,
  input  logic  uart_rx_i,
  // UART modem flow control
  output logic  uart_rts_no,
  output logic  uart_dtr_no,
  input  logic  uart_cts_ni,
  input  logic  uart_dsr_ni,
  input  logic  uart_dcd_ni,
  input  logic  uart_rin_ni,
  // I2C interface
  output logic  i2c_sda_o,
  input  logic  i2c_sda_i,
  output logic  i2c_sda_en_o,
  output logic  i2c_scl_o,
  input  logic  i2c_scl_i,
  output logic  i2c_scl_en_o,
  // SPI host interface
  output logic                  spih_sck_o,
  output logic                  spih_sck_en_o,
  output logic [SpihNumCs-1:0]  spih_csb_o,
  output logic [SpihNumCs-1:0]  spih_csb_en_o,
  output logic [ 3:0]           spih_sd_o,
  output logic [ 3:0]           spih_sd_en_o,
  input  logic [ 3:0]           spih_sd_i,
  // GPIO interface
  input  logic [31:0] gpio_i,
  output logic [31:0] gpio_o,
  output logic [31:0] gpio_en_o,
  // Serial link interface
  input  logic [SlinkNumChan-1:0]                     slink_rcv_clk_i,
  output logic [SlinkNumChan-1:0]                     slink_rcv_clk_o,
  input  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0]  slink_i,
  output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0]  slink_o,
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

  ////////////
  // Router //
  ////////////

  floo_req_t  [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t  [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN      ( AxiCfgN ),
    .AxiCfgW      ( AxiCfgW ),
    .RouteAlgo    ( RouteCfg.RouteAlgo ),
    .NumRoutes    ( 5 ),
    .InFifoDepth  ( 2 ),
    .OutFifoDepth ( 2 ),
    .id_t         ( id_t        ),
    .hdr_t        ( hdr_t       ),
    .floo_req_t   ( floo_req_t  ),
    .floo_rsp_t   ( floo_rsp_t  ),
    .floo_wide_t  ( floo_wide_t )
  ) i_router (
    .clk_i,
    .rst_ni,
    .id_i,
    .test_enable_i  ( test_mode_i ),
    .id_route_map_i ( '0 ),
    .floo_req_i     ( router_floo_req_in   ),
    .floo_rsp_o     ( router_floo_rsp_out  ),
    .floo_req_o     ( router_floo_req_out  ),
    .floo_rsp_i     ( router_floo_rsp_in   ),
    .floo_wide_i    ( router_floo_wide_in  ),
    .floo_wide_o    ( router_floo_wide_out )
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

  axi_narrow_out_req_t narrow_out_req;
  axi_narrow_out_rsp_t narrow_out_rsp;
  axi_narrow_in_req_t narrow_in_req;
  axi_narrow_in_rsp_t narrow_in_rsp;
  axi_wide_out_req_t   wide_out_req;
  axi_wide_out_rsp_t   wide_out_rsp;

  localparam chimney_cfg_t ChimneyCfgN = ChimneyDefaultCfg;
  localparam chimney_cfg_t ChimneyCfgW = set_ports(ChimneyDefaultCfg, 1'b1, 1'b0);

  floo_nw_chimney #(
    .AxiCfgN              ( AxiCfgN     ),
    .AxiCfgW              ( AxiCfgW     ),
    .ChimneyCfgN          ( ChimneyCfgN ),
    .ChimneyCfgW          ( ChimneyCfgW ),
    .RouteCfg             ( RouteCfg    ),
    .AtopSupport          ( 1'b1 ),
    .MaxAtomicTxns        ( AxiCfgN.OutIdWidth-1 ),
    .Sam                  ( Sam ),
    .id_t                 ( id_t       ),
    .rob_idx_t            ( rob_idx_t  ),
    .hdr_t                ( hdr_t      ),
    .sam_rule_t           ( sam_rule_t ),
    .axi_narrow_in_req_t  ( axi_narrow_in_req_t  ),
    .axi_narrow_in_rsp_t  ( axi_narrow_in_rsp_t  ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_in_req_t    ( axi_wide_in_req_t  ),
    .axi_wide_in_rsp_t    ( axi_wide_in_rsp_t  ),
    .axi_wide_out_req_t   ( axi_wide_out_req_t ),
    .axi_wide_out_rsp_t   ( axi_wide_out_rsp_t ),
    .floo_req_t           ( floo_req_t  ),
    .floo_rsp_t           ( floo_rsp_t  ),
    .floo_wide_t          ( floo_wide_t )
  ) i_chimney (
    .clk_i,
    .rst_ni,
    .id_i,
    .test_enable_i        ( test_mode_i ),
    .sram_cfg_i           ( '0 ),
    .route_table_i        ( '0 ),
    .axi_narrow_in_req_i  ( narrow_in_req  ),
    .axi_narrow_in_rsp_o  ( narrow_in_rsp  ),
    .axi_narrow_out_req_o ( narrow_out_req ),
    .axi_narrow_out_rsp_i ( narrow_out_rsp ),
    .axi_wide_in_req_i    ( '0 ),
    .axi_wide_in_rsp_o    (    ),
    .axi_wide_out_req_o   ( wide_out_req ),
    .axi_wide_out_rsp_i   ( wide_out_rsp ),
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

  localparam axi_cfg_t AxiCfgJoin = '{
    AddrWidth: AxiCfgN.AddrWidth,
    DataWidth: AxiCfgN.DataWidth,
    UserWidth: max(AxiCfgN.UserWidth, AxiCfgW.UserWidth),
    InIdWidth: 0, // Not used in `nw_join`
    OutIdWidth: max(AxiCfgN.OutIdWidth, AxiCfgW.OutIdWidth)
  };

  `FLOO_TYPEDEF_AXI_FROM_CFG(nw_join, AxiCfgJoin)

  nw_join_in_req_t nw_join_req;
  nw_join_in_rsp_t nw_join_rsp;

  floo_nw_join #(
    .AxiCfgN          ( axi_cfg_swap_iw(AxiCfgN)    ),
    .AxiCfgW          ( axi_cfg_swap_iw(AxiCfgW)    ),
    .AxiCfgJoin       ( axi_cfg_swap_iw(AxiCfgJoin) ),
    // We should not have any ATOPs in the wide path
    .FilterWideAtops  ( 1'b1 ),
    // We don't need it since there is one in Cheshire
    .EnAtopAdapter    ( 1'b0 ),
    .axi_narrow_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_req_t   ( axi_wide_out_req_t   ),
    .axi_wide_rsp_t   ( axi_wide_out_rsp_t   ),
    .axi_req_t        ( nw_join_in_req_t     ),
    .axi_rsp_t        ( nw_join_in_rsp_t     )
  ) i_floo_nw_join (
    .clk_i,
    .rst_ni,
    .test_enable_i    ( test_mode_i    ),
    .axi_narrow_req_i ( narrow_out_req ),
    .axi_narrow_rsp_o ( narrow_out_rsp ),
    .axi_wide_req_i   ( wide_out_req   ),
    .axi_wide_rsp_o   ( wide_out_rsp   ),
    .axi_req_o        ( nw_join_req    ),
    .axi_rsp_i        ( nw_join_rsp    )
  );

  //////////////
  // Cheshire //
  //////////////

  `CHESHIRE_TYPEDEF_ALL(csh_, CheshireCfg)

  csh_axi_mst_req_t axi_ext_mst_req_in;
  csh_axi_mst_rsp_t axi_ext_mst_rsp_out;
  csh_axi_slv_req_t axi_ext_slv_req_out;
  csh_axi_slv_rsp_t axi_ext_slv_rsp_in;

  `AXI_ASSIGN_REQ_STRUCT(axi_ext_mst_req_in, nw_join_req)
  `AXI_ASSIGN_RESP_STRUCT(nw_join_rsp, axi_ext_mst_rsp_out)
  `AXI_ASSIGN_REQ_STRUCT(narrow_in_req, axi_ext_slv_req_out)
  `AXI_ASSIGN_RESP_STRUCT(axi_ext_slv_rsp_in, narrow_in_rsp)

  cheshire_soc #(
    .Cfg                ( CheshireCfg ),
    .axi_ext_llc_req_t  ( csh_axi_llc_req_t ),
    .axi_ext_llc_rsp_t  ( csh_axi_llc_rsp_t ),
    .axi_ext_mst_req_t  ( csh_axi_mst_req_t ),
    .axi_ext_mst_rsp_t  ( csh_axi_mst_rsp_t ),
    .axi_ext_slv_req_t  ( csh_axi_slv_req_t ),
    .axi_ext_slv_rsp_t  ( csh_axi_slv_rsp_t ),
    .reg_ext_req_t      ( csh_reg_req_t ),
    .reg_ext_rsp_t      ( csh_reg_rsp_t )
  ) i_cheshire_soc (
    .clk_i,
    .rst_ni,
    .test_mode_i,
    .boot_mode_i,
    .rtc_i,
    // TODO(fischeti): Connect if we will use DRAM/Hyperram
    .axi_llc_mst_req_o (   ),
    .axi_llc_mst_rsp_i ('0 ),
    .axi_ext_mst_req_i ( axi_ext_mst_req_in  ),
    .axi_ext_mst_rsp_o ( axi_ext_mst_rsp_out ),
    .axi_ext_slv_req_o ( axi_ext_slv_req_out ),
    .axi_ext_slv_rsp_i ( axi_ext_slv_rsp_in  ),
    // TODO(fischeti): Connect to SoC config registers if needed
    .reg_ext_slv_req_o (    ),
    .reg_ext_slv_rsp_i ( '0 ),
    // TODO(fischeti): Do we need external interrupts?
    .intr_ext_i ( '0 ),
    .intr_ext_o (    ),
    .xeip_ext_o,
    .mtip_ext_o,
    .msip_ext_o,
    // TODO(fischeti): Do we need debug capabilities for external cores?
    .dbg_active_o      (    ),
    .dbg_ext_req_o     (    ),
    .dbg_ext_unavail_i ( '0 ),
    .jtag_tck_i,
    .jtag_trst_ni,
    .jtag_tms_i,
    .jtag_tdi_i,
    .jtag_tdo_o,
    .jtag_tdo_oe_o,
    .uart_tx_o,
    .uart_rx_i,
    .uart_rts_no,
    .uart_dtr_no,
    .uart_cts_ni,
    .uart_dsr_ni,
    .uart_dcd_ni,
    .uart_rin_ni,
    .i2c_sda_o,
    .i2c_sda_i,
    .i2c_sda_en_o,
    .i2c_scl_o,
    .i2c_scl_i,
    .i2c_scl_en_o,
    .spih_sck_o,
    .spih_sck_en_o,
    .spih_csb_o,
    .spih_csb_en_o,
    .spih_sd_o,
    .spih_sd_en_o,
    .spih_sd_i,
    .gpio_i,
    .gpio_o,
    .gpio_en_o,
    .slink_rcv_clk_i,
    .slink_rcv_clk_o,
    .slink_i,
    .slink_o,
    // TODO(fischeti): Check if we need/want VGA
    .vga_hsync_o ( ),
    .vga_vsync_o ( ),
    .vga_red_o   ( ),
    .vga_green_o ( ),
    .vga_blue_o  ( ),
    // TODO(fischeti): Check if we need/want USB
    .usb_clk_i   ( '0 ),
    .usb_rst_ni  ( '0 ),
    .usb_dm_i    ( '0 ),
    .usb_dm_o    (    ),
    .usb_dm_oe_o (    ),
    .usb_dp_i    ( '0 ),
    .usb_dp_o    (    ),
    .usb_dp_oe_o (    )
  );

endmodule
