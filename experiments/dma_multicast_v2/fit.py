#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats
import experiments

pd.options.mode.copy_on_write = True
BEAT_BYTES = 64


def fit(x, y):
    # Perform linear regression
    res = stats.linregress(x, y)
    alpha = res.intercept      # α
    beta = res.slope           # β
    r_value = res.rvalue
    stderr_beta = res.stderr
    stderr_alpha = res.intercept_stderr

    # Print results
    print(f"\talpha (intercept): {alpha:.6g}")
    print(f"\tbeta  (slope)    : {beta:.6g}")
    print(f"\tR^2              : {r_value**2:.6g}")
    print(f"\tSE(beta)         : {stderr_beta:.6g}")
    print(f"\tSE(alpha)        : {stderr_alpha:.6g}")

    # Plot results
    plt.figure()
    plt.scatter(x, y, s=12)
    xline = np.linspace(x.min(), x.max(), 200)
    yline = alpha + beta * xline
    plt.plot(xline, yline, linewidth=2)
    plt.xlabel('size [B]')
    plt.ylabel('cycles')
    plt.title("Linear fit: cycles = alpha + beta * X")
    # plt.show()


def fit_hw(df):
    # Retrieve only single-row experiments (fitted model should generalize to multi-row)
    df = df[df['n_rows'] == 1]
    df['cycles'] = df['results'].apply(experiments.hw_cycles)

    # Fit data
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['cycles'].to_numpy()
    print("Fit transfer time for HW multicast:")
    fit(x, y)


def fit_seq(df):
    # Retrieve 1-batch experiments
    df['n_batches'] = df['size'] // df['batch']
    df_no = df[df['n_batches'] == 1]

    # Get cycles for non-overlapped batch (batch 0, cluster 0)
    df_no['no_batch_cycles'] = df_no.apply(
        lambda row: experiments.seq_batch_cycles(
            row['results'], batch_idx=0, cluster_idx=0),
        axis=1
    )

    # Fit non-overlapped batch data
    x = df_no['batch'].to_numpy() / BEAT_BYTES
    y = df_no['no_batch_cycles'].to_numpy()
    print("Fit non-overlapped batch time for sequential multicast:")
    fit(x, y)

    # Retrieve 2-batch experiments
    df_o = df[df['n_batches'] == 2]

    # Get cycles for overlapped batch (batch 1, cluster 0)
    df_o['o_batch_cycles'] = df_o.apply(
        lambda row: experiments.seq_batch_cycles(
            row['results'], batch_idx=1, cluster_idx=0),
        axis=1
    )

    # Fit overlapped batch data
    x = df_o['batch'].to_numpy() / BEAT_BYTES
    y = df_o['o_batch_cycles'].to_numpy()
    print("Fit overlapped batch time for sequential multicast:")
    fit(x, y)


def fit_tree(df):
    # Get cycles of cluster to cluster and memory to cluster transfers
    df['c2c_cycles'] = df['results'].apply(experiments.tree_c2c_cycles)
    df['m2c_cycles'] = df['results'].apply(experiments.tree_m2c_cycles)

    # Fit cluster to cluster data
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['c2c_cycles'].to_numpy()
    print("Fit cluster-to-cluster transfer time for tree multicast:")
    fit(x, y)

    # Fit memory to cluster data
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['m2c_cycles'].to_numpy()
    print("Fit memory-to-cluster transfer time for tree multicast:")
    fit(x, y)


def main():
    df = experiments.results()

    seq = df[df['impl'] == 'seq']
    fit_seq(seq)

    tree = df[df['impl'] == 'tree']
    fit_tree(tree)

    hw = df[df['impl'] == 'hw']
    fit_hw(hw)


if __name__ == '__main__':
    main()
