#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from functools import cache
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats
from reduction import experiments

pd.options.mode.copy_on_write = True
BEAT_BYTES = 64


def fit(x, y, quiet=True):
    # Perform linear regression
    res = stats.linregress(x, y)
    alpha = res.intercept      # α
    beta = res.slope           # β
    r_value = res.rvalue
    stderr_beta = res.stderr
    stderr_alpha = res.intercept_stderr

    if not quiet:
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
        plt.show()

    # Return results
    return alpha, beta


@cache
def fit_tree_dma(df=None, quiet=True):
    # Get experiment data
    if df is None:
        df = experiments.results()
        df = df[df['impl'] == 'tree']

    # Retrieve only single-row and single-batch experiments (fitted model should generalize)
    df = df[df['n_rows'] == 1]
    df['n_batches'] = df['size'] // df['batch']
    df = df[df['n_batches'] == 1]

    # Fit data
    df['dma_cycles'] = df['results'].apply(experiments.tree_dma_cycles)
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['dma_cycles'].to_numpy()
    if not quiet:
        print("Fit DMA transfer time for tree reduction:")
    return fit(x, y, quiet=quiet)


@cache
def fit_tree_compute(df=None, quiet=True):
    # Get experiment data
    if df is None:
        df = experiments.results()
        df = df[df['impl'] == 'tree']

    # Retrieve only single-row and single-batch experiments (fitted model should generalize)
    df = df[df['n_rows'] == 1]
    df['n_batches'] = df['size'] // df['batch']
    df = df[df['n_batches'] == 1]

    # Fit data
    df['comp_cycles'] = df['results'].apply(experiments.tree_compute_cycles)
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['comp_cycles'].to_numpy()
    if not quiet:
        print("Fit compute time for tree reduction:")
    return fit(x, y, quiet=quiet)


@cache
def fit_hw(df=None, quiet=True):
    # Get experiment data
    if df is None:
        df = experiments.results()
        df = df[df['impl'] == 'hw']

    # Retrieve only single-row experiments (fitted model should generalize to multi-row)
    df = df[df['n_rows'] == 1]

    # Fit data
    df['cycles'] = df['results'].apply(experiments.hw_cycles)
    x = df['size'].to_numpy() / BEAT_BYTES
    y = df['cycles'].to_numpy()
    if not quiet:
        print("Fit runtime for hw reduction:")
    return fit(x, y, quiet=quiet)


def main():
    df = experiments.results()

    tree = df[df['impl'] == 'tree']
    fit_tree_dma(tree, quiet=False)
    fit_tree_compute(tree, quiet=False)

    # hw = df[df['impl'] == 'hw']
    # fit_hw(hw, quiet=False)


if __name__ == '__main__':
    main()
