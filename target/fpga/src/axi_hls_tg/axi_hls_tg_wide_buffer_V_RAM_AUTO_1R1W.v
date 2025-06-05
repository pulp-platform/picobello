// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2022.2.1 (64-bit)
// Version: 2022.2.1
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// ==============================================================
`timescale 1 ns / 1 ps
module axi_hls_tg_wide_buffer_V_RAM_AUTO_1R1W (
     
    address0, ce0,
    d0, we0, 
    q0, 
      
    address1, ce1,
    
    q1, 
     
    reset, clk);

parameter DataWidth = 64;
parameter AddressWidth = 8;
parameter AddressRange = 256;
 
input[AddressWidth-1:0] address0;
input ce0;
input[DataWidth-1:0] d0;
input we0; 
output reg[DataWidth-1:0] q0; 
 
input[AddressWidth-1:0] address1;
input ce1;

output reg[DataWidth-1:0] q1; 

input reset;
input clk;

(* ram_style = "auto"  *)reg [DataWidth-1:0] ram[0:AddressRange-1];


 





//read first
always @(posedge clk)  
begin 
    if (ce0) begin
        if (we0) 
            ram[address0] <= d0; 
        q0 <= ram[address0];

    end
end 
 
  



always @(posedge clk) 
begin 
    if (ce1) begin
        q1 <= ram[address1];
    end
end 

 
 

endmodule

