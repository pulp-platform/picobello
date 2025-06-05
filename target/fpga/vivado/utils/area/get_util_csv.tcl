# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
#

# Get utilization report from Vivado as string
set reportLines [split [report_utilization -hierarchical -return_string -hierarchical_depth 20] "\n"]

# Create output CSV
set csv_file "$reports_dir/$PRJ_NAME\_$design_run_type\_utilization.csv"
set fh [open $csv_file w]

# Process report for use with ArchEx
set writelines false
foreach line $reportLines {
	if {[regexp {\\+[\+-]\+} $line]} {
		set writelines true
	}
	if {[regexp {^\|} $line]} {
		puts $fh [regsub -all {\|} [regsub -all {.\|.} $line ","] ""]
	}
}
close $fh