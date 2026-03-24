#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

import math
import multicast
import reduction
from summa_gemm import fit

PREC = 8  # in bytes
BEAT_BYTES = 64  # in bytes
UTIL = 0.981  # median utilization from https://arxiv.org/pdf/2506.10921
PEAKPERF = 16  # DPflop/cycle on a single cluster
L1SIZE = 16 * 1024  # in bytes
ENERGY_COMPONENTS = fit.ENERGY_COMPONENTS


# --------------- #
# Timing Models   #
# --------------- #

def beats(bytes):
    return math.ceil(bytes / BEAT_BYTES)


def max_square_problem_size():
    n = math.floor(math.sqrt(L1SIZE / (6 * PREC)))
    # Round to nearest lower multiple of 8
    return (n // 8) * 8


def t_mcast(dim, bytes, impl='sw'):
    n = beats(bytes)
    if impl == 'sw':
        return multicast.model.optimal_sw_runtime(dim, 1, n)
    elif impl == 'seq':
        return multicast.model.optimal_seq_runtime(dim, 1, n)
    elif impl == 'tree':
        return multicast.model.tree_runtime(dim, 1, n)
    elif impl == 'hw':
        return multicast.model.hw_runtime(dim, 1, n)
    else:
        raise ValueError(f"Unknown multicast implementation: {impl}")


def t_mcast_a(c, Mt, Kt, impl='sw'):
    return t_mcast(c, Mt * Kt * PREC, impl)


def t_mcast_b(r, Nt, Kt, impl='sw'):
    return t_mcast(r, Nt * Kt * PREC, impl)


def t_summa_comm(r, c, Mt, Nt, Kt, impl='sw'):
    return t_mcast_a(c, Mt, Kt, impl=impl) + t_mcast_b(r, Nt, Kt, impl=impl)


def t_comp(Mt, Nt, Kt):
    return (2 * Mt * Nt * Kt) / (UTIL * PEAKPERF)


def t_summa_gemm(r, c, Mt, Nt, Kt, impl='sw'):
    return max(t_summa_comm(r, c, Mt, Nt, Kt, impl=impl), t_comp(Mt, Nt, Kt))


def t_fcl_comm(r, c, Mt, Nt, Kt, impl='sw'):
    # Time to load c*r submatrices of B (each of size Nt x Kt)
    # from r memory tiles
    return c * r * beats(Nt * Kt * PREC) / r


def t_reduction(r, c, bytes, impl='sw'):
    n = beats(bytes)
    if impl == 'sw':
        return reduction.model.optimal_sw_runtime(c, r, n)
    elif impl == 'hw':
        return reduction.model.hw_runtime(c, r, n)
    else:
        raise ValueError(f"Unknown reduction implementation: {impl}")


def t_fcl_gemm(r, c, Mt, Nt, Kt, impl='sw'):
    t_partial_result = max(t_fcl_comm(r, c, Mt, Nt, Kt, impl=impl), t_comp(Mt, Nt, Kt))
    t_redu = t_reduction(r, c, Mt * Nt * PREC, impl=impl)
    return t_partial_result + t_redu


# -------------- #
#  Power Models  #
# -------------- #

def e_comp(Mt, Nt, Kt):
    return (Mt * Nt * Kt) * fit.EN_COMP


def e_comp_brkdn(Mt, Nt, Kt):
    # mirrors: (Mt * Nt * Kt) * EN_COMP
    brkdn = fit.zero_energy_brkdn()
    brkdn['gemm'] = Mt * Nt * Kt
    return brkdn


def e_mcast(dim, bytes, impl='sw'):
    if impl == 'sw':
        return multicast.model.optimal_sw_energy(dim, bytes)
    elif impl == 'seq':
        return multicast.model.seq_energy(dim, bytes)
    elif impl == 'tree':
        return multicast.model.tree_energy(dim, bytes)
    elif impl == 'hw':
        return multicast.model.hw_energy(dim, bytes)
    else:
        raise ValueError(f"Unknown multicast implementation: {impl}")


def e_mcast_a(c, Mt, Kt, impl='sw'):
    return e_mcast(c, Mt * Kt * PREC, impl)


def e_mcast_b(r, Nt, Kt, impl='sw'):
    return e_mcast(r, Nt * Kt * PREC, impl)


def e_summa_comm(r, c, Mt, Nt, Kt, impl='sw'):
    return r * e_mcast_a(c, Mt, Kt, impl) + c * e_mcast_b(r, Nt, Kt, impl)


def e_summa_gemm(r, c, Mt, Nt, Kt, impl='sw'):
    return r * c * e_comp(Mt, Nt, Kt) + e_summa_comm(r, c, Mt, Nt, Kt, impl=impl)


def e_mcast_brkdn(dim, bytes, impl='sw'):
    if impl == 'sw':
        return multicast.model.optimal_sw_energy_brkdn(dim, bytes)
    elif impl == 'seq':
        return multicast.model.seq_energy_brkdn(dim, bytes)
    elif impl == 'tree':
        return multicast.model.tree_energy_brkdn(dim, bytes)
    elif impl == 'hw':
        return multicast.model.hw_energy_brkdn(dim, bytes)
    else:
        raise ValueError(f"Unknown multicast implementation: {impl}")


def e_mcast_a_brkdn(c, Mt, Kt, impl='sw'):
    return e_mcast_brkdn(c, Mt * Kt * PREC, impl)


def e_mcast_b_brkdn(r, Nt, Kt, impl='sw'):
    return e_mcast_brkdn(r, Nt * Kt * PREC, impl)


def e_summa_comm_brkdn(r, c, Mt, Nt, Kt, impl='sw'):
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(e_mcast_a_brkdn(c, Mt, Kt, impl), r),
        fit.scale_energy_breakdown(e_mcast_b_brkdn(r, Nt, Kt, impl), c),
    )


def e_summa_gemm_brkdn(r, c, Mt, Nt, Kt, impl='sw'):
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(e_comp_brkdn(Mt, Nt, Kt), r * c),
        e_summa_comm_brkdn(r, c, Mt, Nt, Kt, impl=impl),
    )


def e_fcl_comm(r, c, Nt, Kt):
    e_load_b = 0
    bytes = Nt * Kt * PREC  # bytes to move for B tile
    for i in range(c):
        e_load_b += bytes * fit.e_l2_to_clu(i + 1)
    return r * e_load_b


def e_reduction(r, c, Mt, Nt, impl='sw'):
    bytes = Mt * Nt * PREC  # bytes to move for C tile reduction
    if impl == 'sw':
        return reduction.model.optimal_sw_energy(c, r, Mt, Nt, bytes)
    elif impl == 'hw':
        return reduction.model.hw_energy(c, r, Mt, Nt, bytes)


def e_fcl_gemm(r, c, Mt, Nt, Kt, impl='sw'):
    e_fcl_comp = r * c * e_comp(Mt, Nt, Kt)
    return (e_fcl_comp + e_fcl_comm(r, c, Nt, Kt) +
            e_reduction(r, c, Mt, Nt, impl=impl))


def e_fcl_comm_brkdn(r, c, Nt, Kt):
    # mirrors e_fcl_comm: r * sum_{i=0}^{c-1} bytes * e_l2_to_clu(i+1)
    bytes = Nt * Kt * PREC
    load_brkdn = fit.zero_energy_brkdn()
    for i in range(c):
        load_brkdn = fit.add_energy_brkdn(
            load_brkdn,
            fit.scale_energy_breakdown(fit.e_l2_to_clu_brkdn(i + 1), bytes),
        )
    return fit.scale_energy_breakdown(load_brkdn, r)


def e_reduction_brkdn(r, c, Mt, Nt, impl='sw'):
    bytes = Mt * Nt * PREC
    if impl == 'sw':
        return reduction.model.optimal_sw_energy_brkdn(c, r, Mt, Nt, bytes)
    elif impl == 'hw':
        return reduction.model.hw_energy_brkdn(c, r, Mt, Nt, bytes)


def e_fcl_gemm_brkdn(r, c, Mt, Nt, Kt, impl='sw'):
    # mirrors e_fcl_gemm: r*c*e_comp + e_fcl_comm + e_reduction
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(e_comp_brkdn(Mt, Nt, Kt), r * c),
        e_fcl_comm_brkdn(r, c, Nt, Kt),
        e_reduction_brkdn(r, c, Mt, Nt, impl=impl),
    )
