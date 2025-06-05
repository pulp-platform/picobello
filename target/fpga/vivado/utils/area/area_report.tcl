# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# ========= #
# Variables #
# ========= #

# Following variables are set global for other sub-scripts to access 
# them as source command does allow for additional arguments to be passed

# Vivado build location
set VIVADO_BUILD [lindex $argv 0]

# Area utils directory
set ::area_utils [lindex $argv 1]

# Vivado project location
set VIVADO_PRJ $VIVADO_BUILD/vivado_prj
puts "Vivado project is going to be located in $VIVADO_PRJ\."

# Source project parameters
source $VIVADO_BUILD/picobello_cfg.tcl

# Reports directory
set ::reports_dir "$VIVADO_PRJ/../reports"

# Create report directory
set reports_dir_list [glob -nocomplain -directory "$VIVADO_PRJ/.." -type d "reports"]

if {[llength $reports_dir_list] == 0} {
  file mkdir $reports_dir
}

# =================== #
# Open target project #
# =================== #

open_project $VIVADO_PRJ/$PRJ_NAME.xpr
update_compile_order -fileset sources_1

# ================================================= #
# Create utilization reports for synthesized design #
# ================================================= #

# Design run type
set ::design_run_type "synth"
set ::design_run_name "synth_1"

# Design run state
set ::design_run_status [get_property STATUS [get_runs $design_run_name]]
set ::design_run_progress [get_property PROGRESS [get_runs $design_run_name]]

# Open runlist 
set runlist [get_runs $design_run_type*]

# Check if run exist
if {[regexp -- $design_run_name $runlist]} {

    # Check if run has completed
    if { [regexp -- Complete $design_run_status] && [regexp -- 100% $design_run_progress]} {

        # Open design run
        open_run $design_run_name

        # Export report into CSV
        source $area_utils/get_util_csv.tcl

    }
}

# ================================================= #
# Create utilization reports for implemented design #
# ================================================= #

# Design run type
set ::design_run_type "impl"
set ::design_run_name "impl_1"

# Design run state
set ::design_run_status [get_property STATUS [get_runs $design_run_name]]
set ::design_run_progress [get_property PROGRESS [get_runs $design_run_name]]

# Open runlist 
set runlist [get_runs $design_run_type*]

# Check if run exist
if {[regexp -- $design_run_name $runlist]} {

    # Check if run has completed
    if { [regexp -- Complete $design_run_status] && [regexp -- 100% $design_run_progress]} {

        # Open design run
        open_run $design_run_name

        # Export report into CSV
        source $area_utils/get_util_csv.tcl

    }
}