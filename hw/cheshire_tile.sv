// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "apb/typedef.svh"
`include "cheshire/typedef.svh"
`include "floo_noc/typedef.svh"
`include "axi/assign.svh"
`include "common_cells/assertions.svh"


module cheshire_tile
  import cheshire_pkg::*;
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
  import pb_soc_regs_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,
  input logic test_mode_i,
  input logic [1:0] boot_mode_i,
  input logic rtc_i,
  // Interrupt requests to external harts
  output logic [iomsb(NumIrqCtxts*CheshireCfg.NumExtIrqHarts):0] xeip_ext_o,
  output logic [iomsb(CheshireCfg.NumExtIrqHarts):0] mtip_ext_o,
  output logic [iomsb(CheshireCfg.NumExtIrqHarts):0] msip_ext_o,
  // JTAG
  input logic jtag_tck_i,
  input logic jtag_trst_ni,
  input logic jtag_tms_i,
  input logic jtag_tdi_i,
  output logic jtag_tdo_o,
  output logic jtag_tdo_oe_o,
  // UART interface
  output logic uart_tx_o,
  input logic uart_rx_i,
  // UART modem flow control
  output logic uart_rts_no,
  output logic uart_dtr_no,
  input logic uart_cts_ni,
  input logic uart_dsr_ni,
  input logic uart_dcd_ni,
  input logic uart_rin_ni,
  // I2C interface
  output logic i2c_sda_o,
  input logic i2c_sda_i,
  output logic i2c_sda_en_o,
  output logic i2c_scl_o,
  input logic i2c_scl_i,
  output logic i2c_scl_en_o,
  // SPI host interface
  output logic spih_sck_o,
  output logic spih_sck_en_o,
  output logic [SpihNumCs-1:0] spih_csb_o,
  output logic [SpihNumCs-1:0] spih_csb_en_o,
  output logic [3:0] spih_sd_o,
  output logic [3:0] spih_sd_en_o,
  input logic [3:0] spih_sd_i,
  // GPIO interface
  input logic [31:0] gpio_i,
  output logic [31:0] gpio_o,
  output logic [31:0] gpio_en_o,
  // register interfaces
  output csh_reg_req_t [CshRegExtChipCtrl:CshRegExtFLL] reg_req_o,
  input csh_reg_rsp_t [CshRegExtChipCtrl:CshRegExtFLL] reg_rsp_i,
  // Serial link interface
  input logic [SlinkNumChan-1:0] slink_rcv_clk_i,
  output logic [SlinkNumChan-1:0] slink_rcv_clk_o,
  input logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i,
  output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o,
  // DRAM Serial link interface
  input logic [SlinkNumChan-1:0] dram_slink_rcv_clk_i,
  output logic [SlinkNumChan-1:0] dram_slink_rcv_clk_o,
  input logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] dram_slink_i,
  output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] dram_slink_o,
  // Chimney ports
  input id_t id_i,
  // Router ports
  output floo_req_t floo_req_west_o,
  input floo_rsp_t floo_rsp_west_i,
  output floo_wide_t floo_wide_west_o,
  input floo_req_t floo_req_west_i,
  output floo_rsp_t floo_rsp_west_o,
  input floo_wide_t floo_wide_west_i,
  output floo_req_t floo_req_south_o,
  input floo_rsp_t floo_rsp_south_i,
  output floo_wide_t floo_wide_south_o,
  input floo_req_t floo_req_south_i,
  output floo_rsp_t floo_rsp_south_o,
  input floo_wide_t floo_wide_south_i,
  // Tile-specific clock gating and reset
  output logic [NumClusters-1:0] cluster_rst_no,
  output logic [NumClusters-1:0] cluster_clk_en_o,
  output logic [NumMemTiles-1:0] mem_tile_rst_no,
  output logic [NumMemTiles-1:0] mem_tile_clk_en_o,
  output logic fhg_spu_rst_no,
  output logic fhg_spu_clk_en_o
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
    .id_i,
    .test_enable_i (test_mode_i),
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
  assign floo_req_south_o           = router_floo_req_out[South];
  assign router_floo_req_in[West]   = floo_req_west_i;
  assign router_floo_req_in[North]  = '0;  // No North port in this tile
  assign router_floo_req_in[East]   = '0;  // No East port in this tile
  assign router_floo_req_in[South]  = floo_req_south_i;
  assign floo_rsp_west_o            = router_floo_rsp_out[West];
  assign floo_rsp_south_o           = router_floo_rsp_out[South];
  assign router_floo_rsp_in[West]   = floo_rsp_west_i;
  assign router_floo_rsp_in[North]  = '0;  // No North port in this tile
  assign router_floo_rsp_in[East]   = '0;  // No East port in this tile
  assign router_floo_rsp_in[South]  = floo_rsp_south_i;
  assign floo_wide_west_o           = router_floo_wide_out[West];
  assign floo_wide_south_o          = router_floo_wide_out[South];
  assign router_floo_wide_in[West]  = floo_wide_west_i;
  assign router_floo_wide_in[North] = '0;  // No North port in this tile
  assign router_floo_wide_in[East]  = '0;  // No East port in this tile
  assign router_floo_wide_in[South] = floo_wide_south_i;

  /////////////
  // Chimney //
  /////////////

  axi_narrow_out_req_t narrow_out_req;
  axi_narrow_out_rsp_t narrow_out_rsp;
  axi_narrow_in_req_t  narrow_in_req;
  axi_narrow_in_rsp_t  narrow_in_rsp;
  axi_wide_out_req_t   wide_out_req;
  axi_wide_out_rsp_t   wide_out_rsp;

  localparam chimney_cfg_t ChimneyCfgN = ChimneyDefaultCfg;
  localparam chimney_cfg_t ChimneyCfgW = set_ports(ChimneyDefaultCfg, 1'b1, 1'b0);

  floo_nw_chimney #(
    .AxiCfgN             (AxiCfgN),
    .AxiCfgW             (AxiCfgW),
    .ChimneyCfgN         (ChimneyCfgN),
    .ChimneyCfgW         (ChimneyCfgW),
    .RouteCfg            (RouteCfgNoMcast),
    .AtopSupport         (1'b1),
    .MaxAtomicTxns       (AxiCfgN.OutIdWidth - 1),
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
    .id_i,
    .test_enable_i       (test_mode_i),
    .sram_cfg_i          ('0),
    .route_table_i       ('0),
    .axi_narrow_in_req_i (narrow_in_req),
    .axi_narrow_in_rsp_o (narrow_in_rsp),
    .axi_narrow_out_req_o(narrow_out_req),
    .axi_narrow_out_rsp_i(narrow_out_rsp),
    .axi_wide_in_req_i   ('0),
    .axi_wide_in_rsp_o   (),
    .axi_wide_out_req_o  (wide_out_req),
    .axi_wide_out_rsp_i  (wide_out_rsp),
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

  localparam axi_cfg_t AxiCfgJoin = '{
      AddrWidth: AxiCfgN.AddrWidth,
      DataWidth: AxiCfgN.DataWidth,
      UserWidth: max(AxiCfgN.UserWidth, AxiCfgW.UserWidth),
      InIdWidth: 0,  // Not used in `nw_join`
      OutIdWidth: max(AxiCfgN.OutIdWidth, AxiCfgW.OutIdWidth)
  };

  `FLOO_TYPEDEF_AXI_FROM_CFG(nw_join, AxiCfgJoin)

  nw_join_in_req_t nw_join_req;
  nw_join_in_rsp_t nw_join_rsp;

  floo_nw_join #(
    .AxiCfgN         (axi_cfg_swap_iw(AxiCfgN)),
    .AxiCfgW         (axi_cfg_swap_iw(AxiCfgW)),
    .AxiCfgJoin      (axi_cfg_swap_iw(AxiCfgJoin)),
    // We should not have any ATOPs in the wide path
    .FilterWideAtops (1'b1),
    // We don't need it since there is one in Cheshire
    .EnAtopAdapter   (1'b0),
    .axi_narrow_req_t(axi_narrow_out_req_t),
    .axi_narrow_rsp_t(axi_narrow_out_rsp_t),
    .axi_wide_req_t  (axi_wide_out_req_t),
    .axi_wide_rsp_t  (axi_wide_out_rsp_t),
    .axi_req_t       (nw_join_in_req_t),
    .axi_rsp_t       (nw_join_in_rsp_t)
  ) i_floo_nw_join (
    .clk_i,
    .rst_ni,
    .test_enable_i   (test_mode_i),
    .axi_narrow_req_i(narrow_out_req),
    .axi_narrow_rsp_o(narrow_out_rsp),
    .axi_wide_req_i  (wide_out_req),
    .axi_wide_rsp_o  (wide_out_rsp),
    .axi_req_o       (nw_join_req),
    .axi_rsp_i       (nw_join_rsp)
  );

  //////////////
  // Cheshire //
  //////////////

  csh_axi_llc_req_t                                axi_llc_req;
  csh_axi_llc_rsp_t                                axi_llc_rsp;
  csh_axi_mst_req_t [CheshireCfg.AxiExtNumMst-1:0] axi_ext_mst_req_in;
  csh_axi_mst_rsp_t [CheshireCfg.AxiExtNumMst-1:0] axi_ext_mst_rsp_out;
  csh_axi_slv_req_t [CheshireCfg.AxiExtNumSlv-1:0] axi_ext_slv_req_out;
  csh_axi_slv_rsp_t [CheshireCfg.AxiExtNumSlv-1:0] axi_ext_slv_rsp_in;
  csh_reg_req_t     [CheshireCfg.RegExtNumSlv-1:0] reg_ext_req;
  csh_reg_rsp_t     [CheshireCfg.RegExtNumSlv-1:0] reg_ext_rsp;

  `AXI_ASSIGN_REQ_STRUCT(axi_ext_mst_req_in[0], nw_join_req)
  `AXI_ASSIGN_RESP_STRUCT(nw_join_rsp, axi_ext_mst_rsp_out[0])
  `AXI_ASSIGN_REQ_STRUCT(narrow_in_req, axi_ext_slv_req_out[0])
  `AXI_ASSIGN_RESP_STRUCT(axi_ext_slv_rsp_in[0], narrow_in_rsp)

  cheshire_soc #(
    .Cfg              (CheshireCfg),
    .axi_ext_llc_req_t(csh_axi_llc_req_t),
    .axi_ext_llc_rsp_t(csh_axi_llc_rsp_t),
    .axi_ext_mst_req_t(csh_axi_mst_req_t),
    .axi_ext_mst_rsp_t(csh_axi_mst_rsp_t),
    .axi_ext_slv_req_t(csh_axi_slv_req_t),
    .axi_ext_slv_rsp_t(csh_axi_slv_rsp_t),
    .reg_ext_req_t    (csh_reg_req_t),
    .reg_ext_rsp_t    (csh_reg_rsp_t)
  ) i_cheshire_soc (
    .clk_i,
    .rst_ni,
    .test_mode_i,
    .boot_mode_i,
    .rtc_i,
    .axi_llc_mst_req_o(axi_llc_req),
    .axi_llc_mst_rsp_i(axi_llc_rsp),
    .axi_ext_mst_req_i(axi_ext_mst_req_in),
    .axi_ext_mst_rsp_o(axi_ext_mst_rsp_out),
    .axi_ext_slv_req_o(axi_ext_slv_req_out),
    .axi_ext_slv_rsp_i(axi_ext_slv_rsp_in),
    .reg_ext_slv_req_o(reg_ext_req),
    .reg_ext_slv_rsp_i(reg_ext_rsp),
    // TODO(fischeti): Do we need external interrupts?
    .intr_ext_i       ('0),
    .intr_ext_o       (),
    .xeip_ext_o,
    .mtip_ext_o,
    .msip_ext_o,
    // TODO(fischeti): Do we need debug capabilities for external cores?
    .dbg_active_o     (),
    .dbg_ext_req_o    (),
    .dbg_ext_unavail_i('0),
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
    // We do not need/want VGA
    .vga_hsync_o      (),
    .vga_vsync_o      (),
    .vga_red_o        (),
    .vga_green_o      (),
    .vga_blue_o       (),
    // We do not need/want USB
    .usb_clk_i        ('0),
    .usb_rst_ni       ('0),
    .usb_dm_i         ('0),
    .usb_dm_o         (),
    .usb_dm_oe_o      (),
    .usb_dp_i         ('0),
    .usb_dp_o         (),
    .usb_dp_oe_o      ()
  );

  // Connect to the chip-level register interfaces
  assign reg_req_o                                   = reg_ext_req[CshRegExtChipCtrl:CshRegExtFLL];
  assign reg_ext_rsp[CshRegExtChipCtrl:CshRegExtFLL] = reg_rsp_i;

  // Serial Link to connect to DRAM on an FPGA
  csh_axi_llc_req_t dram_slink_err_req;
  csh_axi_llc_rsp_t dram_slink_err_rsp;

  serial_link #(
    .axi_req_t  (csh_axi_llc_req_t),
    .axi_rsp_t  (csh_axi_llc_rsp_t),
    .cfg_req_t  (csh_reg_req_t),
    .cfg_rsp_t  (csh_reg_rsp_t),
    .aw_chan_t  (csh_axi_llc_aw_chan_t),
    .ar_chan_t  (csh_axi_llc_ar_chan_t),
    .r_chan_t   (csh_axi_llc_r_chan_t),
    .w_chan_t   (csh_axi_llc_w_chan_t),
    .b_chan_t   (csh_axi_llc_b_chan_t),
    .hw2reg_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t),
    .reg2hw_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t),
    .NumChannels(SlinkNumChan),
    .NumLanes   (SlinkNumLanes),
    .MaxClkDiv  (SlinkMaxClkDiv)
  ) i_dram_serial_link (
    .clk_i,
    .rst_ni,
    .clk_sl_i     (clk_i),
    .rst_sl_ni    (rst_ni),
    .clk_reg_i    (clk_i),
    .rst_reg_ni   (rst_ni),
    .testmode_i   (test_mode_i),
    .axi_in_req_i (axi_llc_req),
    .axi_in_rsp_o (axi_llc_rsp),
    .axi_out_req_o(dram_slink_err_req),
    .axi_out_rsp_i(dram_slink_err_rsp),
    .cfg_req_i    (reg_ext_req[CshRegExtDramSerialLink]),
    .cfg_rsp_o    (reg_ext_rsp[CshRegExtDramSerialLink]),
    .ddr_rcv_clk_i(dram_slink_rcv_clk_i),
    .ddr_rcv_clk_o(dram_slink_rcv_clk_o),
    .ddr_i        (dram_slink_i),
    .ddr_o        (dram_slink_o),
    .isolated_i   ('0),
    .isolate_o    (),
    .clk_ena_o    (),
    .reset_no     ()
  );

  axi_err_slv #(
    .AxiIdWidth(CheshireCfg.AxiMstIdWidth + $clog2(
        csh_axi__AxiIn.num_in
    ) + CheshireCfg.LlcNotBypass),
    .axi_req_t(csh_axi_llc_req_t),
    .axi_resp_t(csh_axi_llc_rsp_t),
    .Resp(axi_pkg::RESP_DECERR),
    .RespWidth(CheshireCfg.AxiDataWidth),
    .RespData(64'hCA11AB1EBADCAB1E),
    .ATOPs(1'b1),
    .MaxTrans(4)  // TODO maybe tune, but this block should never be used.
  ) i_dram_slink_err (
    .clk_i,
    .rst_ni,
    .test_i    (test_mode_i),
    .slv_req_i (dram_slink_err_req),
    .slv_resp_o(dram_slink_err_rsp)
  );

  // to apb bus (declare type for req and resp)
  `APB_TYPEDEF_ALL(apb, logic[CheshireCfg.AddrWidth-1:0], logic[31:0], logic[3:0])

  apb_req_t                           csh_apb_req;
  apb_resp_t                          csh_apb_rsp;
  pb_soc_regs_pkg::pb_soc_regs__out_t control_reg;

  reg_to_apb #(
    .reg_req_t(csh_reg_req_t),
    .reg_rsp_t(csh_reg_rsp_t),
    .apb_req_t(apb_req_t),
    .apb_rsp_t(apb_resp_t)
  ) i_reg_to_apb (
    .clk_i,
    .rst_ni,
    .reg_req_i(reg_ext_req[CshRegExtClkGatingRst]),
    .reg_rsp_o(reg_ext_rsp[CshRegExtClkGatingRst]),
    .apb_req_o(csh_apb_req),
    .apb_rsp_i(csh_apb_rsp)
  );

  pb_soc_regs i_pb_soc_regs (
    .clk          (clk_i),
    .arst_n       (rst_ni),
    .s_apb_paddr  (csh_apb_req.paddr[PB_SOC_REGS_MIN_ADDR_WIDTH-1:0]),
    .s_apb_penable(csh_apb_req.penable),
    .s_apb_psel   (csh_apb_req.psel),
    .s_apb_pwrite (csh_apb_req.pwrite),
    .s_apb_pprot  (csh_apb_req.pprot),
    .s_apb_pwdata (csh_apb_req.pwdata),
    .s_apb_pstrb  (csh_apb_req.pstrb),
    .s_apb_prdata (csh_apb_rsp.prdata),
    .s_apb_pready (csh_apb_rsp.pready),
    .s_apb_pslverr(csh_apb_rsp.pslverr),
    .hwif_out     (control_reg)
  );

  for (genvar i = 0; i < NumClusters; i++) begin : gen_cluster_ctrl_out
    assign cluster_rst_no[i]   = control_reg.cluster_rsts.rst.value[i];
    assign cluster_clk_en_o[i] = control_reg.cluster_clk_enables.clk_en.value[i];
  end
  for (genvar i = 0; i < NumMemTiles; i++) begin : gen_mem_tile_ctrl_out
    assign mem_tile_rst_no[i]   = control_reg.mem_tile_rsts.rst.value[i];
    assign mem_tile_clk_en_o[i] = control_reg.mem_tile_clk_enables.clk_en.value[i];
  end
  assign fhg_spu_rst_no   = control_reg.fhg_spu_rsts.rst.value;
  assign fhg_spu_clk_en_o = control_reg.fhg_spu_clk_enables.clk_en.value;

  // Add Assertion that no multicast / reduction can enter this tile!
  for (genvar r = 0; r < 4; r++) begin : gen_virt
    `ASSERT(NoCollectivOperation_NReq_In, (!router_floo_req_in[r].valid | (router_floo_req_in[r].req.generic.hdr.collective_op == Unicast)))
    `ASSERT(NoCollectivOperation_NRsp_In, (!router_floo_rsp_in[r].valid | (router_floo_rsp_in[r].rsp.generic.hdr.collective_op == Unicast)))
    `ASSERT(NoCollectivOperation_NWide_In, (!router_floo_wide_in[r].valid | (router_floo_wide_in[r].wide.generic.hdr.collective_op == Unicast)))
    `ASSERT(NoCollectivOperation_NReq_Out, (!router_floo_req_out[r].valid | (router_floo_req_out[r].req.generic.hdr.collective_op == Unicast)))
    `ASSERT(NoCollectivOperation_NRsp_Out, (!router_floo_rsp_out[r].valid | (router_floo_rsp_out[r].rsp.generic.hdr.collective_op == Unicast)))
    `ASSERT(NoCollectivOperation_NWide_Out, (!router_floo_wide_out[r].valid | (router_floo_wide_out[r].wide.generic.hdr.collective_op == Unicast)))
  end

endmodule
