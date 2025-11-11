#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import math
import dma_multicast_v2 as multicast
import reduction

PREC = 8  # in bytes
BEAT_BYTES = 64  # in bytes
UTIL = 0.981  # median utilization from https://arxiv.org/pdf/2506.10921
PEAKPERF = 16  # DPflop/cycle on a single cluster
L1SIZE = 16 * 1024  # in bytes


def beats(bytes):
    return math.ceil(bytes / BEAT_BYTES)


def max_square_problem_size():
    return math.floor(math.sqrt(L1SIZE / (6 * PREC)))


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
