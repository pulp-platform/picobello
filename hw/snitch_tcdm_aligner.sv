// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "hci_helpers.svh"

module snitch_tcdm_aligner
  import reqrsp_pkg::amo_op_e;
#(
  parameter type         tcdm_req_t    = logic,
  parameter type         tcdm_rsp_t    = logic,
  parameter int unsigned DataWidth     = 512,
  parameter int unsigned TCDMDataWidth = 64,
  parameter int unsigned AddrWidth     = 48
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  tcdm_req_t tcdm_req_misaligned_i,
  output tcdm_req_t tcdm_req_aligned_o,
  input  tcdm_rsp_t tcdm_rsp_aligned_i,
  output tcdm_rsp_t tcdm_rsp_misaligned_o
);

  localparam logic [AddrWidth-1:0] AddrMask = ~(DataWidth / 8 - 1);

  logic [$clog2(DataWidth/TCDMDataWidth)-1:0] addr_significant_d, addr_significant_q;


  assign addr_significant_d = tcdm_req_misaligned_i.q.addr[$clog2(
      DataWidth/8
  )-1:$clog2(
      TCDMDataWidth/8
  )];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      addr_significant_q <= '0;
    end else if (tcdm_rsp_aligned_i.q_ready) begin
      addr_significant_q <= addr_significant_d;
    end
  end

  // Bind tcdm_req_aligned_o signals
  assign tcdm_req_aligned_o.q.addr = tcdm_req_misaligned_i.q.addr & AddrMask;
  assign tcdm_req_aligned_o.q.write = tcdm_req_misaligned_i.q.write;
  assign tcdm_req_aligned_o.q.amo = tcdm_req_misaligned_i.q.amo;
  assign tcdm_req_aligned_o.q.data  = tcdm_req_misaligned_i.q.data << (addr_significant_d * TCDMDataWidth);
  assign tcdm_req_aligned_o.q.strb  = tcdm_req_misaligned_i.q.strb << (addr_significant_d * TCDMDataWidth/8);
  assign tcdm_req_aligned_o.q.user = tcdm_req_misaligned_i.q.user;
  assign tcdm_req_aligned_o.q_valid = tcdm_req_misaligned_i.q_valid;

  // Bind tcdm_rsp_misaligned_o signals
  assign tcdm_rsp_misaligned_o.p.data  = tcdm_rsp_aligned_i.p.data >> (addr_significant_q * TCDMDataWidth);
  assign tcdm_rsp_misaligned_o.p_valid = tcdm_rsp_aligned_i.p_valid;
  assign tcdm_rsp_misaligned_o.q_ready = tcdm_rsp_aligned_i.q_ready;

endmodule