#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from math import log2, sqrt, isqrt
from reduction import fit

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
    hw_alpha, _ = fit.fit_hw()
    beta = 1
    if r > 1:
        beta = 2
    return hw_alpha + n * beta


def tree_runtime(c, r, n, k, delta=DELTA):
    batch = int(n // k)
    dma_alpha, _ = fit.fit_tree_dma()
    comp_alpha, _ = fit.fit_tree_compute()
    t_comp = comp_alpha + batch * 1
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


# print(5 * tree_runtime(4, 1, 16384 // 64, 2))
