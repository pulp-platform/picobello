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
EN_L1_R = 2.4   # energy of a transfer from L1 to router interface (= EN_L1_L2)
EN_R_L1 = 1.84  # energy of a transfer from router to L1
EN_R_R = 1.14   # energy to cross a router

# 7 components matching the energy table columns (dma_ld, dma_st, link_to_link,
# tcdm_write, gemm, sw_red, hw_red). Breakdown values are *counts* (number of
# primitive transfers/operations); multiply by ENERGY_PER_COMPONENT to get energy.
ENERGY_COMPONENTS = ("dma_ld", "dma_st", "link_to_link", "tcdm_write", "gemm", "sw_red", "hw_red")
ENERGY_PER_COMPONENT = {
    "dma_ld":       EN_L2_L1,   # L2 → L1 DMA load          [pJ/B]
    "dma_st":       EN_L1_L2,   # L1 → L2 or L1 → router    [pJ/B] (EN_L1_R = EN_L1_L2)
    "link_to_link": EN_R_R,     # router-to-router hop       [pJ/B·hop]
    "tcdm_write":   EN_R_L1,    # router → L1 TCDM write     [pJ/B]
    "gemm":         EN_COMP,    # GEMM MAC operation         [pJ/op]
    "sw_red":       EN_SW_RED,  # SW reduction operation     [pJ/op]
    "hw_red":       EN_HW_RED,  # HW reduction operation     [pJ/op]
}


# --------------------------------- #
#  Energy primitive (scalar) models #
# --------------------------------- #

def e_clu_to_clu(dist):
    return EN_L1_R + EN_R_R * (dist - 1) + EN_R_L1


def e_l2_to_clu(dist):
    return EN_L2_L1 + EN_R_R * (dist - 1)


def e_clu_to_l2(dist):
    return EN_L1_L2 + EN_R_R * (dist - 1)


def e_sw_red_clu(m, n):
    return m * n * EN_SW_RED


def e_hw_red_clu(m, n):
    return m * n * EN_HW_RED


# ---------------------------------- #
#  Breakdown helpers                  #
# ---------------------------------- #

def zero_energy_brkdn():
    return {c: 0.0 for c in ENERGY_COMPONENTS}


def add_energy_brkdn(*brkdns):
    total = zero_energy_brkdn()
    for brkdn in brkdns:
        for c in ENERGY_COMPONENTS:
            total[c] += brkdn[c]
    return total


def scale_energy_breakdown(brkdn, factor):
    return {c: factor * brkdn[c] for c in ENERGY_COMPONENTS}


def brkdn_to_energy(brkdn):
    """Convert a count-based breakdown dict to a scalar energy value."""
    return sum(brkdn[c] * ENERGY_PER_COMPONENT[c] for c in ENERGY_COMPONENTS)


# ---------------------------------- #
#  Energy primitive breakdown models  #
# (return counts per byte/op, not    #
#  energies)                         #
# ---------------------------------- #

def e_l2_to_clu_brkdn(dist):
    """e_l2_to_clu = EN_L2_L1 + EN_R_R*(dist-1)  [per byte]"""
    brkdn = zero_energy_brkdn()
    brkdn["dma_ld"] = 1
    brkdn["link_to_link"] = dist - 1
    return brkdn


def e_clu_to_l2_brkdn(dist):
    """e_clu_to_l2 = EN_L1_L2 + EN_R_R*(dist-1)  [per byte]"""
    brkdn = zero_energy_brkdn()
    brkdn["dma_st"] = 1
    brkdn["link_to_link"] = dist - 1
    return brkdn


def e_clu_to_clu_brkdn(dist):
    """e_clu_to_clu = EN_L1_R + EN_R_R*(dist-1) + EN_R_L1  [per byte]
    EN_L1_R == EN_L1_L2, so the egress cost is tracked under dma_st."""
    brkdn = zero_energy_brkdn()
    brkdn["dma_st"] = 1
    brkdn["link_to_link"] = dist - 1
    brkdn["tcdm_write"] = 1
    return brkdn


def e_sw_red_clu_brkdn(m, n):
    """e_sw_red_clu = m*n*EN_SW_RED  [total ops]"""
    brkdn = zero_energy_brkdn()
    brkdn["sw_red"] = m * n
    return brkdn


def e_hw_red_clu_brkdn(m, n):
    """e_hw_red_clu = m*n*EN_HW_RED  [total ops]"""
    brkdn = zero_energy_brkdn()
    brkdn["hw_red"] = m * n
    return brkdn
