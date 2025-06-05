# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Vivado build location
set VIVADO_BUILD [lindex $argv 0]

# Source project parameters
source $VIVADO_BUILD/picobello_cfg.tcl

# Create project
create_project $PRJ_IP_NAME $VIVADO_BUILD/$PRJ_IP_NAME -part $PL_PART_NAME
set_property board_part $BOARD_PART_NAME [current_project]
set_property part $PL_PART_NAME [current_project]

source $VIVADO_BUILD/define_sources.tcl
source $VIVADO_BUILD/define_defines_includes.tcl
add_files -norecurse -fileset constrs_1 {picobello_txilzu9eg_synth.xdc picobello_txilzu9eg_impl.xdc}
set_property used_in_implementation false [get_files $VIVADO_BUILD/picobello_txilzu9eg_synth.xdc]
set_property used_in_synthesis false [get_files $VIVADO_BUILD/picobello_txilzu9eg_impl.xdc]

# Select top
set_property top $PRJ_IP_NAME [current_fileset]

# Build RTL design
synth_design -rtl -name rtl_1

# IP packaging
ipx::package_project -root_dir . -vendor ethz.ch -library user -taxonomy /UserIP \
  -set_current true

# Ports and Interfaces

# Clock
ipx::add_bus_interface clk [ipx::current_core]
set clk [ipx::get_bus_interfaces clk -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 $clk
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 $clk
set_property interface_mode slave $clk
ipx::add_bus_parameter FREQ_HZ $clk
ipx::add_port_map CLK $clk
set_property physical_name clk_i [ipx::get_port_maps CLK -of_objects $clk]

# Reset
ipx::add_bus_interface rst_n [ipx::current_core]
set rst [ipx::get_bus_interfaces rst_n -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $rst
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $rst
ipx::add_port_map RST $rst
set_property physical_name rst_ni [ipx::get_port_maps RST -of_objects $rst]

# AXI Slave
ipx::add_bus_interface slv [ipx::current_core]
set slv [ipx::get_bus_interfaces slv -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 $slv
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 $slv
set_property interface_mode slave $slv
ipx::add_bus_parameter NUM_READ_OUTSTANDING $slv
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING $slv
set portmap {
  {AWID slv_aw_id_i}
  {AWADDR slv_aw_addr_i}
  {AWLEN slv_aw_len_i}
  {AWSIZE slv_aw_size_i}
  {AWBURST slv_aw_burst_i}
  {AWLOCK slv_aw_lock_i}
  {AWCACHE slv_aw_cache_i}
  {AWPROT slv_aw_prot_i}
  {AWQOS slv_aw_qos_i}
  {AWUSER slv_aw_user_i}
  {AWVALID slv_aw_valid_i}
  {AWREADY slv_aw_ready_o}
  {WDATA slv_w_data_i}
  {WSTRB slv_w_strb_i}
  {WLAST slv_w_last_i}
  {WVALID slv_w_valid_i}
  {WREADY slv_w_ready_o}
  {BID slv_b_id_o}
  {BRESP slv_b_resp_o}
  {BVALID slv_b_valid_o}
  {BREADY slv_b_ready_i}
  {ARID slv_ar_id_i}
  {ARADDR slv_ar_addr_i}
  {ARLEN slv_ar_len_i}
  {ARSIZE slv_ar_size_i}
  {ARBURST slv_ar_burst_i}
  {ARLOCK slv_ar_lock_i}
  {ARCACHE slv_ar_cache_i}
  {ARPROT slv_ar_prot_i}
  {ARQOS slv_ar_qos_i}
  {ARUSER slv_ar_user_i}
  {ARVALID slv_ar_valid_i}
  {ARREADY slv_ar_ready_o}
  {RID slv_r_id_o}
  {RDATA slv_r_data_o}
  {RRESP slv_r_resp_o}
  {RLAST slv_r_last_o}
  {RVALID slv_r_valid_o}
  {RREADY slv_r_ready_i}
}
foreach pair $portmap {
  set theirs [lindex $pair 0]
  set ours [lindex $pair 1]
  ipx::add_port_map $theirs $slv
  set_property physical_name $ours [ipx::get_port_maps $theirs -of_objects $slv]
}
ipx::associate_bus_interfaces -busif slv -clock clk [ipx::current_core]

# Address Space
ipx::add_address_space Data [ipx::current_core]
# set_property master_address_space_ref Data \
#   [ipx::get_bus_interfaces axi_host_in -of_objects [ipx::current_core] \ 
# ]
set_property width 32 [ipx::get_address_spaces Data -of_objects [ipx::current_core]]
set_property range_format string [ipx::get_address_spaces Data -of_objects [ipx::current_core]]
set_property range 16E [ipx::get_address_spaces Data -of_objects [ipx::current_core]]

# Save IP
set_property core_revision 4 [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project