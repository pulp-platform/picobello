// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// AUTOMATICALLY GENERATED! DO NOT EDIT!

`include "axi/typedef.svh"
`include "floo_noc/typedef.svh"

package floo_picobello_noc_pkg;

  import floo_pkg::*;

  /////////////////////
  //   Address Map   //
  /////////////////////

  typedef enum logic [4:0] {
    ClusterX0Y0  = 0,
    ClusterX0Y1  = 1,
    ClusterX0Y2  = 2,
    ClusterX0Y3  = 3,
    ClusterX1Y0  = 4,
    ClusterX1Y1  = 5,
    ClusterX1Y2  = 6,
    ClusterX1Y3  = 7,
    ClusterX2Y0  = 8,
    ClusterX2Y1  = 9,
    ClusterX2Y2  = 10,
    ClusterX2Y3  = 11,
    ClusterX3Y0  = 12,
    ClusterX3Y1  = 13,
    ClusterX3Y2  = 14,
    ClusterX3Y3  = 15,
    Cheshire     = 16,
    FhgSpu       = 17,
    TopSpmNarrow = 18,
    TopSpmWide   = 19,
    L2Spm0       = 20,
    L2Spm1       = 21,
    L2Spm2       = 22,
    L2Spm3       = 23,
    L2Spm4       = 24,
    L2Spm5       = 25,
    L2Spm6       = 26,
    L2Spm7       = 27,
    NumEndpoints = 28
  } ep_id_e;



  typedef enum logic [4:0] {
    ClusterX0Y0SamIdx      = 0,
    ClusterX0Y1SamIdx      = 1,
    ClusterX0Y2SamIdx      = 2,
    ClusterX0Y3SamIdx      = 3,
    ClusterX1Y0SamIdx      = 4,
    ClusterX1Y1SamIdx      = 5,
    ClusterX1Y2SamIdx      = 6,
    ClusterX1Y3SamIdx      = 7,
    ClusterX2Y0SamIdx      = 8,
    ClusterX2Y1SamIdx      = 9,
    ClusterX2Y2SamIdx      = 10,
    ClusterX2Y3SamIdx      = 11,
    ClusterX3Y0SamIdx      = 12,
    ClusterX3Y1SamIdx      = 13,
    ClusterX3Y2SamIdx      = 14,
    ClusterX3Y3SamIdx      = 15,
    CheshireExternalSamIdx = 16,
    CheshireInternalSamIdx = 17,
    FhgSpuSamIdx           = 18,
    TopSpmNarrowSamIdx     = 19,
    TopSpmWideSamIdx       = 20,
    L2Spm0SamIdx           = 21,
    L2Spm1SamIdx           = 22,
    L2Spm2SamIdx           = 23,
    L2Spm3SamIdx           = 24,
    L2Spm4SamIdx           = 25,
    L2Spm5SamIdx           = 26,
    L2Spm6SamIdx           = 27,
    L2Spm7SamIdx           = 28
  } sam_idx_e;



  typedef logic [0:0] rob_idx_t;
  typedef logic [0:0] port_id_t;
  typedef logic [3:0] x_bits_t;
  typedef logic [1:0] y_bits_t;
  typedef struct packed {
    x_bits_t  x;
    y_bits_t  y;
    port_id_t port_id;
  } id_t;

  typedef logic route_t;


  localparam int unsigned SamNumRules = 29;

  typedef struct packed {
    id_t         idx;
    logic [47:0] start_addr;
    logic [47:0] end_addr;
  } sam_rule_t;

  localparam sam_rule_t [SamNumRules-1:0] Sam = '{
      '{
          idx: '{x: 8, y: 3, port_id: 0},
          start_addr: 48'h000070700000,
          end_addr: 48'h000070800000
      },  // L2Spm7
      '{
          idx: '{x: 8, y: 2, port_id: 0},
          start_addr: 48'h000070600000,
          end_addr: 48'h000070700000
      },  // L2Spm6
      '{
          idx: '{x: 8, y: 1, port_id: 0},
          start_addr: 48'h000070500000,
          end_addr: 48'h000070600000
      },  // L2Spm5
      '{
          idx: '{x: 8, y: 0, port_id: 0},
          start_addr: 48'h000070400000,
          end_addr: 48'h000070500000
      },  // L2Spm4
      '{
          idx: '{x: 0, y: 3, port_id: 0},
          start_addr: 48'h000070300000,
          end_addr: 48'h000070400000
      },  // L2Spm3
      '{
          idx: '{x: 0, y: 2, port_id: 0},
          start_addr: 48'h000070200000,
          end_addr: 48'h000070300000
      },  // L2Spm2
      '{
          idx: '{x: 0, y: 1, port_id: 0},
          start_addr: 48'h000070100000,
          end_addr: 48'h000070200000
      },  // L2Spm1
      '{
          idx: '{x: 0, y: 0, port_id: 0},
          start_addr: 48'h000070000000,
          end_addr: 48'h000070100000
      },  // L2Spm0
      '{
          idx: '{x: 9, y: 1, port_id: 0},
          start_addr: 48'h000060040000,
          end_addr: 48'h000060080000
      },  // TopSpmWide
      '{
          idx: '{x: 9, y: 2, port_id: 0},
          start_addr: 48'h000060000000,
          end_addr: 48'h000060040000
      },  // TopSpmNarrow
      '{
          idx: '{x: 9, y: 0, port_id: 0},
          start_addr: 48'h000040000000,
          end_addr: 48'h000040040000
      },  // FhgSpu
      '{
          idx: '{x: 9, y: 3, port_id: 0},
          start_addr: 48'h000000000000,
          end_addr: 48'h000020000000
      },  // CheshireInternal
      '{
          idx: '{x: 9, y: 3, port_id: 0},
          start_addr: 48'h000080000000,
          end_addr: 48'h020000000000
      },  // CheshireExternal
      '{
          idx: '{x: 7, y: 3, port_id: 0},
          start_addr: 48'h0000203c0000,
          end_addr: 48'h000020400000
      },  // ClusterX3Y3
      '{
          idx: '{x: 7, y: 2, port_id: 0},
          start_addr: 48'h000020380000,
          end_addr: 48'h0000203c0000
      },  // ClusterX3Y2
      '{
          idx: '{x: 7, y: 1, port_id: 0},
          start_addr: 48'h000020340000,
          end_addr: 48'h000020380000
      },  // ClusterX3Y1
      '{
          idx: '{x: 7, y: 0, port_id: 0},
          start_addr: 48'h000020300000,
          end_addr: 48'h000020340000
      },  // ClusterX3Y0
      '{
          idx: '{x: 6, y: 3, port_id: 0},
          start_addr: 48'h0000202c0000,
          end_addr: 48'h000020300000
      },  // ClusterX2Y3
      '{
          idx: '{x: 6, y: 2, port_id: 0},
          start_addr: 48'h000020280000,
          end_addr: 48'h0000202c0000
      },  // ClusterX2Y2
      '{
          idx: '{x: 6, y: 1, port_id: 0},
          start_addr: 48'h000020240000,
          end_addr: 48'h000020280000
      },  // ClusterX2Y1
      '{
          idx: '{x: 6, y: 0, port_id: 0},
          start_addr: 48'h000020200000,
          end_addr: 48'h000020240000
      },  // ClusterX2Y0
      '{
          idx: '{x: 5, y: 3, port_id: 0},
          start_addr: 48'h0000201c0000,
          end_addr: 48'h000020200000
      },  // ClusterX1Y3
      '{
          idx: '{x: 5, y: 2, port_id: 0},
          start_addr: 48'h000020180000,
          end_addr: 48'h0000201c0000
      },  // ClusterX1Y2
      '{
          idx: '{x: 5, y: 1, port_id: 0},
          start_addr: 48'h000020140000,
          end_addr: 48'h000020180000
      },  // ClusterX1Y1
      '{
          idx: '{x: 5, y: 0, port_id: 0},
          start_addr: 48'h000020100000,
          end_addr: 48'h000020140000
      },  // ClusterX1Y0
      '{
          idx: '{x: 4, y: 3, port_id: 0},
          start_addr: 48'h0000200c0000,
          end_addr: 48'h000020100000
      },  // ClusterX0Y3
      '{
          idx: '{x: 4, y: 2, port_id: 0},
          start_addr: 48'h000020080000,
          end_addr: 48'h0000200c0000
      },  // ClusterX0Y2
      '{
          idx: '{x: 4, y: 1, port_id: 0},
          start_addr: 48'h000020040000,
          end_addr: 48'h000020080000
      },  // ClusterX0Y1
      '{
          idx: '{x: 4, y: 0, port_id: 0},
          start_addr: 48'h000020000000,
          end_addr: 48'h000020040000
      }  // ClusterX0Y0

  };



  localparam route_cfg_t RouteCfg = '{
      RouteAlgo: XYRouting,
      UseIdTable: 1'b1,
      XYAddrOffsetX: 41,
      XYAddrOffsetY: 45,
      IdAddrOffset: 0,
      NumSamRules: 29,
      NumRoutes: 0,
      EnMultiCast: 1'b1,
      EnParallelReduction: 1'b1,
      EnNarrowOffloadReduction: 1'b1,
      EnWideOffloadReduction: 1'b1,
      CollectiveCfg: '{
        OpCfg: '{
            EnNarrowMulticast:  1'b1,
            EnWideMulticast:    1'b1,
            EnLSBAnd:           1'b1,
            default:            '0
        },
        SequentialRedCfg: ReductionDefaultCfg
      }
  };


  typedef logic [47:0] axi_narrow_in_addr_t;
  typedef logic [63:0] axi_narrow_in_data_t;
  typedef logic [7:0] axi_narrow_in_strb_t;
  typedef logic [4:0] axi_narrow_in_id_t;
  typedef logic [4:0] axi_narrow_in_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_narrow_in, axi_narrow_in_req_t, axi_narrow_in_rsp_t, axi_narrow_in_addr_t,
                      axi_narrow_in_id_t, axi_narrow_in_data_t, axi_narrow_in_strb_t,
                      axi_narrow_in_user_t)


  typedef logic [47:0] axi_narrow_out_addr_t;
  typedef logic [63:0] axi_narrow_out_data_t;
  typedef logic [7:0] axi_narrow_out_strb_t;
  typedef logic [1:0] axi_narrow_out_id_t;
  typedef logic [4:0] axi_narrow_out_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_narrow_out, axi_narrow_out_req_t, axi_narrow_out_rsp_t,
                      axi_narrow_out_addr_t, axi_narrow_out_id_t, axi_narrow_out_data_t,
                      axi_narrow_out_strb_t, axi_narrow_out_user_t)


  typedef logic [47:0] axi_wide_in_addr_t;
  typedef logic [511:0] axi_wide_in_data_t;
  typedef logic [63:0] axi_wide_in_strb_t;
  typedef logic [2:0] axi_wide_in_id_t;
  typedef logic [0:0] axi_wide_in_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_wide_in, axi_wide_in_req_t, axi_wide_in_rsp_t, axi_wide_in_addr_t,
                      axi_wide_in_id_t, axi_wide_in_data_t, axi_wide_in_strb_t, axi_wide_in_user_t)


  typedef logic [47:0] axi_wide_out_addr_t;
  typedef logic [511:0] axi_wide_out_data_t;
  typedef logic [63:0] axi_wide_out_strb_t;
  typedef logic [0:0] axi_wide_out_id_t;
  typedef logic [0:0] axi_wide_out_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_wide_out, axi_wide_out_req_t, axi_wide_out_rsp_t, axi_wide_out_addr_t,
                      axi_wide_out_id_t, axi_wide_out_data_t, axi_wide_out_strb_t,
                      axi_wide_out_user_t)



  `FLOO_TYPEDEF_HDR_T(hdr_t, id_t, id_t, nw_ch_e, rob_idx_t, id_t, collect_op_e)
  localparam axi_cfg_t AxiCfgN = '{
      AddrWidth: 48,
      DataWidth: 64,
      UserWidth: 5,
      InIdWidth: 5,
      OutIdWidth: 2
  };
  localparam axi_cfg_t AxiCfgW = '{
      AddrWidth: 48,
      DataWidth: 512,
      UserWidth: 1,
      InIdWidth: 3,
      OutIdWidth: 1
  };
  `FLOO_TYPEDEF_NW_CHAN_ALL(axi, req, rsp, wide, axi_narrow_in, axi_wide_in, AxiCfgN, AxiCfgW,
                            hdr_t)

  `FLOO_TYPEDEF_NW_VIRT_CHAN_LINK_ALL(req, rsp, wide, req, rsp, wide, 1, 2)


endpackage
