// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define wait_for(signal) do @(posedge clk); while (!signal);

// `define VERBOSE

module tb_picobello_fpga;

  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  // SoC parameters
  localparam int unsigned NumHostPorts = 1;
  localparam int unsigned NumTrafficGenerators = picobello_pkg::NumClusters + 2; // Snitch clusters, Cheshire and FhG SPU

  // Host AXI4 parameters and typedefs
  localparam int unsigned HostAxiAddrWidth = 64;
  localparam int unsigned HostAxiDataWidth = 32;
  localparam int unsigned HostAxiUserWidth = 1;
  localparam int unsigned HostAxiIdWidth = 1;

  typedef logic [HostAxiAddrWidth-1:0] axi_host_addr_t;
  typedef logic [HostAxiDataWidth-1:0] axi_host_data_t;
  typedef logic [HostAxiDataWidth/8-1:0] axi_host_strb_t;
  typedef logic [HostAxiIdWidth-1:0] axi_host_id_t;
  typedef logic [HostAxiUserWidth-1:0] axi_host_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_host, axi_host_req_t, axi_host_rsp_t, axi_host_addr_t,
                      axi_host_id_t, axi_host_data_t, axi_host_strb_t,
                      axi_host_user_t)

  // Host AXI4-Lite parameters and typedefs
  localparam int unsigned HostAxiLiteAddrWidth = 32;
  localparam int unsigned HostAxiLiteDataWidth = 32;
  
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
    axi_host_data_t TrafficGenTrafficDim; // Traffic dimension - TO-DO: set value as HLS TB
    axi_host_data_t TrafficGenComputeDim; // Compute dimension - TO-DO: set value as HLS TB
    axi_host_data_t TrafficGenIdx; // Index - TO-DO: set value as HLS TB
  } tg_cfg_t;

  tg_cfg_t tb_tg_cfg;

  // Host signals
  axi_host_req_t tb_axi_host_req_i;
  axi_host_rsp_t tb_axi_host_rsp_o;

  // TB signals
  axi_host_addr_t tb_addr; // Read payload
  axi_host_data_t tb_read_data; // Read payload
  axi_host_data_t tb_write_data; // Write payload
  axi_host_rsp_t tb_rsp; // Transaction response

  // General
  logic clk;
  logic rst_n;
  logic test_mode;

  // DUT
  fpga_picobello_top #(
    // Parameters
    .NumHostPorts (NumHostPorts),      
    .NumTrafficGenerators (NumTrafficGenerators),
    .HostAxiAddrWidth (HostAxiAddrWidth),
    .HostAxiDataWidth (HostAxiDataWidth),
    .HostAxiUserWidth (HostAxiUserWidth),
    .HostAxiIdWidth (HostAxiIdWidth),
    .HostAxiLiteAddrWidth (HostAxiLiteAddrWidth),
    .HostAxiLiteDataWidth (HostAxiLiteDataWidth),
    // AXI4 channel types
    .axi_host_req_t (axi_host_req_t),
    .axi_host_rsp_t (axi_host_rsp_t),
    .axi_host_aw_chan_t (axi_host_aw_chan_t),
    .axi_host_w_chan_t (axi_host_w_chan_t),
    .axi_host_b_chan_t (axi_host_b_chan_t),
    .axi_host_ar_chan_t (axi_host_ar_chan_t),
    .axi_host_r_chan_t (axi_host_r_chan_t),
    // AXI4-Lite channel types
    .axi_lite_host_req_t (axi_lite_host_req_t),
    .axi_lite_host_rsp_t (axi_lite_host_rsp_t),
    .axi_lite_host_aw_chan_t (axi_lite_host_aw_chan_t),
    .axi_lite_host_w_chan_t (axi_lite_host_w_chan_t),
    .axi_lite_host_b_chan_t (axi_lite_host_b_chan_t),
    .axi_lite_host_ar_chan_t (axi_lite_host_ar_chan_t),
    .axi_lite_host_r_chan_t (axi_lite_host_r_chan_t)
  ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),
    .test_mode_i          (test_mode),
    .axi_host_req_i       (tb_axi_host_req_i),
    .axi_host_rsp_o       (tb_axi_host_rsp_o)
  );

  clk_rst_gen #(
    .ClkPeriod        (1ns),
    .RstClkCycles     (10)
  ) i_clk_gen (
    .clk_o            (clk),
    .rst_no           (rst_n)
  );

  // Write to Picobello
  task automatic picobello_write(
    input axi_host_addr_t write_addr, 
    input axi_host_data_t write_data, 
    output axi_host_rsp_t write_rsp
  );
    tb_axi_host_req_i.aw.id = '0;
    tb_axi_host_req_i.aw.addr = write_addr;
    tb_axi_host_req_i.aw.len = '0;
    tb_axi_host_req_i.aw.size = $clog2(HostAxiDataWidth/8);
    tb_axi_host_req_i.aw.burst = axi_pkg::BURST_INCR;
    tb_axi_host_req_i.aw.lock = 1'b0;
    tb_axi_host_req_i.aw.cache = '0;
    tb_axi_host_req_i.aw.prot = '0;
    tb_axi_host_req_i.aw.qos = '0;
    tb_axi_host_req_i.aw.region = '0;
    tb_axi_host_req_i.aw.atop = axi_pkg::ATOP_NONE;
    tb_axi_host_req_i.aw.user = '0;
    tb_axi_host_req_i.aw_valid = 1'b1;
    `wait_for(tb_axi_host_rsp_o.aw_ready)
    tb_axi_host_req_i.aw_valid = 1'b0;
    tb_axi_host_req_i.w.data = write_data;
    tb_axi_host_req_i.w.strb = '1;
    tb_axi_host_req_i.w.last = 1'b1;
    tb_axi_host_req_i.w.user = '0;
    tb_axi_host_req_i.w_valid = 1'b1;
    `wait_for(tb_axi_host_rsp_o.w_ready)
    tb_axi_host_req_i.w_valid = 1'b0;
    tb_axi_host_req_i.b_ready = 1'b1;
    `wait_for(tb_axi_host_rsp_o.b_valid)
    write_rsp = tb_axi_host_rsp_o.b.resp;
    tb_axi_host_req_i.b_ready = 1'b0;
`ifdef VERBOSE
    $display ("[%0tns] picobello_write - Write 0x%h to address location 0x%h", $time, write_data, write_addr);
`endif
  endtask

  // Read from Picobello
  task automatic picobello_read(
    input axi_host_addr_t read_addr, 
    output axi_host_data_t read_data, 
    output axi_host_rsp_t read_rsp
  );
    tb_axi_host_req_i.ar.id = '0;
    tb_axi_host_req_i.ar.addr = read_addr;
    tb_axi_host_req_i.ar.len = '0;
    tb_axi_host_req_i.ar.size = $clog2(HostAxiDataWidth/8);
    tb_axi_host_req_i.ar.burst = axi_pkg::BURST_INCR;
    tb_axi_host_req_i.ar.lock = 1'b0;
    tb_axi_host_req_i.ar.cache = '0;
    tb_axi_host_req_i.ar.prot = '0;
    tb_axi_host_req_i.ar.qos = '0;
    tb_axi_host_req_i.ar.region = '0;
    tb_axi_host_req_i.ar.user = '0;
    tb_axi_host_req_i.ar_valid = 1'b1;
    `wait_for(tb_axi_host_rsp_o.ar_ready)
    tb_axi_host_req_i.ar_valid = 1'b0;
    tb_axi_host_req_i.r_ready = 1'b1;
    `wait_for(tb_axi_host_rsp_o.r_valid)
    read_data = tb_axi_host_rsp_o.r.data;
    read_rsp = tb_axi_host_rsp_o.r.resp;
    tb_axi_host_req_i.r_ready = 1'b0;
`ifdef VERBOSE
    $display ("[%0tns] picobello_read - Read 0x%h from address location 0x%h", $time, read_data, read_addr);
`endif
  endtask

  task picobello_tg_cfg(
    input tg_cfg_t tg_cfg
  );
    axi_host_addr_t int_addr;
    axi_host_data_t int_write_data, int_read_data;
    axi_host_rsp_t int_rsp;

    // Set destination address of narrow port
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h10;
    assign int_write_data = tg_cfg.mem_addr_base;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set destination address of wide port
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h1c;
    assign int_write_data = tg_cfg.mem_addr_base;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set traffic dimension
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h28;
    assign int_write_data = tg_cfg.TrafficGenTrafficDim;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set compute dimension
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h34;
    assign int_write_data = tg_cfg.TrafficGenComputeDim;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set traffic index
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h40;
    assign int_write_data = tg_cfg.TrafficGenIdx;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);
`ifdef VERBOSE
    $display ("[%0tns] picobello_tg_cfg - Configured TG-%d to access MEM-%d", $time, tg_cfg.traffic_gen_port_id, tg_cfg.mem_port_id);
`endif
  endtask

  task picobello_tg_start(
    input tg_cfg_t tg_cfg
  );
    axi_host_data_t traffic_gen_start;
    axi_host_addr_t int_addr;
    axi_host_data_t int_read_data;
    axi_host_rsp_t int_rsp;

    // Read control register
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
    picobello_read(int_addr, int_read_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Run traffic generator
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
    assign traffic_gen_start = (int_read_data & 32'h0000_0080) | 32'h0000_0001;
    picobello_write(int_addr, traffic_gen_start, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);
  endtask

  task picobello_tg_polling(
    input tg_cfg_t tg_cfg
  );
    axi_host_data_t traffic_gen_idle;
    axi_host_addr_t int_addr;
    axi_host_data_t int_read_data;
    axi_host_rsp_t int_rsp;

    // Check traffic generator idleness  
    assign traffic_gen_idle = '0;  
    while (~traffic_gen_idle[0]) begin
      // Read control register
      assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
      picobello_read(int_addr, int_read_data, int_rsp);
      assert(int_rsp == axi_pkg::RESP_OKAY);
`ifdef VERBOSE
      $display ("[%0tns] picobello_tg_polling - Control register: 0x%h", $time, int_read_data);
`endif
      assign traffic_gen_idle = (int_read_data >> 2) & 32'h0000_0001; // - TO-DO: check why different wrt. accelerator driver
    end
  endtask

  // Program and launch traffic generators inside Picobello
  initial begin
    wait(rst_n);
    @(posedge clk);

    //////////////////////////////////
    // Test: ClusterX0Y0 <-> L2Spm0 //
    //////////////////////////////////

    $display ("[%0tns] Test: ClusterX0Y0 <-> L2Spm0", $time);

    // Set address map
    tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::ClusterX0Y0;
    tb_tg_cfg.mem_port_id               = floo_picobello_noc_pkg::L2Spm0 - floo_picobello_noc_pkg::L2Spm0;
    tb_tg_cfg.traffic_gen_addr_base     = 32'h2000_0000 + tb_tg_cfg.traffic_gen_port_id * 32'h0004_0000;    
    tb_tg_cfg.mem_addr_base             = 32'h3000_0000 + tb_tg_cfg.mem_port_id * 32'h0010_0000;

    // Set traffic generator parameters
    tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenIdx             = 32'h0000_0001;

    // Program traffic generator
    picobello_tg_cfg(tb_tg_cfg);

    // Run traffic generator
    picobello_tg_start(tb_tg_cfg);

    #5us;

    // Wait for termination
    picobello_tg_polling(tb_tg_cfg); 

    //////////////////////////////////
    // Test: ClusterX3Y3 <-> L2Spm0 //
    //////////////////////////////////

    $display ("[%0tns] Test: ClusterX3Y3 <-> L2Spm0", $time);

    // Set address map
    tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::ClusterX3Y3;
    tb_tg_cfg.mem_port_id               = floo_picobello_noc_pkg::L2Spm0 - floo_picobello_noc_pkg::L2Spm0;
    tb_tg_cfg.traffic_gen_addr_base     = 32'h2000_0000 + tb_tg_cfg.traffic_gen_port_id * 32'h0004_0000;    
    tb_tg_cfg.mem_addr_base             = 32'h3000_0000 + tb_tg_cfg.mem_port_id * 32'h0010_0000;

    // Set traffic generator parameters
    tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenIdx             = 32'h0000_0001;

    // Program traffic generator
    picobello_tg_cfg(tb_tg_cfg);

    // Run traffic generator
    picobello_tg_start(tb_tg_cfg);

    #5us;

    // Wait for termination
    picobello_tg_polling(tb_tg_cfg); 

    ////////////////////////
    // Test: Run Them All //
    ////////////////////////

    $display ("[%0tns] Test: Run Them All", $time);

    // Iterate traffic generators and memory tiles to test NoC paths
    mem_tile_loop: for (int i_mem = 0; i_mem < picobello_pkg::NumMemTiles; i_mem++) begin
      // Set memory address
      tb_tg_cfg.mem_port_id               = i_mem;  
      tb_tg_cfg.mem_addr_base             = 32'h3000_0000 + i_mem * 32'h0010_0000;

      // Set traffic generator parameters
      tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
      tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;

      // Program all traffic generators (Snitch clusters, Cheshire and FhgSpu)
      tg_cfg_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters+2); i_tg++) begin
        // Set traffic generator address and index
        tb_tg_cfg.traffic_gen_port_id       = i_tg;
        tb_tg_cfg.traffic_gen_addr_base     = 32'h2000_0000 + i_tg * 32'h0004_0000;  
        tb_tg_cfg.TrafficGenIdx             = i_tg;
        picobello_tg_cfg(tb_tg_cfg);
      end

      // Run traffic generators
      tg_start_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters+2); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'h2000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_start(tb_tg_cfg);
      end

      #20us;

      // Wait for termination
      tg_wait_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters+2); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'h2000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_polling(tb_tg_cfg);
      end

      tg_info_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters+2); i_tg++) begin
        $display ("[%0tns] - Mem-tile: %d", $time, i_mem);
        $display ("[%0tns] - TG-tile: %d", $time, i_tg);
      end
    end

    #1us; 
    $finish();
  end

endmodule

