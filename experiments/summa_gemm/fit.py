#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo Leone <lleoen@iis.ee.ethz.ch>

EN_COMP = 24.6  # energy per ops of matmul execution
EN_SW_RED = 22.43  # energy per ops of software reduction
EN_HW_RED = 19  # energy per ops of hardware reduction (DCA)

EN_L2_L1 = 2.2  # energy of a transfer from L2 to L1
EN_L1_L2 = 2.4  # energy of a transfer from L1 to L2
EN_L1_R = 2.2  # energy of a transfer from L1 to router interface
EN_R_L1 = 1.84  # energy of a transfer from router to L1
EN_R_R = 1.14  # energy to cross a router


def e_clu_to_clu(dist):
    return EN_L1_R + EN_R_R * (dist - 1) + EN_R_L1


def e_l2_to_clu(dist):
    return EN_L2_L1 + EN_R_R * (dist - 1)


def e_clu_to_l2(dist):
    return EN_L1_L2 + EN_R_R * (dist - 1)


def e_sw_red_clu(m, n):
    # return POW_SW_RED_CLU * T_SW_RED_CLU
    return m * n * EN_SW_RED


def e_hw_red_clu(m, n):
    return m * n * EN_HW_RED
