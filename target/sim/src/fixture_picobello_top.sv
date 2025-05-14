// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

module fixture_picobello_top;

  `include "cheshire/typedef.svh"

  import cheshire_pkg::*;
  import picobello_pkg::*;

  `CHESHIRE_TYPEDEF_ALL(, CheshireCfg)

  ///////////
  //  DUT  //
  ///////////

  // verilog_format: off
  logic       clk;
  logic       rst_n;
  logic       test_mode;
  logic [1:0] boot_mode;
  logic       rtc;

  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;

  logic uart_tx;
  logic uart_rx;

  logic i2c_sda_o;
  logic i2c_sda_i;
  logic i2c_sda_en;
  logic i2c_scl_o;
  logic i2c_scl_i;
  logic i2c_scl_en;

  logic                 spih_sck_o;
  logic                 spih_sck_en;
  logic [SpihNumCs-1:0] spih_csb_o;
  logic [SpihNumCs-1:0] spih_csb_en;
  logic [ 3:0]          spih_sd_o;
  logic [ 3:0]          spih_sd_i;
  logic [ 3:0]          spih_sd_en;

  logic [SlinkNumChan-1:0]                    slink_rcv_clk_i;
  logic [SlinkNumChan-1:0]                    slink_rcv_clk_o;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o;

  logic [SlinkNumChan-1:0]                    dram_slink_rcv_clk_i;
  logic [SlinkNumChan-1:0]                    dram_slink_rcv_clk_o;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] dram_slink_i;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] dram_slink_o;
  // verilog_format: on

  picobello_top dut (
    .clk_i               (clk),
    .rst_ni              (rst_n),
    .test_mode_i         (test_mode),
    .boot_mode_i         (boot_mode),
    .rtc_i               (rtc),
    .jtag_tck_i          (jtag_tck),
    .jtag_trst_ni        (jtag_trst_n),
    .jtag_tms_i          (jtag_tms),
    .jtag_tdi_i          (jtag_tdi),
    .jtag_tdo_o          (jtag_tdo),
    .jtag_tdo_oe_o       (),
    .uart_tx_o           (uart_tx),
    .uart_rx_i           (uart_rx),
    .uart_rts_no         (),
    .uart_dtr_no         (),
    .uart_cts_ni         (1'b0),
    .uart_dsr_ni         (1'b0),
    .uart_dcd_ni         (1'b0),
    .uart_rin_ni         (1'b0),
    .i2c_sda_o           (i2c_sda_o),
    .i2c_sda_i           (i2c_sda_i),
    .i2c_sda_en_o        (i2c_sda_en),
    .i2c_scl_o           (i2c_scl_o),
    .i2c_scl_i           (i2c_scl_i),
    .i2c_scl_en_o        (i2c_scl_en),
    .spih_sck_o          (spih_sck_o),
    .spih_sck_en_o       (spih_sck_en),
    .spih_csb_o          (spih_csb_o),
    .spih_csb_en_o       (spih_csb_en),
    .spih_sd_o           (spih_sd_o),
    .spih_sd_en_o        (spih_sd_en),
    .spih_sd_i           (spih_sd_i),
    .gpio_i              ('0),
    .gpio_o              (),
    .gpio_en_o           (),
    .slink_rcv_clk_i     (slink_rcv_clk_i),
    .slink_rcv_clk_o     (slink_rcv_clk_o),
    .slink_i             (slink_i),
    .slink_o             (slink_o),
    .dram_slink_rcv_clk_i(dram_slink_rcv_clk_i),
    .dram_slink_rcv_clk_o(dram_slink_rcv_clk_o),
    .dram_slink_i        (dram_slink_i),
    .dram_slink_o        (dram_slink_o)
  );

  ////////////////////////
  //  Tristate Adapter  //
  ////////////////////////

  wire                 i2c_sda;
  wire                 i2c_scl;

  wire                 spih_sck;
  wire [SpihNumCs-1:0] spih_csb;
  wire [          3:0] spih_sd;

  vip_cheshire_soc_tristate vip_tristate (.*);

  ///////////
  //  VIP  //
  ///////////

  axi_mst_req_t axi_slink_mst_req;
  axi_mst_rsp_t axi_slink_mst_rsp;

  axi_llc_req_t axi_llc_mst_req;
  axi_llc_rsp_t axi_llc_mst_rsp;

  assign axi_slink_mst_req = '0;

  // Mirror instance of serial link, reflecting DRAM on FPGA
  serial_link #(
    .axi_req_t  (axi_llc_req_t),
    .axi_rsp_t  (axi_llc_rsp_t),
    .cfg_req_t  (reg_req_t),
    .cfg_rsp_t  (reg_rsp_t),
    .aw_chan_t  (axi_llc_aw_chan_t),
    .ar_chan_t  (axi_llc_ar_chan_t),
    .r_chan_t   (axi_llc_r_chan_t),
    .w_chan_t   (axi_llc_w_chan_t),
    .b_chan_t   (axi_llc_b_chan_t),
    .hw2reg_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t),
    .reg2hw_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t),
    .NumChannels(SlinkNumChan),
    .NumLanes   (SlinkNumLanes),
    .MaxClkDiv  (SlinkMaxClkDiv)
  ) i_dram_serial_link (
    .clk_i        (clk),
    .rst_ni       (rst_n),
    .clk_sl_i     (clk),
    .rst_sl_ni    (rst_n),
    .clk_reg_i    (clk),
    .rst_reg_ni   (rst_n),
    .testmode_i   (test_mode),
    .axi_in_req_i ('0),
    .axi_in_rsp_o (),
    .axi_out_req_o(axi_llc_mst_req),
    .axi_out_rsp_i(axi_llc_mst_rsp),
    .cfg_req_i    ('0),
    .cfg_rsp_o    (),
    .ddr_rcv_clk_i(dram_slink_rcv_clk_o),
    .ddr_rcv_clk_o(dram_slink_rcv_clk_i),
    .ddr_i        (dram_slink_o),
    .ddr_o        (dram_slink_i),
    .isolated_i   ('0),
    .isolate_o    (),
    .clk_ena_o    (),
    .reset_no     ()
  );

  vip_cheshire_soc #(
    .DutCfg           (CheshireCfg),
    .UseDramSys       (1'b0),
    .axi_ext_llc_req_t(axi_llc_req_t),
    .axi_ext_llc_rsp_t(axi_llc_rsp_t),
    .axi_ext_mst_req_t(axi_mst_req_t),
    .axi_ext_mst_rsp_t(axi_mst_rsp_t)
  ) vip (
    .*
  );

  initial begin
    print_sam_multicast(SamMcast);
  end

endmodule
