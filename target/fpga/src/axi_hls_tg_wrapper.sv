// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"

module axi_hls_tg_wrapper #(
  parameter int unsigned  AXI_ADDR_WIDTH = 64,
  parameter int unsigned  AXI_DATA_WIDTH = 64,
  parameter int unsigned  AXI_ID_WIDTH = 1,
  parameter int unsigned  AXI_USER_WIDTH = 1,
  parameter int unsigned  AXI_LOCK = 1,
  parameter int unsigned  AXI_LITE_ADDR_WIDTH = 32,
  parameter int unsigned  AXI_LITE_DATA_WIDTH = 32
) (
    input logic             clk_i,
    input logic             rst_ni,
    // AXI4 narrow
    output floo_picobello_noc_pkg::axi_narrow_out_req_t     axi_tg_narrow_out_req,
    input floo_picobello_noc_pkg::axi_narrow_out_rsp_t      axi_tg_narrow_out_rsp,
    // AXI4 wide
    output floo_picobello_noc_pkg::axi_wide_out_req_t       axi_tg_wide_out_req,
    input floo_picobello_noc_pkg::axi_wide_out_rsp_t        axi_tg_wide_out_rsp,
    // AXI4-Lite program
    AXI_LITE.Slave          axi_lite_tg_cfg
);

    axi_hls_tg #(
        // AXI4 narrow
        .C_M_AXI_NARROW_PORT_ID_WIDTH           (AXI_ID_WIDTH),
        .C_M_AXI_NARROW_PORT_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .C_M_AXI_NARROW_PORT_DATA_WIDTH         (AXI_DATA_WIDTH),
        .C_M_AXI_NARROW_PORT_AWUSER_WIDTH       (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_ARUSER_WIDTH       (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_WUSER_WIDTH        (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_RUSER_WIDTH        (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_BUSER_WIDTH        (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_USER_VALUE         (AXI_USER_WIDTH),
        .C_M_AXI_NARROW_PORT_PROT_VALUE         (0),
        .C_M_AXI_NARROW_PORT_CACHE_VALUE        (3),
        // AXI4 wide
        .C_M_AXI_WIDE_PORT_ID_WIDTH             (AXI_ID_WIDTH),
        .C_M_AXI_WIDE_PORT_ADDR_WIDTH           (AXI_ADDR_WIDTH),
        .C_M_AXI_WIDE_PORT_DATA_WIDTH           (AXI_DATA_WIDTH),
        .C_M_AXI_WIDE_PORT_AWUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_ARUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_WUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_RUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_BUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_USER_VALUE           (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_PROT_VALUE           (0),
        .C_M_AXI_WIDE_PORT_CACHE_VALUE          (3),
        //
        .C_M_AXI_DATA_WIDTH                     (AXI_DATA_WIDTH),
        .C_M_AXI_LOCK                           (AXI_LOCK),
        // AXI4-Lite control
        .C_S_AXI_CONTROL_DATA_WIDTH             (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_DATA_WIDTH                     (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_CONTROL_ADDR_WIDTH             (AXI_LITE_ADDR_WIDTH)
    ) i_axi_hls_tg (
        .ap_clk                     ( clk_i                             ),
        .ap_rst_n                   ( rst_ni                            ),
        // AXI4 narrow
        .m_axi_narrow_port_AWVALID  ( axi_tg_narrow_out_req.aw_valid    ),
        .m_axi_narrow_port_AWREADY  ( axi_tg_narrow_out_rsp.aw_ready    ),
        .m_axi_narrow_port_AWADDR   ( axi_tg_narrow_out_req.aw.addr     ),
        .m_axi_narrow_port_AWID     ( axi_tg_narrow_out_req.aw.id       ),
        .m_axi_narrow_port_AWLEN    ( axi_tg_narrow_out_req.aw.len      ),
        .m_axi_narrow_port_AWSIZE   ( axi_tg_narrow_out_req.aw.size     ),
        .m_axi_narrow_port_AWBURST  ( axi_tg_narrow_out_req.aw.burst    ),
        .m_axi_narrow_port_AWLOCK   ( axi_tg_narrow_out_req.aw.lock     ),
        .m_axi_narrow_port_AWCACHE  ( axi_tg_narrow_out_req.aw.cache    ),
        .m_axi_narrow_port_AWPROT   ( axi_tg_narrow_out_req.aw.prot     ),
        .m_axi_narrow_port_AWQOS    ( axi_tg_narrow_out_req.aw.qos      ),
        .m_axi_narrow_port_AWREGION ( axi_tg_narrow_out_req.aw.region   ),
        .m_axi_narrow_port_AWUSER   ( axi_tg_narrow_out_req.aw.user     ),
        .m_axi_narrow_port_WVALID   ( axi_tg_narrow_out_req.w_valid     ),
        .m_axi_narrow_port_WREADY   ( axi_tg_narrow_out_rsp.w_ready     ),
        .m_axi_narrow_port_WDATA    ( axi_tg_narrow_out_req.w.data      ),
        .m_axi_narrow_port_WSTRB    ( axi_tg_narrow_out_req.w.strb      ),
        .m_axi_narrow_port_WLAST    ( axi_tg_narrow_out_req.w.last      ),
        .m_axi_narrow_port_WID      (                                        ),
        .m_axi_narrow_port_WUSER    ( axi_tg_narrow_out_req.w.user      ),
        .m_axi_narrow_port_ARVALID  ( axi_tg_narrow_out_req.ar_valid    ),
        .m_axi_narrow_port_ARREADY  ( axi_tg_narrow_out_rsp.ar_ready    ),
        .m_axi_narrow_port_ARADDR   ( axi_tg_narrow_out_req.ar.addr     ),
        .m_axi_narrow_port_ARID     ( axi_tg_narrow_out_req.ar.id       ),
        .m_axi_narrow_port_ARLEN    ( axi_tg_narrow_out_req.ar.len      ),
        .m_axi_narrow_port_ARSIZE   ( axi_tg_narrow_out_req.ar.size     ),
        .m_axi_narrow_port_ARBURST  ( axi_tg_narrow_out_req.ar.burst    ),
        .m_axi_narrow_port_ARLOCK   ( axi_tg_narrow_out_req.ar.lock     ),
        .m_axi_narrow_port_ARCACHE  ( axi_tg_narrow_out_req.ar.cache    ),
        .m_axi_narrow_port_ARPROT   ( axi_tg_narrow_out_req.ar.prot     ),
        .m_axi_narrow_port_ARQOS    ( axi_tg_narrow_out_req.ar.qos      ),
        .m_axi_narrow_port_ARREGION ( axi_tg_narrow_out_req.ar.region   ),
        .m_axi_narrow_port_ARUSER   ( axi_tg_narrow_out_req.ar.user     ),
        .m_axi_narrow_port_RVALID   ( axi_tg_narrow_out_rsp.r_valid     ),
        .m_axi_narrow_port_RREADY   ( axi_tg_narrow_out_req.r_ready     ),
        .m_axi_narrow_port_RDATA    ( axi_tg_narrow_out_rsp.r.data      ),
        .m_axi_narrow_port_RLAST    ( axi_tg_narrow_out_rsp.r.last      ),
        .m_axi_narrow_port_RID      ( axi_tg_narrow_out_rsp.r.id        ),
        .m_axi_narrow_port_RUSER    ( axi_tg_narrow_out_rsp.r.user      ),
        .m_axi_narrow_port_RRESP    ( axi_tg_narrow_out_rsp.r.resp      ),
        .m_axi_narrow_port_BVALID   ( axi_tg_narrow_out_rsp.b_valid     ),
        .m_axi_narrow_port_BREADY   ( axi_tg_narrow_out_req.b_ready     ),
        .m_axi_narrow_port_BRESP    ( axi_tg_narrow_out_rsp.b.resp      ),
        .m_axi_narrow_port_BID      ( axi_tg_narrow_out_rsp.b.id        ),
        .m_axi_narrow_port_BUSER    ( axi_tg_narrow_out_rsp.b.user      ),
        // AXI4 wide
        .m_axi_wide_port_AWVALID    ( axi_tg_wide_out_req.aw_valid      ),
        .m_axi_wide_port_AWREADY    ( axi_tg_wide_out_rsp.aw_ready      ),
        .m_axi_wide_port_AWADDR     ( axi_tg_wide_out_req.aw.addr       ),
        .m_axi_wide_port_AWID       ( axi_tg_wide_out_req.aw.id         ),
        .m_axi_wide_port_AWLEN      ( axi_tg_wide_out_req.aw.len        ),
        .m_axi_wide_port_AWSIZE     ( axi_tg_wide_out_req.aw.size       ),
        .m_axi_wide_port_AWBURST    ( axi_tg_wide_out_req.aw.burst      ),
        .m_axi_wide_port_AWLOCK     ( axi_tg_wide_out_req.aw.lock       ),
        .m_axi_wide_port_AWCACHE    ( axi_tg_wide_out_req.aw.cache      ),
        .m_axi_wide_port_AWPROT     ( axi_tg_wide_out_req.aw.prot       ),
        .m_axi_wide_port_AWQOS      ( axi_tg_wide_out_req.aw.qos        ),
        .m_axi_wide_port_AWREGION   ( axi_tg_wide_out_req.aw.region     ),
        .m_axi_wide_port_AWUSER     ( axi_tg_wide_out_req.aw.user       ),
        .m_axi_wide_port_WVALID     ( axi_tg_wide_out_req.w_valid       ),
        .m_axi_wide_port_WREADY     ( axi_tg_wide_out_rsp.w_ready       ),
        .m_axi_wide_port_WDATA      ( axi_tg_wide_out_req.w.data        ),
        .m_axi_wide_port_WSTRB      ( axi_tg_wide_out_req.w.strb        ),
        .m_axi_wide_port_WLAST      ( axi_tg_wide_out_req.w.last        ),
        .m_axi_wide_port_WID        (                                        ),
        .m_axi_wide_port_WUSER      ( axi_tg_wide_out_req.w.user        ),
        .m_axi_wide_port_ARVALID    ( axi_tg_wide_out_req.ar_valid      ),
        .m_axi_wide_port_ARREADY    ( axi_tg_wide_out_rsp.ar_ready      ),
        .m_axi_wide_port_ARADDR     ( axi_tg_wide_out_req.ar.addr       ),
        .m_axi_wide_port_ARID       ( axi_tg_wide_out_req.ar.id         ),
        .m_axi_wide_port_ARLEN      ( axi_tg_wide_out_req.ar.len        ),
        .m_axi_wide_port_ARSIZE     ( axi_tg_wide_out_req.ar.size       ),
        .m_axi_wide_port_ARBURST    ( axi_tg_wide_out_req.ar.burst      ),
        .m_axi_wide_port_ARLOCK     ( axi_tg_wide_out_req.ar.lock       ),
        .m_axi_wide_port_ARCACHE    ( axi_tg_wide_out_req.ar.cache      ),
        .m_axi_wide_port_ARPROT     ( axi_tg_wide_out_req.ar.prot       ),
        .m_axi_wide_port_ARQOS      ( axi_tg_wide_out_req.ar.qos        ),
        .m_axi_wide_port_ARREGION   ( axi_tg_wide_out_req.ar.region     ),
        .m_axi_wide_port_ARUSER     ( axi_tg_wide_out_req.ar.user       ),
        .m_axi_wide_port_RVALID     ( axi_tg_wide_out_rsp.r_valid       ),
        .m_axi_wide_port_RREADY     ( axi_tg_wide_out_req.r_ready       ),
        .m_axi_wide_port_RDATA      ( axi_tg_wide_out_rsp.r.data        ),
        .m_axi_wide_port_RLAST      ( axi_tg_wide_out_rsp.r.last        ),
        .m_axi_wide_port_RID        ( axi_tg_wide_out_rsp.r.id          ),
        .m_axi_wide_port_RUSER      ( axi_tg_wide_out_rsp.r.user        ),
        .m_axi_wide_port_RRESP      ( axi_tg_wide_out_rsp.r.resp        ),
        .m_axi_wide_port_BVALID     ( axi_tg_wide_out_rsp.b_valid       ),
        .m_axi_wide_port_BREADY     ( axi_tg_wide_out_req.b_ready       ),
        .m_axi_wide_port_BRESP      ( axi_tg_wide_out_rsp.b.resp        ),
        .m_axi_wide_port_BID        ( axi_tg_wide_out_rsp.b.id          ),
        .m_axi_wide_port_BUSER      ( axi_tg_wide_out_rsp.b.user        ),
        // AXI4-Lite control
        .s_axi_control_AWVALID      ( axi_lite_tg_cfg.aw_valid          ),
        .s_axi_control_AWREADY      ( axi_lite_tg_cfg.aw_ready          ),
        .s_axi_control_AWADDR       ( axi_lite_tg_cfg.aw_addr           ),
        .s_axi_control_WVALID       ( axi_lite_tg_cfg.w_valid           ),
        .s_axi_control_WREADY       ( axi_lite_tg_cfg.w_ready           ),
        .s_axi_control_WDATA        ( axi_lite_tg_cfg.w_data            ),
        .s_axi_control_WSTRB        ( axi_lite_tg_cfg.w_strb            ),
        .s_axi_control_ARVALID      ( axi_lite_tg_cfg.ar_valid          ),
        .s_axi_control_ARREADY      ( axi_lite_tg_cfg.ar_ready          ),
        .s_axi_control_ARADDR       ( axi_lite_tg_cfg.ar_addr           ),
        .s_axi_control_RVALID       ( axi_lite_tg_cfg.r_valid           ),
        .s_axi_control_RREADY       ( axi_lite_tg_cfg.r_ready           ),
        .s_axi_control_RDATA        ( axi_lite_tg_cfg.r_data            ),
        .s_axi_control_RRESP        ( axi_lite_tg_cfg.r_resp            ),
        .s_axi_control_BVALID       ( axi_lite_tg_cfg.b_valid           ),
        .s_axi_control_BREADY       ( axi_lite_tg_cfg.b_ready           ),
        .s_axi_control_BRESP        ( axi_lite_tg_cfg.b_resp            ),
        // Interrupt
        .interrupt                  (                                   )
    );

    // Signals not handled by HLS
    assign axi_tg_narrow_out_req.aw.atop = axi_pkg::ATOP_NONE;
    assign axi_tg_wide_out_req.aw.atop = axi_pkg::ATOP_NONE;

endmodule
