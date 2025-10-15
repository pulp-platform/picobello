#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import argparse
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
import pandas as pd
from summa_gemm import model


def plot1(show=True):
    # Get data
    mesh_sizes = [4, 8, 16, 32, 64, 128, 256]
    t_comm_sw = []
    t_comm_hw = []
    t_compute = []
    Mt = model.max_square_problem_size()
    for c in mesh_sizes:
        r = c
        t_comm_sw.append(model.t_summa_comm(r, c, Mt, Mt, Mt, impl='sw'))
        t_comm_hw.append(model.t_summa_comm(r, c, Mt, Mt, Mt, impl='hw'))
        t_compute.append(model.t_comp(Mt, Mt, Mt))

    df = pd.DataFrame({
        'size': mesh_sizes,
        't_comm_sw': t_comm_sw,
        't_comm_hw': t_comm_hw,
        't_compute': t_compute,
    })

    # Prepare critical paths and speedups
    df['t_sw'] = df[['t_comm_sw', 't_compute']].max(axis=1)
    df['t_hw'] = df[['t_comm_hw', 't_compute']].max(axis=1)
    df['speedup'] = df['t_sw'] / df['t_hw']

    # Plot curves
    fig, ax = plt.subplots()
    ax.plot(mesh_sizes, t_comm_sw, marker='o', label='$T_{comm}$ (sw)')
    ax.plot(mesh_sizes, t_comm_hw, marker='s', label='$T_{comm}$ (hw)')
    ax.plot(mesh_sizes, t_compute, marker='^', label='$T_{comp}$')
    ax.set_xticks(mesh_sizes)
    ax.set_xscale('log', base=2)
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, pos: f"{int(x)}x{int(x)}"))
    ax.set_xlabel('Mesh size')
    ax.set_ylabel('Runtime [cycles]')
    ax.grid(True, which="both", alpha=0.5)
    ax.legend()
    fig.tight_layout()

    # Annotate plot with speedup arrows (when speedup > 1)
    keys = ['size', 't_comm_sw', 't_comm_hw', 't_compute', 'speedup']
    for x, sw, hw, t, sp in df[keys].itertuples(index=False, name=None):
        if sp > 1.0:
            y0 = sw
            y1 = max(hw, t)

            # Double-headed arrow from t_comm_sw to max(t_comm_hw, t_compute)
            ax.annotate(
                "",
                xy=(x, y1),
                xytext=(x, y0),
                arrowprops=dict(arrowstyle="<->", lw=1.2),
                annotation_clip=False,
            )

            # Arithmetic midpoint for linear scale
            y_mid = 0.5 * (y0 + y1)

            offset = 3
            if sp > 1.2:
                ha = "right"
                xytext = (-offset, 0)
            else:
                ha = "left"
                xytext = (offset, 0)
            ax.annotate(
                f"{sp:.2f}$\\times$",
                xy=(x, y_mid),
                xytext=xytext,
                textcoords="offset points",
                ha=ha,
                va="center",
                rotation=90 if ax.get_yscale() == "log" else 0,  # optional
                annotation_clip=True,
            )

    if show:
        plt.show()

    return df


def plot2(show=True):
    # Get data
    mesh_sizes = [4, 8, 16, 32, 64, 128, 256]
    Mt = model.max_square_problem_size()
    t_sw = []
    t_hw = []
    for size in mesh_sizes:
        t_sw.append(model.t_fcl_gemm(size, size, Mt, Mt, Mt, impl='sw'))
        t_hw.append(model.t_fcl_gemm(size, size, Mt, Mt, Mt, impl='hw'))
    df = pd.DataFrame({
        'size': mesh_sizes,
        't_sw': t_sw,
        't_hw': t_hw,
    })

    # Calculate speedup
    df['speedup'] = df['t_sw'] / df['t_hw']

    # Plot
    fig, ax = plt.subplots()
    ax.bar(df['size'].astype(str), df['speedup'])
    ax.set_xlabel('Mesh size')
    ax.set_ylabel('Speedup')
    ax.grid(axis='y', alpha=0.5)
    fig.tight_layout()

    if show:
        plt.show()

    return df


def main():
    # Parse arguments
    functions = [plot1, plot2]
    parser = argparse.ArgumentParser(description='Plot wide multicast results.')
    parser.add_argument(
        'plots',
        nargs='*',
        default='all',
        choices=[f.__name__ for f in functions] + ['all'],
        help='Plots to generate.'
    )
    args = parser.parse_args()

    # Helper function to check if a plot was requested on the command line
    def requested(plot):
        return plot in args.plots or 'all' in args.plots

    # Generate plots
    if requested('plot1'):
        plot1()
    if requested('plot2'):
        plot2()


if __name__ == "__main__":
    main()