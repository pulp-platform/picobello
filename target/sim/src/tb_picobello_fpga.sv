// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define wait_for(signal) do @(posedge clk); while (!signal);

module tb_picobello_fpga;

  // `include "tb_picobello_tasks.svh"
  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  localparam int unsigned NumTrafficGenerators = picobello_pkg::NumClusters + 1;

  // verilog_format: off
  logic clk;
  logic rst_n;
  logic test_mode;

  logic [NumTrafficGenerators-1:0] tg_busy;

  // Host interface
  floo_picobello_noc_pkg::axi_narrow_in_req_t tb_axi_host_req_i;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t tb_axi_host_rsp_o;

  fpga_picobello_top #(
    .NumTrafficGenerators (NumTrafficGenerators)
  ) dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .test_mode_i      (test_mode),
    .axi_host_req_i   (tb_axi_host_req_i),
    .axi_host_rsp_o   (tb_axi_host_rsp_o)
  );

  // Write to Picobello
  task write_to_picobello(
    input floo_picobello_noc_pkg::axi_narrow_in_addr_t addr, 
    input floo_picobello_noc_pkg::axi_narrow_in_data_t data, 
    output floo_picobello_noc_pkg::axi_narrow_in_rsp_t rsp
  );
    tb_axi_host_req_i.aw.id = '0;
    tb_axi_host_req_i.aw.addr = addr;
    tb_axi_host_req_i.aw.len = '0;
    tb_axi_host_req_i.aw.size = $clog2(floo_picobello_noc_pkg::AxiCfgN.DataWidth/8);
    tb_axi_host_req_i.aw.burst = axi_pkg::BURST_INCR;
    tb_axi_host_req_i.aw.lock = 1'b0;
    tb_axi_host_req_i.aw.cache = '0;
    tb_axi_host_req_i.aw.prot = '0;
    tb_axi_host_req_i.aw.qos = '0;
    tb_axi_host_req_i.aw.region = '0;
    tb_axi_host_req_i.aw.atop = '0;
    tb_axi_host_req_i.aw.user = '0;
    tb_axi_host_req_i.aw_valid = 1'b1;
    `wait_for(tb_axi_host_rsp_o.aw_ready)
    tb_axi_host_req_i.aw_valid = 1'b0;
    tb_axi_host_req_i.w.data = data;
    tb_axi_host_req_i.w.strb = '1;
    tb_axi_host_req_i.w.last = 1'b1;
    tb_axi_host_req_i.w.user = '0;
    tb_axi_host_req_i.w_valid = 1'b1;
    `wait_for(tb_axi_host_rsp_o.w_ready)
    tb_axi_host_req_i.w_valid = 1'b0;
    tb_axi_host_req_i.b_ready = 1'b1;
    `wait_for(tb_axi_host_rsp_o.b_valid)
    rsp = tb_axi_host_rsp_o.b.resp;
    tb_axi_host_req_i.b_ready = 1'b0;
  endtask

  // Read from Picobello
  task read_from_picobello(
    input floo_picobello_noc_pkg::axi_narrow_in_addr_t addr, 
    output floo_picobello_noc_pkg::axi_narrow_out_data_t data, 
    output floo_picobello_noc_pkg::axi_narrow_in_rsp_t rsp
  );
    tb_axi_host_req_i.ar.id = '0;
    tb_axi_host_req_i.ar.addr = addr;
    tb_axi_host_req_i.ar.len = '0;
    tb_axi_host_req_i.ar.size = $clog2(floo_picobello_noc_pkg::AxiCfgN.DataWidth/8);
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
    data = tb_axi_host_rsp_o.r.data;
    rsp = tb_axi_host_rsp_o.r.resp;
    tb_axi_host_req_i.r_ready = 1'b0;
  endtask

  // Program and launch traffic generators inside Picobello
  initial begin
    floo_picobello_noc_pkg::axi_narrow_out_data_t data;
    floo_picobello_noc_pkg::axi_narrow_in_rsp_t rsp;

    wait(rst_n);
    @(posedge clk);

    // Configure traffic generators inside Picobello.
    write_to_picobello(64'h0000_0000_1000_0000, 32'h0000_0000, rsp);
    assert(rsp == axi_pkg::RESP_OKAY);

    // // Wait for EOC of cluster 0 before terminating the simulation.
    // wait(tg_busy[NumTrafficGenerators-1]);

    #1us; 
    $finish();
  end

endmodule

