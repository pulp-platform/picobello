# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Vivado build location
set VIVADO_BUILD [lindex $argv 0]

# Vivado project location
set VIVADO_PRJ $VIVADO_BUILD/vivado_prj
puts "Vivado project is going to be located in $VIVADO_PRJ\."

# Source project parameters
source $VIVADO_BUILD/picobello_cfg.tcl

# Create project
create_project $PRJ_NAME $VIVADO_PRJ -part $PL_PART_NAME
set_property board_part $BOARD_PART_NAME [current_project]

# Add Picobello IP to user library
set_property ip_repo_paths $VIVADO_BUILD [current_project]
update_ip_catalog

# Create block design
create_bd_design "$PRJ_NAME"
update_compile_order -fileset sources_1

# Add Zynq UltraScale+ Processor System (Host)
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 i_zynq_ps
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" } \
  [get_bd_cells i_zynq_ps]
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP0 {1} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP3 {1} \
  CONFIG.PSU__MAXIGP0__DATA_WIDTH {${dw}} \
  CONFIG.PSU__MAXIGP1__DATA_WIDTH {${dw}} \
  CONFIG.PSU__SAXIGP2__DATA_WIDTH {${dw}} \
  CONFIG.PSU__SAXIGP3__DATA_WIDTH {${dw}} \
  CONFIG.PSU__USE__IRQ1 {1} \
] [get_bd_cells i_zynq_ps]

connect_bd_net [get_bd_pins i_zynq_ps/pl_clk0] \
  [get_bd_pins i_zynq_ps/saxihp1_fpd_aclk]
connect_bd_net [get_bd_pins i_zynq_ps/pl_clk0] \
  [get_bd_pins i_zynq_ps/maxihpm0_fpd_aclk]

# Configure PL frequency
set_property -dict [list \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ "$PL_FREQMHZ"] [get_bd_cells i_zynq_ps]

# Add System Reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 i_sys_reset
connect_bd_net [get_bd_pins i_zynq_ps/pl_resetn0] \
  [get_bd_pins i_sys_reset/ext_reset_in]
connect_bd_net [get_bd_pins i_zynq_ps/pl_clk0] \
  [get_bd_pins i_sys_reset/slowest_sync_clk]

# Add Picobello IP
create_bd_cell -type ip -vlnv ethz.ch:user:$PRJ_IP_NAME:1.0 i_picobello

# Connect host to Picobello IP
set clk [format "clk_i" 0]
set rst [format "rst_ni" 0]
connect_bd_net [get_bd_pins i_zynq_ps/pl_clk0] \
  [get_bd_pins i_picobello/$clk]
connect_bd_net [get_bd_pins i_sys_reset/peripheral_aresetn] \
  [get_bd_pins i_picobello/$rst]
connect_bd_intf_net -boundary_type upper [get_bd_intf_pins i_zynq_ps/M_AXI_HPM0_FPD] \
  [get_bd_intf_pins i_picobello/slv]

# # Concats for the Picobello->Host IRQs
# create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 i_irq_concat_0
# set_property -dict [list CONFIG.NUM_PORTS {2}] [get_bd_cells i_irq_concat_0]
# connect_bd_net [get_bd_pins i_irq_concat_0/dout] [get_bd_pins i_zynq_ps/pl_ps_irq1]

# connect_bd_net [get_bd_pins i_picobello/cl_eoc_o] [get_bd_pins i_irq_concat_0/In0]

# Address Map
## Picobello Slave
assign_bd_address [get_bd_addr_segs {i_picobello/slv/Reg }]
set_property range 128M [get_bd_addr_segs {i_zynq_ps/Data/SEG_i_picobello_Reg}]
set_property offset 0x00A0000000 [get_bd_addr_segs {i_zynq_ps/Data/SEG_i_picobello_Reg}]
# ## DDR Low
# assign_bd_address [get_bd_addr_segs {i_zynq_ps/SAXIGP3/HP1_DDR_LOW }]
# set_property range 2G [get_bd_addr_segs {i_picobello/Data/SEG_i_zynq_ps_HP1_DDR_LOW}]
# set_property offset 0x0000000000 [get_bd_addr_segs {i_picobello/Data/SEG_i_zynq_ps_HP1_DDR_LOW}]
# ## DDR High
# assign_bd_address [get_bd_addr_segs {i_zynq_ps/SAXIGP3/HP1_DDR_HIGH }]
# set_property range 32G [get_bd_addr_segs {i_picobello/Data/SEG_i_zynq_ps_HP1_DDR_HIGH}]
# set_property offset 0x0800000000 [get_bd_addr_segs {i_picobello/Data/SEG_i_zynq_ps_HP1_DDR_HIGH}]

# Validate and save Top-Level Block Design
save_bd_design
validate_bd_design
save_bd_design
close_bd_design [get_bd_designs $PRJ_NAME]

make_wrapper -files [get_files \
  $VIVADO_PRJ/$PRJ_NAME.srcs/sources_1/bd/$PRJ_NAME/$PRJ_NAME.bd \
] -top
add_files -norecurse \
  $VIVADO_PRJ/$PRJ_NAME.srcs/sources_1/bd/$PRJ_NAME/hdl/$PRJ_NAME\_wrapper.v

# Create targets and runs for IPs.
generate_target all \
  [get_files $VIVADO_PRJ/$PRJ_NAME.srcs/sources_1/bd/$PRJ_NAME/$PRJ_NAME.bd]
export_ip_user_files -of_objects \
  [get_files $VIVADO_PRJ/$PRJ_NAME.srcs/sources_1/bd/$PRJ_NAME/$PRJ_NAME.bd] \
  -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] \
  $VIVADO_PRJ/$PRJ_NAME.srcs/sources_1/bd/$PRJ_NAME/$PRJ_NAME.bd \
]
export_ip_user_files -of_objects [get_ips $PRJ_NAME\_$I_SOC_NAME\_0] \
  -no_script -sync -force -quiet

# Define include and defines again for PULP.
# Note: Direct name substitution because of conflicts between Mako and tcl syntaxes
set string_name "$PRJ_NAME"
append string_name "_"
append string_name "i_picobello"
append string_name "_0"
eval [exec sed {s/current_fileset/get_filesets $string_name/} \
  $VIVADO_BUILD\/define_defines_includes_no_simset.tcl]

#
# FPGA SYNTHESIS
#

# Set strategies
set_property strategy Flow_AlternateRoutability [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

# Set synthesis properties
set_property XPM_LIBRARIES XPM_MEMORY [current_project]

# Launch synthesis
launch_runs synth_1 -jobs 12
wait_on_run synth_1

#
# FPGA IMPLEMENTATION
#

# Set strategies
set_property strategy Congestion_SpreadLogic_low [get_runs impl_1]

# Launch implementation
launch_runs impl_1 -jobs 12
wait_on_run impl_1

# Check timing constraints.
open_run impl_1
set timingrep [report_timing_summary -no_header -no_detailed_paths -return_string]
if {! [string match -nocase {*timing constraints are met*} $timingrep]} {
  send_msg_id {USER 1-1} ERROR {Timing constraints were not met.}
  return -code error
}

# Generate Bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

# Export Hardware Definition file
file mkdir $VIVADO_PRJ/$PRJ_NAME.sdk
write_hwdef -force -file $VIVADO_PRJ/$PRJ_NAME.sdk/$PRJ_NAME\_wrapper.hdf

# Export bitstream file
file copy -force $VIVADO_PRJ/$PRJ_NAME.runs/impl_1/$PRJ_NAME\_wrapper.bit $VIVADO_PRJ/$PRJ_NAME.sdk/$PRJ_NAME\_wrapper.bit

# Export Xilinx Support Archive (XSA) file
write_hw_platform -fixed -force -include_bit -file $VIVADO_PRJ/$PRJ_NAME\_wrapper.xsa