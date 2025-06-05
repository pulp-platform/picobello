#!/usr/bin/env python3
# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import sys
from mako.lookup import Template
import math
import re

def clog2(x):
    return math.ceil(math.log(x))

filename = sys.argv[1]

# Parameters

# Vivado project
soc_name                = 'picobello'
soc_prj_name            = 'picobello_exilzcu102'
soc_prj_ip_name         = 'picobello_ip'
fpga_target             = 'xilzu9eg'

# Host interface
n_host_ports = 1

# AXI4 parameters
aw                      = 64 
dw                      = 32 
iw                      = 3
uw                      = 4
aw_pl2ps                = 49
iw_pl2ps                = 5
uw_pl2ps                = 1
aw_ps2pl                = 40 
iw_ps2pl                = 16
uw_ps2pl                = 16

# AXI4-Lite parameters
aw_lite                 = 32
dw_lite                 = 32

# Generator

target_template = Template(filename=filename)
string = target_template.render(
    soc_name                = soc_name,
    soc_prj_name            = soc_prj_name,
    soc_prj_ip_name         = soc_prj_ip_name,
    fpga_target             = fpga_target, 
    n_host_ports            = n_host_ports,
    aw                      = aw, 
    dw                      = dw, 
    iw                      = iw, 
    uw                      = uw,
    aw_pl2ps                = aw_pl2ps, 
    iw_pl2ps                = iw_pl2ps, 
    uw_pl2ps                = uw_pl2ps,
    aw_ps2pl                = aw_ps2pl, 
    iw_ps2pl                = iw_ps2pl, 
    uw_ps2pl                = uw_ps2pl,
    aw_lite                 = aw_lite, 
    dw_lite                 = dw_lite,
)

re_trailws = re.compile(r'[ \t\r]+$', re.MULTILINE)
string = re.sub(r'\n\s*\n', '\n\n', string) 
string = re_trailws.sub("", string)

print(string)