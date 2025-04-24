// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

module picobello_top
  import picobello_pkg::*;
  import cheshire_pkg::*;
  import floo_pkg::*;
  import snitch_cluster_pkg::*;
  import floo_picobello_noc_pkg::*;
(
  input  logic                                       clk_i,
  input  logic                                       rst_ni,
  input  logic                                       test_mode_i,
  input  logic [             1:0]                    boot_mode_i,
  input  logic                                       rtc_i,
  // JTAG
  input  logic                                       jtag_tck_i,
  input  logic                                       jtag_trst_ni,
  input  logic                                       jtag_tms_i,
  input  logic                                       jtag_tdi_i,
  output logic                                       jtag_tdo_o,
  output logic                                       jtag_tdo_oe_o,
  // UART interface
  output logic                                       uart_tx_o,
  input  logic                                       uart_rx_i,
  // UART modem flow control
  output logic                                       uart_rts_no,
  output logic                                       uart_dtr_no,
  input  logic                                       uart_cts_ni,
  input  logic                                       uart_dsr_ni,
  input  logic                                       uart_dcd_ni,
  input  logic                                       uart_rin_ni,
  // I2C interface
  output logic                                       i2c_sda_o,
  input  logic                                       i2c_sda_i,
  output logic                                       i2c_sda_en_o,
  output logic                                       i2c_scl_o,
  input  logic                                       i2c_scl_i,
  output logic                                       i2c_scl_en_o,
  // SPI host interface
  output logic                                       spih_sck_o,
  output logic                                       spih_sck_en_o,
  output logic [   SpihNumCs-1:0]                    spih_csb_o,
  output logic [   SpihNumCs-1:0]                    spih_csb_en_o,
  output logic [             3:0]                    spih_sd_o,
  output logic [             3:0]                    spih_sd_en_o,
  input  logic [             3:0]                    spih_sd_i,
  // GPIO interface
  input  logic [            31:0]                    gpio_i,
  output logic [            31:0]                    gpio_o,
  output logic [            31:0]                    gpio_en_o,
  // Serial link interface
  input  logic [SlinkNumChan-1:0]                    slink_rcv_clk_i,
  output logic [SlinkNumChan-1:0]                    slink_rcv_clk_o,
  input  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i,
  output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o
);

  floo_req_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_req_in, floo_req_out;
  floo_rsp_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_rsp_in, floo_rsp_out;
  floo_wide_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_wide_in, floo_wide_out;

  ///////////////////
  // Cluster tiles //
  ///////////////////

  logic [NumClusters-1:0][NrCores-1:0] debug_req, meip, mtip, msip;

  // TODO: Connect the debug and interrupt signals
  assign debug_req = '0;
  assign meip      = '0;
  assign mtip      = '0;
  assign msip      = '0;

  for (genvar c = 0; c < NumClusters; c++) begin : gen_clusters

    localparam int ClusterSamIdx = c + ClusterX0Y0SamIdx;
    localparam id_t ClusterId = Sam[ClusterSamIdx].idx;
    localparam int X = int'(ClusterId.x);
    localparam int Y = int'(ClusterId.y);
    localparam int unsigned HartBaseId = c * NrCores;
    localparam axi_wide_in_addr_t ClusterBaseAddr = Sam[ClusterSamIdx].start_addr;

    cluster_tile i_cluster_tile (
      .clk_i,
      .rst_ni,
      .test_enable_i      (test_mode_i),
      .debug_req_i        (debug_req[c]),
      .meip_i             (meip[c]),
      .mtip_i             (mtip[c]),
      .msip_i             (msip[c]),
      .hart_base_id_i     (HartBaseId[9:0]),
      .cluster_base_addr_i(ClusterBaseAddr),
      .id_i               (ClusterId),
      .floo_req_o         (floo_req_out[X][Y]),
      .floo_rsp_i         (floo_rsp_in[X][Y]),
      .floo_wide_o        (floo_wide_out[X][Y]),
      .floo_req_i         (floo_req_in[X][Y]),
      .floo_rsp_o         (floo_rsp_out[X][Y]),
      .floo_wide_i        (floo_wide_in[X][Y])
    );
  end

  ///////////////////
  // Cheshire tile //
  ///////////////////

  // TODO(fischeti): Connect the interrupt signals
  logic [iomsb(NumIrqCtxts*CheshireCfg.NumExtIrqHarts):0] xeip_ext;
  logic [            iomsb(CheshireCfg.NumExtIrqHarts):0] mtip_ext;
  logic [            iomsb(CheshireCfg.NumExtIrqHarts):0] msip_ext;

  localparam id_t CheshireId = Sam[CheshireInternalSamIdx].idx;

  cheshire_tile i_cheshire_tile (
    .clk_i,
    .rst_ni,
    .test_mode_i,
    .boot_mode_i,
    .rtc_i,
    .xeip_ext_o (xeip_ext),
    .mtip_ext_o (mtip_ext),
    .msip_ext_o (msip_ext),
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
    .id_i       (CheshireId),
    .floo_req_o (floo_req_out[CheshireId.x][CheshireId.y]),
    .floo_rsp_i (floo_rsp_in[CheshireId.x][CheshireId.y]),
    .floo_wide_o(floo_wide_out[CheshireId.x][CheshireId.y]),
    .floo_req_i (floo_req_in[CheshireId.x][CheshireId.y]),
    .floo_rsp_o (floo_rsp_out[CheshireId.x][CheshireId.y]),
    .floo_wide_i(floo_wide_in[CheshireId.x][CheshireId.y])
  );

  //////////////////
  // FhG SPU tile //
  //////////////////

  // TODO: Connect the debug and interrupt signals
  logic [8:0] fhg_spu_debug_req, fhg_spu_meip, fhg_spu_mtip, fhg_spu_msip;

  assign fhg_spu_debug_req = '0;
  assign fhg_spu_meip      = '0;
  assign fhg_spu_mtip      = '0;
  assign fhg_spu_msip      = '0;

  localparam id_t FhgSpuId = Sam[FhgSpuSamIdx].idx;

  // TODO: connect actual hart_base_id
  fhg_spu_tile i_fhg_spu_tile (
    .clk_i,
    .rst_ni,
    .test_enable_i      (test_mode_i),
    .debug_req_i        (fhg_spu_debug_req),
    .meip_i             (fhg_spu_meip),
    .mtip_i             (fhg_spu_mtip),
    .msip_i             (fhg_spu_msip),
    .hart_base_id_i     ('0),
    .cluster_base_addr_i(Sam[FhgSpuSamIdx].start_addr),
    .id_i               (FhgSpuId),
    .floo_req_o         (floo_req_out[FhgSpuId.x][FhgSpuId.y]),
    .floo_rsp_i         (floo_rsp_in[FhgSpuId.x][FhgSpuId.y]),
    .floo_wide_o        (floo_wide_out[FhgSpuId.x][FhgSpuId.y]),
    .floo_req_i         (floo_req_in[FhgSpuId.x][FhgSpuId.y]),
    .floo_rsp_o         (floo_rsp_out[FhgSpuId.x][FhgSpuId.y]),
    .floo_wide_i        (floo_wide_in[FhgSpuId.x][FhgSpuId.y])
  );

  //////////////
  // Mem tile //
  //////////////

  for (genvar m = 0; m < NumMemTiles; m++) begin : gen_memtile

    localparam int MemTileSamIdx = m + L2Spm0SamIdx;
    localparam id_t MemTileId = Sam[MemTileSamIdx].idx;
    localparam int MemTileX = int'(MemTileId.x);
    localparam int MemTileY = int'(MemTileId.y);

    mem_tile i_mem_tile (
      .clk_i,
      .rst_ni,
      .test_enable_i(test_mode_i),
      .id_i         (MemTileId),
      .floo_req_o   (floo_req_out[MemTileX][MemTileY]),
      .floo_rsp_i   (floo_rsp_in[MemTileX][MemTileY]),
      .floo_wide_o  (floo_wide_out[MemTileX][MemTileY]),
      .floo_req_i   (floo_req_in[MemTileX][MemTileY]),
      .floo_rsp_o   (floo_rsp_out[MemTileX][MemTileY]),
      .floo_wide_i  (floo_wide_in[MemTileX][MemTileY])
    );

  end

  // ////////////////
  // // Dummy tile //
  // ////////////////

  for (genvar d = 0; d < NumDummyTiles; d++) begin : gen_dummytiles

    localparam id_t DummyTileId = DummyIdx[d];
    localparam int DummyTileX = int'(DummyIdx[d].x);
    localparam int DummyTileY = int'(DummyIdx[d].y);

    dummy_tile i_dummy_tile (
      .clk_i,
      .rst_ni,
      .test_enable_i(test_mode_i),
      .id_i         (DummyTileId),
      .floo_req_o   (floo_req_out[DummyTileX][DummyTileY]),
      .floo_rsp_i   (floo_rsp_in[DummyTileX][DummyTileY]),
      .floo_wide_o  (floo_wide_out[DummyTileX][DummyTileY]),
      .floo_req_i   (floo_req_in[DummyTileX][DummyTileY]),
      .floo_rsp_o   (floo_rsp_out[DummyTileX][DummyTileY]),
      .floo_wide_i  (floo_wide_in[DummyTileX][DummyTileY])
    );
  end

  /////////////////////
  // NoC Connections //
  /////////////////////

  for (genvar x = 0; x < MeshDim.x; x++) begin : gen_x
    for (genvar y = 0; y < MeshDim.y; y++) begin : gen_y
      for (genvar d = int'(North); d <= int'(West); d++) begin : gen_dir
        localparam route_direction_e Dir = route_direction_e'(d);
        if (is_tie_off(x, y, Dir)) begin : gen_tie_off
          assign floo_req_in[x][y][Dir]  = '0;
          assign floo_rsp_in[x][y][Dir]  = '0;
          assign floo_wide_in[x][y][Dir] = '0;
        end else begin : gen_con
          localparam int Xn = neighbor_x(x, Dir);
          localparam int Yn = neighbor_y(y, Dir);
          localparam route_direction_e Dirn = opposite_dir(Dir);
          assign floo_req_in[x][y][Dir]  = floo_req_out[Xn][Yn][Dirn];
          assign floo_rsp_in[x][y][Dir]  = floo_rsp_out[Xn][Yn][Dirn];
          assign floo_wide_in[x][y][Dir] = floo_wide_out[Xn][Yn][Dirn];
        end
      end
    end
  end

endmodule
