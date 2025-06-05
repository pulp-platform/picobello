// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

package fpga_picobello_pkg;
  import picobello_pkg::*; 
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;

  // SoC parameters
  localparam int unsigned NumFpgaHostPorts = 1;
  localparam int unsigned NumFpgaDummyTiles = 2;
  localparam int unsigned NumTrafficGenerators = picobello_pkg::NumClusters + 1; // Snitch clusters and FhG SPU

  // Host AXI4 parameters and typedefs
  localparam int unsigned HostAxiAddrWidth = 64;
  localparam int unsigned HostAxiDataWidth = 64;
  localparam int unsigned HostAxiUserWidth = 4;
  localparam int unsigned HostAxiIdWidth = 3;

  // Host AXI4-Lite parameters and typedefs
  localparam int unsigned HostAxiLiteAddrWidth = 32;
  localparam int unsigned HostAxiLiteDataWidth = 32;

  // AXI4 typedefs
  typedef logic [HostAxiAddrWidth-1:0] axi_host_addr_t;
  typedef logic [HostAxiDataWidth-1:0] axi_host_data_t;
  typedef logic [HostAxiDataWidth/8-1:0] axi_host_strb_t;
  typedef logic [HostAxiIdWidth-1:0] axi_host_id_t;
  typedef logic [HostAxiUserWidth-1:0] axi_host_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_host, axi_host_req_t, axi_host_rsp_t, axi_host_addr_t,
                      axi_host_id_t, axi_host_data_t, axi_host_strb_t,
                      axi_host_user_t)

  // AXI4-Lite typedefs
  typedef logic [HostAxiLiteAddrWidth-1:0] axi_lite_host_addr_t;
  typedef logic [HostAxiLiteAddrWidth-1:0] axi_lite_host_data_t;
  typedef logic [HostAxiLiteDataWidth/8-1:0] axi_lite_host_strb_t;
  `AXI_LITE_TYPEDEF_ALL_CT(axi_lite_host, axi_lite_host_req_t, axi_lite_host_rsp_t, 
                           axi_lite_host_addr_t, axi_lite_host_data_t, axi_lite_host_strb_t)

  // Traffic generator configuration struct
  typedef struct packed {
    // Port IDs
    logic [3:0] traffic_gen_port_id;
    logic [3:0] mem_port_id;
    // Addresses
  	axi_host_addr_t traffic_gen_addr_base; // Traffic generator base address
    axi_host_addr_t mem_addr_base; // Memory base address
    // Traffic generator parameters
    axi_host_data_t TrafficGenTrafficDim; // Traffic dimension
    axi_host_data_t TrafficGenComputeDim; // Compute dimension
    axi_host_data_t TrafficGenIdx; // Index
  } tg_cfg_t;

endpackage
