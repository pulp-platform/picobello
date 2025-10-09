#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import matplotlib.pyplot as plt
import numpy as np
from scipy import stats
from barrier import experiments

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


def get_results():
    df = experiments.results()
    df['cycles'] = df['results'].apply(experiments.get_total_cycles)
    return df


def fit_hw(quiet=True):
    print("Hardware barrier:")
    df = get_results()
    df = df[df['impl'] == 'hw']
    x = df['n_clusters'].to_numpy()
    y = df['cycles'].to_numpy()
    return fit(x, y, quiet)


def fit_sw(quiet=True):
    print("Software barrier:")
    df = get_results()
    df = df[df['impl'] == 'sw']
    x = df['n_clusters'].to_numpy()
    y = df['cycles'].to_numpy()
    return fit(x, y, quiet)


def main():
    fit_hw(quiet=False)
    fit_sw(quiet=False)


if __name__ == '__main__':
    main()
