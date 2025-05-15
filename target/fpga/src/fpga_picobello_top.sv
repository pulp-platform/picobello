// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/typedef.svh"
`include "axi/assign.svh"

module fpga_picobello_top 
  import picobello_pkg::*; 
  import floo_pkg::*; 
  import floo_picobello_noc_pkg::*; #(
  parameter int unsigned NumTrafficGenerators = NumClusters + 1
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_mode_i,
  // Host control port
  input  axi_narrow_in_req_t axi_host_req_i,
  output axi_narrow_in_rsp_t axi_host_rsp_o
  // AXI_BUS.Slave host_tg_progr
);
  ///////////////////////////////
  // Parameters and Interfaces //
  ///////////////////////////////

  // Address map - TG regfiles
  sam_rule_t [NumTrafficGenerators-1:0] host_tg_addr_map;

  // AXI4 interfaces - TG regfiles
  axi_narrow_in_req_t axi_tg_cfg_req_i[NumTrafficGenerators-1:0];
  axi_narrow_in_rsp_t axi_tg_cfg_rsp_o[NumTrafficGenerators-1:0];

  // AXI4 interfaces - TG regfiles
  axi_narrow_in_req_t axi_tg_cfg_req_i_downsized[NumTrafficGenerators-1:0];
  axi_narrow_in_rsp_t axi_tg_cfg_rsp_o_downsized[NumTrafficGenerators-1:0];

  // AXI4-Lite interfaces - TG regfiles
  localparam int unsigned AxiLiteAddrWidth = 32;
  localparam int unsigned AxiLiteDataWidth = 32;

  typedef logic [AxiLiteAddrWidth-1:0] axi_lite_in_addr_t;
  typedef logic [AxiLiteAddrWidth-1:0] axi_lite_in_data_t;
  typedef logic [AxiLiteDataWidth/8-1:0] axi_lite_in_strb_t;
  `AXI_LITE_TYPEDEF_ALL_CT(axi_lite_in, axi_lite_in_req_t, axi_lite_in_rsp_t, 
                           axi_lite_in_addr_t, axi_lite_in_data_t, axi_lite_in_strb_t)

  axi_lite_in_req_t axi_lite_tg_cfg_req_i[NumTrafficGenerators-1:0];
  axi_lite_in_rsp_t axi_lite_tg_cfg_rsp_o[NumTrafficGenerators-1:0];

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteAddrWidth),
    .AXI_DATA_WIDTH (AxiLiteDataWidth)
  ) axi_lite_tg_cfg[NumTrafficGenerators-1:0]();

  // NoC interfaces
  floo_req_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_req_in, floo_req_out;
  floo_rsp_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_rsp_in, floo_rsp_out;
  floo_wide_t [MeshDim.x-1:0][MeshDim.y-1:0][West:North] floo_wide_in, floo_wide_out;

  /////////////////////////////
  // Host-to-TG interconnect //
  /////////////////////////////

  localparam axi_pkg::xbar_cfg_t PicobelloHostXbarCfg = '{
    NoSlvPorts:         1,
    NoMstPorts:         NumTrafficGenerators,
    MaxMstTrans:        4,
    MaxSlvTrans:        4,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: AxiCfgN.InIdWidth,
    AxiIdUsedSlvPorts:  AxiCfgN.InIdWidth,
    UniqueIds:          0,
    AxiAddrWidth:       AxiCfgN.AddrWidth,
    AxiDataWidth:       AxiCfgN.DataWidth,
    NoAddrRules:        NumTrafficGenerators
  };

  for (genvar i = 0; i < NumTrafficGenerators; i++) begin : gen_addr_map_tg
    assign host_tg_addr_map[1+i] = '{
      idx:        '{x: 0, y: 0, port_id: i},
      start_addr: 64'h0000_0000_1000_0000 + i * 32'h0002_0000,
      end_addr:   64'h0000_0000_1000_0000 + i * 32'h0002_0000 + 32'h0001_FFFF
    };
  end

  axi_xbar #(
    .Cfg            (PicobelloHostXbarCfg),
    .ATOPs          (1'b1),
    .Connectivity   ('1),
    .slv_aw_chan_t  (axi_narrow_in_aw_chan_t),
    .mst_aw_chan_t  (axi_narrow_in_aw_chan_t),
    .w_chan_t       (axi_narrow_in_w_chan_t),
    .slv_b_chan_t   (axi_narrow_in_b_chan_t),
    .mst_b_chan_t   (axi_narrow_in_b_chan_t),
    .slv_ar_chan_t  (axi_narrow_in_ar_chan_t),
    .mst_ar_chan_t  (axi_narrow_in_ar_chan_t),
    .slv_r_chan_t   (axi_narrow_in_r_chan_t),
    .mst_r_chan_t   (axi_narrow_in_r_chan_t),
    .slv_req_t      (axi_narrow_in_req_t),
    .slv_resp_t     (axi_narrow_in_rsp_t),
    .mst_req_t      (axi_narrow_in_req_t),
    .mst_resp_t     (axi_narrow_in_rsp_t),
    .rule_t         (sam_rule_t)
  ) i_host_tg_xbar (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),
    .test_i                 (test_mode_i),
    .slv_ports_req_i        (axi_host_req_i),
    .slv_ports_resp_o       (axi_host_rsp_o),
    .mst_ports_req_o        (axi_tg_cfg_req_i),
    .mst_ports_resp_i       (axi_tg_cfg_rsp_o),
    .addr_map_i             (host_tg_addr_map),
    .en_default_mst_port_i  ('0),
    .default_mst_port_i     ('0)
  );

  for (genvar i = 0; i < NumTrafficGenerators; i++) begin : gen_tg_axi_lite

    axi_dw_converter #(
      .AxiMaxReads        (AxiCfgN.DataWidth/AxiLiteDataWidth),
      .AxiSlvPortDataWidth(AxiCfgN.DataWidth),
      .AxiMstPortDataWidth(AxiLiteDataWidth),
      .AxiAddrWidth       (AxiCfgN.AddrWidth),
      .AxiIdWidth         (AxiCfgN.InIdWidth),
      .aw_chan_t          (axi_narrow_in_aw_chan_t),
      .mst_w_chan_t       (axi_narrow_in_w_chan_t),
      .slv_w_chan_t       (axi_narrow_in_w_chan_t),
      .b_chan_t           (axi_narrow_in_b_chan_t),
      .ar_chan_t          (axi_narrow_in_ar_chan_t),
      .mst_r_chan_t       (axi_narrow_in_r_chan_t),
      .slv_r_chan_t       (axi_narrow_in_req_t    ),
      .axi_mst_req_t      (axi_narrow_in_req_t),
      .axi_mst_resp_t     (axi_narrow_in_rsp_t),
      .axi_slv_req_t      (axi_narrow_in_req_t),
      .axi_slv_resp_t     (axi_narrow_in_rsp_t)
    ) i_axi_dw_converter (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .slv_req_i  (axi_tg_cfg_req_i[i]),
      .slv_resp_o (axi_tg_cfg_rsp_o[i]),
      .mst_req_o  (axi_tg_cfg_req_i_downsized[i]),
      .mst_resp_i (axi_tg_cfg_rsp_o_downsized[i])
    );

    axi_to_axi_lite #(
      .AxiAddrWidth    (AxiCfgN.AddrWidth),
      .AxiDataWidth    (AxiCfgN.DataWidth),
      .AxiIdWidth      (AxiCfgN.InIdWidth),
      .AxiUserWidth    (AxiCfgN.UserWidth),
      .AxiMaxWriteTxns (AxiCfgN.DataWidth/AxiLiteDataWidth),
      .AxiMaxReadTxns  (AxiCfgN.DataWidth/AxiLiteDataWidth),
      .FallThrough     (1'b0),
      .FullBW          (0),
      .full_req_t      (axi_narrow_in_req_t),
      .full_resp_t     (axi_narrow_in_rsp_t),
      .lite_req_t      (axi_lite_in_req_t),
      .lite_resp_t     (axi_lite_in_rsp_t)
    ) i_axi_to_axi_lite (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .test_i     (test_mode_i),
      .slv_req_i  (axi_tg_cfg_req_i_downsized[i]),
      .slv_resp_o (axi_tg_cfg_rsp_o_downsized[i]),
      .mst_req_o  (axi_lite_tg_cfg_req_i[i]),
      .mst_resp_i (axi_lite_tg_cfg_rsp_o[i])
    );

    `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_tg_cfg[i], axi_lite_tg_cfg_req_i[i])
    `AXI_LITE_ASSIGN_TO_RESP(axi_lite_tg_cfg_rsp_o[i], axi_lite_tg_cfg[i])
  end

  //////////////////////
  // Cluster TG tiles //
  //////////////////////

  for (genvar c = 0; c < NumClusters; c++) begin : gen_clusters

    localparam int ClusterSamIdx = c + ClusterX0Y0SamIdx;
    localparam id_t ClusterId = Sam[ClusterSamIdx].idx;
    localparam int X = int'(ClusterId.x);
    localparam int Y = int'(ClusterId.y);

    traffic_gen_tile #(
      .AxiLiteAddrWidth (AxiLiteAddrWidth),
      .AxiLiteDataWidth (AxiLiteDataWidth)
    ) i_cluster_tg_tile (
      .clk_i,
      .rst_ni,
      .test_enable_i      (test_mode_i),
      .id_i               (ClusterId),
      .floo_req_o         (floo_req_out[X][Y]),
      .floo_rsp_i         (floo_rsp_in[X][Y]),
      .floo_wide_o        (floo_wide_out[X][Y]),
      .floo_req_i         (floo_req_in[X][Y]),
      .floo_rsp_o         (floo_rsp_out[X][Y]),
      .floo_wide_i        (floo_wide_in[X][Y]),
      .traffic_gen_progr  (axi_lite_tg_cfg[c])
    );
  end

  //////////////////////
  // Cheshire TG tile //
  //////////////////////

  localparam id_t CheshireId = Sam[CheshireInternalSamIdx].idx;

  traffic_gen_tile #(
    .AxiLiteAddrWidth (AxiLiteAddrWidth),
    .AxiLiteDataWidth (AxiLiteDataWidth)
  ) i_cheshire_tg_tile (
    .clk_i,
    .rst_ni,
    .test_enable_i      (test_mode_i),
    .id_i               (CheshireId),
    .floo_req_o         (floo_req_out[CheshireId.x][CheshireId.y]),
    .floo_rsp_i         (floo_rsp_in[CheshireId.x][CheshireId.y]),
    .floo_wide_o        (floo_wide_out[CheshireId.x][CheshireId.y]),
    .floo_req_i         (floo_req_in[CheshireId.x][CheshireId.y]),
    .floo_rsp_o         (floo_rsp_out[CheshireId.x][CheshireId.y]),
    .floo_wide_i        (floo_wide_in[CheshireId.x][CheshireId.y]),
    .traffic_gen_progr  (axi_lite_tg_cfg[NumClusters])
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

  ////////////////
  // Dummy tile //
  ////////////////

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
