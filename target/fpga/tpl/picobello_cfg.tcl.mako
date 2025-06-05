# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Vivado project location
set prj_dir [lindex $argv 0]
puts "Vivado project is going to be located in $prj_dir\."

# Vivado parameters
set PRJ_NAME "${soc_prj_name}"
set PRJ_IP_NAME "${soc_prj_ip_name}"
% if (fpga_target == 'xilzu9eg'):
set PL_PART_NAME "xczu9eg-ffvb1156-2-e"
set BOARD_PART_NAME "xilinx.com:zcu102:part0:3.3"
% endif
set I_SOC_NAME "i_${soc_name}"
set N_ZYNQ_MST ${n_host_ports}
set N_ZYNQ_SLV 1
set PL_FREQMHZ 10