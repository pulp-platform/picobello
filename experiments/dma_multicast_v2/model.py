#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from math import isqrt, sqrt, log2

# N: num clusters
# L: num beats in transfer
# B: num beats in batch
# delta: num synchronization overhead cycles

BEAT_BYTES = 64
SEQ_ALPHA = 30
# TODO(colluca): in reality delta depends on n_rows, and the arrival times of all clusters
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
    c2c_transfer_cycles = (TREE_C2C_ALPHA + L) * log2(N1 * N2)
    delta_cycles = delta * (log2(N1 * N2) - 1)
    return m2c_transfer_cycles + c2c_transfer_cycles + delta_cycles
