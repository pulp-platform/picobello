#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

from math import isqrt, sqrt, log2, ceil
from summa_gemm.fit import e_clu_to_clu, e_l2_to_clu, EN_R_L1, EN_R_R, EN_L1_R
import summa_gemm.fit as fit

# N: num clusters
# L: num beats in transfer
# B: num beats in batch
# delta: num synchronization overhead cycles

BEAT_BYTES = 64
SEQ_ALPHA = 30
DELTA = 36
HW_ALPHA = 30
TREE_M2C_ALPHA = 30
TREE_C2C_ALPHA = 17


def nearest_divisors(divisor, dividend):
    from bisect import bisect_left

    # 1) Enumerate all positive divisors of dividend
    divs = set()
    r = int(isqrt(int(dividend)))
    for d in range(1, r + 1):
        if dividend % d == 0:        # d divides dividend
            divs.add(d)              # add the small factor
            divs.add(dividend // d)  # add the paired large factor
    divs = sorted(divs)              # sort them ascending

    # 2) Binary search to locate where x would be inserted
    i = bisect_left(divs, divisor)  # first index with divs[i] >= divisor

    # 3) Pick neighbors around divisor
    lower = divs[i - 1] if i > 0 and divs[i - 1] <= divisor else None
    upper = divs[i] if i < len(divs) else None
    return lower, upper


# N1: num cols, N2: num rows
def seq_runtime(N1, N2, L, B, delta=DELTA, alpha=SEQ_ALPHA, alpha1=SEQ_ALPHA):
    n_batches = L // B
    n_iters_row = n_batches - 1 + (N1 - 1)
    n_iters_col = n_batches - 1 + (N2 - 1) if N2 > 1 else 0
    n_iters = n_iters_row + n_iters_col
    return (alpha1 + B) + n_iters * (alpha + B + delta)


def optimal_batch_size(N1, N2, L, delta=DELTA, alpha=SEQ_ALPHA):
    if N2 > 1:
        real_B = sqrt(L * (alpha + delta) / (N1 + N2 - 1))
    else:
        real_B = sqrt(L * (alpha + delta) / (N1 - 1))
    lower_B, upper_B = nearest_divisors(real_B, L)
    assert (lower_B is None) or (lower_B > 0)
    assert (upper_B is None) or (upper_B <= L)
    if lower_B is None:
        return upper_B
    elif upper_B is None:
        return lower_B
    else:
        T_lower_B = seq_runtime(N1, N2, L, lower_B, delta, alpha)
        T_upper_B = seq_runtime(N1, N2, L, upper_B, delta, alpha)
        if T_lower_B < T_upper_B:
            return lower_B
        else:
            return upper_B


def optimal_seq_runtime(N1, N2, L, delta=DELTA, alpha=SEQ_ALPHA, alpha1=SEQ_ALPHA):
    B_opt = optimal_batch_size(N1, N2, L, delta, alpha)
    return seq_runtime(N1, N2, L, B_opt, delta, alpha, alpha1)


def hw_runtime(N1, N2, L):
    if N2 > 1:
        return HW_ALPHA + L + N1 - 1 + N2 - 1
    else:
        return HW_ALPHA + L + N1 - 1


def tree_runtime(N1, N2, L, delta=DELTA):
    m2c_transfer_cycles = TREE_M2C_ALPHA + L

    # C2C alpha depends on the distance between the clusters.
    # On our system we have two cycles latency per hop.
    c2c_transfer_cycles = 0
    for i in range(ceil(log2(N1))):
        dist = N1 / (2 ** (i + 1))
        c2c_transfer_cycles += TREE_C2C_ALPHA + 2 * dist + L
    for i in range(ceil(log2(N2))):
        dist = N2 / (2 ** (i + 1))
        c2c_transfer_cycles += TREE_C2C_ALPHA + 2 * dist + L

    delta_cycles = delta * (log2(N1 * N2) - 1)
    return m2c_transfer_cycles + c2c_transfer_cycles + delta_cycles


def optimal_sw_runtime(N1, N2, L, delta=DELTA, alpha=SEQ_ALPHA, alpha1=SEQ_ALPHA):
    T_seq = optimal_seq_runtime(N1, N2, L, delta, alpha, alpha1)
    T_tree = tree_runtime(N1, N2, L, delta)
    return min(T_seq, T_tree)


def hw_energy(dim, bytes):
    return bytes * (e_l2_to_clu(1) + EN_L1_R + (dim - 1) * (EN_R_R + EN_R_L1))


def seq_energy(dim, bytes):
    return bytes * (e_l2_to_clu(1) + (dim - 1) * e_clu_to_clu(1))


def tree_energy(dim, bytes):
    c2c_energy = 0
    for i in range(ceil(log2(dim))):
        dist = dim / (2 ** (i + 1))
        c2c_energy += (2 ** i) * e_clu_to_clu(dist)
    return bytes * (e_l2_to_clu(1) + c2c_energy)


def optimal_sw_energy(dim, bytes):
    n = ceil(bytes / BEAT_BYTES)
    T_seq = optimal_seq_runtime(dim, 1, n)
    T_tree = tree_runtime(dim, 1, n)
    if T_seq < T_tree:
        return seq_energy(dim, bytes)
    else:
        return tree_energy(dim,  bytes)


def seq_energy_brkdn(dim, bytes):
    # mirrors: bytes * (e_l2_to_clu(1) + (dim - 1) * e_clu_to_clu(1))
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(fit.e_l2_to_clu_brkdn(1), bytes),
        fit.scale_energy_breakdown(fit.e_clu_to_clu_brkdn(1), bytes * (dim - 1)),
    )


def tree_energy_brkdn(dim, bytes):
    # mirrors: bytes * (e_l2_to_clu(1) + sum_i 2^i * e_clu_to_clu(dist_i))
    c2c_brkdn = fit.zero_energy_brkdn()
    for i in range(ceil(log2(dim))):
        dist = dim / (2 ** (i + 1))
        c2c_brkdn = fit.add_energy_brkdn(
            c2c_brkdn,
            fit.scale_energy_breakdown(fit.e_clu_to_clu_brkdn(dist), 2 ** i),
        )
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(fit.e_l2_to_clu_brkdn(1), bytes),
        fit.scale_energy_breakdown(c2c_brkdn, bytes),
    )


def optimal_sw_energy_brkdn(dim, bytes):
    n = ceil(bytes / BEAT_BYTES)
    T_seq = optimal_seq_runtime(dim, 1, n)
    T_tree = tree_runtime(dim, 1, n)
    if T_seq < T_tree:
        return seq_energy_brkdn(dim, bytes)
    else:
        return tree_energy_brkdn(dim, bytes)


def hw_energy_brkdn(dim, bytes):
    # mirrors: bytes * (e_l2_to_clu(1) + (dim - 1) * (EN_R_R + EN_R_L1))
    # (EN_R_R + EN_R_L1) = 1 router hop + 1 TCDM write (no L1→Router egress in HW path)
    recv_brkdn = fit.zero_energy_brkdn()
    recv_brkdn["link_to_link"] = dim - 1
    recv_brkdn["tcdm_write"] = dim - 1
    recv_brkdn["dma_st"] = 1
    return fit.add_energy_brkdn(
        fit.scale_energy_breakdown(fit.e_l2_to_clu_brkdn(1), bytes),
        fit.scale_energy_breakdown(recv_brkdn, bytes),
    )
