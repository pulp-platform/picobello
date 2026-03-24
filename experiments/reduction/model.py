#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

from math import log2, sqrt, isqrt, ceil
from reduction import fit
from summa_gemm.fit import EN_L1_R, EN_R_L1, e_clu_to_clu, e_clu_to_l2, e_sw_red_clu, e_hw_red_clu
import summa_gemm.fit as sg_fit

BEAT_BYTES = 64
DELTA = 30


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


def hw_runtime(c, r, n):
    hw_alpha, hw_beta = fit.fit_hw()
    t_hw = hw_alpha + n * hw_beta
    if r > 1:
        return 2 * t_hw
    else:
        return t_hw


def seq_runtime(c, r, n, k, delta=DELTA):
    batch = int(n // k)
    dma_alpha, _ = fit.fit_seq_dma()
    comp_alpha, _ = fit.fit_seq_compute()
    t_comp = comp_alpha + batch * 1.16
    t_dma = dma_alpha + batch * 1
    t_max = max(t_comp, t_dma)
    # print(t_dma * 5, t_comp * 5, t_max * 5)
    n_iters = 1 + 2 * (c - 2) + k
    if r > 1:
        n_iters += 1 + 2 * (r - 2) + k
    # First approximation model assumes compute and dma take roughly the same time
    delta = 4 * r + 28
    return n_iters * (t_max + delta) - delta


def optimal_seq_k(c, r, n, delta=DELTA):
    comp_alpha, _ = fit.fit_seq_compute()
    if r > 1:
        real_k = sqrt(n * (2 * (c + r) - 7) / (2 * (delta + comp_alpha)))
    else:
        real_k = sqrt(n * (2 * c - 3) / (delta + comp_alpha))
    lower_k, upper_k = nearest_divisors(real_k, n)
    assert (lower_k is None) or (lower_k > 0)
    assert (upper_k is None) or (upper_k <= n)
    if lower_k is None:
        return upper_k
    elif upper_k is None:
        return lower_k
    else:
        T_lower_k = seq_runtime(c, r, n, lower_k, delta)
        T_upper_k = seq_runtime(c, r, n, upper_k, delta)
        if T_lower_k < T_upper_k:
            return lower_k
        else:
            return upper_k


def optimal_seq_runtime(c, r, n, delta=DELTA):
    k_opt = optimal_seq_k(c, r, n, delta)
    return seq_runtime(c, r, n, k_opt, delta)


def tree_runtime(c, r, n, k, delta=DELTA):
    batch = int(n // k)
    dma_alpha, _ = fit.fit_tree_dma()
    comp_alpha, _ = fit.fit_tree_compute()
    t_comp = comp_alpha + batch * 1.16
    t_dma = dma_alpha + batch * 1
    t_max = max(t_comp, t_dma)
    # print(t_dma * 5, t_comp * 5, t_max * 5)
    n_levels = log2(c * r)
    return n_levels * (t_dma + (k - 1) * (delta + t_max) + delta + t_comp)


def optimal_tree_k(c, r, n, delta=DELTA):
    dma_alpha, _ = fit.fit_tree_dma()
    comp_alpha, _ = fit.fit_tree_compute()
    real_k = sqrt(n / (delta + max(dma_alpha, comp_alpha)))
    lower_k, upper_k = nearest_divisors(real_k, n)
    assert (lower_k is None) or (lower_k > 0)
    assert (upper_k is None) or (upper_k <= n)
    if lower_k is None:
        return upper_k
    elif upper_k is None:
        return lower_k
    else:
        T_lower_k = tree_runtime(c, r, n, lower_k, delta)
        T_upper_k = tree_runtime(c, r, n, upper_k, delta)
        if T_lower_k < T_upper_k:
            return lower_k
        else:
            return upper_k


def optimal_tree_runtime(c, r, n, delta=DELTA):
    k_opt = optimal_tree_k(c, r, n, delta)
    return tree_runtime(c, r, n, k_opt, delta)


def optimal_sw_runtime(c, r, n, delta=DELTA):
    T_seq = optimal_seq_runtime(c, r, n, delta)
    T_tree = optimal_tree_runtime(c, r, n, delta)
    return min(T_seq, T_tree)


def seq_energy(c, r, m, n, bytes):
    row_energy = (c-1) * (e_clu_to_clu(1)) * r
    col_energy = (r-1) * (e_clu_to_clu(1))
    red_energy = (c + r - 2) * e_sw_red_clu(m, n)
    return bytes * (row_energy + col_energy + e_clu_to_l2(1)) + red_energy


def tree_energy(c, r, m, n, bytes):
    c2c_energy = 0
    for i in range(ceil(log2(c))):
        dist = 2 ** i
        c2c_energy += 2**(ceil(log2(c))-i-1) * (bytes * e_clu_to_clu(dist) + e_sw_red_clu(m, n))
    c2c_energy *= r
    for i in range(ceil(log2(r))):
        dist = 2 ** i
        c2c_energy += 2**(ceil(log2(r))-i-1) * (bytes * e_clu_to_clu(dist) + e_sw_red_clu(m, n))
    return c2c_energy + bytes * e_clu_to_l2(1)


def optimal_sw_energy(c, r, m, n, bytes):
    n = ceil(bytes / BEAT_BYTES)
    T_seq = optimal_seq_runtime(c, r, n)
    T_tree = optimal_tree_runtime(c, r, n)
    if T_seq < T_tree:
        return seq_energy(c, r, m, n, bytes)
    else:
        return tree_energy(c, r, m, n, bytes)


def hw_energy(c, r, m, n, bytes):
    row_energy = r * (bytes * (e_clu_to_l2(1) + EN_L1_R + EN_R_L1) + (c-1) * e_hw_red_clu(m, n))
    col_energy = bytes * (e_clu_to_l2(1) + EN_L1_R + EN_R_L1) + (r-1) * e_hw_red_clu(m, n)

    return row_energy + col_energy + e_clu_to_l2(1) * bytes


def seq_energy_brkdn(c, r, m, n, bytes):
    # mirrors: bytes*(row_energy + col_energy + e_clu_to_l2(1)) + red_energy
    # row_energy = (c-1)*r * e_clu_to_clu(1), col_energy = (r-1) * e_clu_to_clu(1)
    return sg_fit.add_energy_brkdn(
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_clu_brkdn(1), bytes * (c - 1) * r),
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_clu_brkdn(1), bytes * (r - 1)),
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_l2_brkdn(1), bytes),
        sg_fit.scale_energy_breakdown(sg_fit.e_sw_red_clu_brkdn(m, n), c + r - 2),
    )


def tree_energy_brkdn(c, r, m, n, bytes):
    # mirrors tree_energy: c2c_energy (scaled by r) + col c2c + bytes*e_clu_to_l2(1)
    c2c_brkdn = sg_fit.zero_energy_brkdn()
    for i in range(ceil(log2(c))):
        dist = 2 ** i
        count = 2 ** (ceil(log2(c)) - i - 1)
        c2c_brkdn = sg_fit.add_energy_brkdn(
            c2c_brkdn,
            sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_clu_brkdn(dist), bytes * count),
            sg_fit.scale_energy_breakdown(sg_fit.e_sw_red_clu_brkdn(m, n), count),
        )
    c2c_brkdn = sg_fit.scale_energy_breakdown(c2c_brkdn, r)
    for i in range(ceil(log2(r))):
        dist = 2 ** i
        count = 2 ** (ceil(log2(r)) - i - 1)
        c2c_brkdn = sg_fit.add_energy_brkdn(
            c2c_brkdn,
            sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_clu_brkdn(dist), bytes * count),
            sg_fit.scale_energy_breakdown(sg_fit.e_sw_red_clu_brkdn(m, n), count),
        )
    return sg_fit.add_energy_brkdn(
        c2c_brkdn,
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_l2_brkdn(1), bytes),
    )


def optimal_sw_energy_brkdn(c, r, m, n, bytes):
    n_beats = ceil(bytes / BEAT_BYTES)
    T_seq = optimal_seq_runtime(c, r, n_beats)
    T_tree = optimal_tree_runtime(c, r, n_beats)
    if T_seq < T_tree:
        return seq_energy_brkdn(c, r, m, n, bytes)
    else:
        return tree_energy_brkdn(c, r, m, n, bytes)


def hw_energy_brkdn(c, r, m, n, bytes):
    # mirrors hw_energy:
    #   row_energy = r * (bytes*(e_clu_to_l2(1) + EN_L1_R + EN_R_L1) + (c-1)*e_hw_red_clu(m,n))
    #   col_energy =     bytes*(e_clu_to_l2(1) + EN_L1_R + EN_R_L1) + (r-1)*e_hw_red_clu(m,n)
    #   + e_clu_to_l2(1)
    # EN_L1_R = EN_L1_L2 → dma_st; EN_R_L1 → tcdm_write
    en_l1_r_brkdn = sg_fit.zero_energy_brkdn()
    en_l1_r_brkdn["dma_st"] = 1        # EN_L1_R ≡ EN_L1_L2
    en_r_l1_brkdn = sg_fit.zero_energy_brkdn()
    en_r_l1_brkdn["tcdm_write"] = 1    # EN_R_L1

    # bytes*(e_clu_to_l2(1) + EN_L1_R + EN_R_L1)
    per_byte_brkdn = sg_fit.add_energy_brkdn(
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_l2_brkdn(1), bytes),
        sg_fit.scale_energy_breakdown(en_l1_r_brkdn, bytes),
        sg_fit.scale_energy_breakdown(en_r_l1_brkdn, bytes),
    )

    per_cluster_row = sg_fit.add_energy_brkdn(
        per_byte_brkdn,
        sg_fit.scale_energy_breakdown(sg_fit.e_hw_red_clu_brkdn(m, n), c - 1),
    )
    col_brkdn = sg_fit.add_energy_brkdn(
        per_byte_brkdn,
        sg_fit.scale_energy_breakdown(sg_fit.e_hw_red_clu_brkdn(m, n), r - 1),
    )
    return sg_fit.add_energy_brkdn(
        sg_fit.scale_energy_breakdown(per_cluster_row, r),
        col_brkdn,
        sg_fit.scale_energy_breakdown(sg_fit.e_clu_to_l2_brkdn(1), bytes),
    )
