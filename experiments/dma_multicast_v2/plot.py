#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import argparse
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import model
import experiments

pd.options.mode.copy_on_write = True


def plot1(df):
    """Plot actual vs. expected runtime heatmaps."""

    # Get only sequential implementation results
    df = df[(df['impl'] == 'seq') & (df['n_rows'] == 1)]

    # Add actual and expected runtimes to the dataframe
    df['act'] = df.apply(
        lambda row: experiments.seq_cycles(
            row['results'], int(row['size'] // row['batch']), row['n_rows']),
        axis=1
    )
    df['exp'] = df.apply(
        lambda row: model.seq_runtime(4, 1, row['size'] // 64, row['batch'] // 64),
        axis=1
    )

    # Create dataframe for actual runtime heatmap
    df_act = df.drop(columns=['exp'])
    df_act = df_act.pivot(index='size', columns='batch', values='act')
    sizes = df_act.index
    batches = df_act.columns

    # Create dataframe for expected runtime heatmap
    df_exp = df.drop(columns=['act'])
    df_exp = df_exp.pivot(index='size', columns='batch', values='exp')
    sizes = df_exp.index
    batches = df_exp.columns

    # Plot actual and expected heatmaps
    fig, ax = plt.subplots(1, 2)
    cmap = mpl.colormaps['plasma']
    cmap = mpl.colors.ListedColormap(cmap(np.linspace(0.15, 0.85, 128)))
    sns.heatmap(
        df_act,
        cmap=cmap,
        annot=True,
        fmt=".0f",
        cbar=True,
        xticklabels=batches,
        yticklabels=sizes,
        ax=ax[0]
    )
    sns.heatmap(
        df_exp,
        cmap=cmap,
        annot=True,
        fmt=".0f",
        cbar=True,
        xticklabels=batches,
        yticklabels=sizes,
        ax=ax[1]
    )
    plt.tight_layout()
    plt.show()


def plot2(df):
    """Plot actual and expected runtimes."""

    # Get actual runtimes
    def cycles(row):
        if row['impl'] == 'seq':
            return experiments.seq_cycles(row['results'], int(row['size'] // row['batch']),
                                          row['n_rows'])
        elif row['impl'] == 'tree':
            return experiments.tree_cycles(row['results'], row['n_rows'])
        elif row['impl'] == 'hw':
            return experiments.hw_cycles(row['results'])
    df['cycles'] = df.apply(cycles, axis=1)

    # Select optimal configuration (optimal n_batches) for sequential pipelined runs
    df = df.loc[df.groupby(['impl', 'size', 'n_rows'])['cycles'].idxmin()] \
        .sort_values(['impl', 'n_rows', 'size']) \
        .reset_index(drop=True)

    # Calculate expected runtimes
    def exp_cycles(row):
        if row['impl'] == 'seq':
            cycles = model.seq_runtime(4, row['n_rows'], row['size'] // 64, row['batch'] // 64)
        elif row['impl'] == 'tree':
            cycles = model.tree_runtime(4, row['n_rows'], row['size'] // 64)
        elif row['impl'] == 'hw':
            cycles = model.hw_runtime(4, row['size'] // 64)
        return int(cycles)
    df['exp_cycles'] = df.apply(exp_cycles, axis=1)

    # Drop results column for cleaner output
    df = df.drop(columns=['results'])
    print(df)

    # Choose consistent colors and markers for the plots
    colors = {"seq": "C0", "tree": "C1", "hw": "C2"}
    markers = {"actual": "o", "expected": "x"}

    # Plot measured runtimes
    _, ax = plt.subplots(2, 2)

    def plot_runtime_vs_speedup(ax, n_rows):
        res = df[df['n_rows'] == n_rows]
        sizes = res['size'].unique()
        ax.scatter(
            sizes, res[res['impl'] == 'seq']['cycles'], label='Actual (seq)',
            marker=markers['actual'], color=colors['seq']
        )
        ax.scatter(
            sizes, res[res['impl'] == 'tree']['cycles'], label='Actual (tree)',
            marker=markers['actual'], color=colors['tree']
        )
        ax.scatter(
            sizes, res[res['impl'] == 'hw']['cycles'], label='Actual (hw)',
            marker=markers['actual'], color=colors['hw']
        )

        # Plot expected runtimes
        ax.scatter(
            sizes, res[res['impl'] == 'seq']['exp_cycles'], label='Expected (seq)',
            marker=markers['expected'], color=colors['seq']
        )
        ax.scatter(
            sizes, res[res['impl'] == 'tree']['exp_cycles'], label='Expected (tree)',
            marker=markers['expected'], color=colors['tree']
        )
        ax.scatter(
            sizes, res[res['impl'] == 'hw']['exp_cycles'], label='Expected (hw)',
            marker=markers['expected'], color=colors['hw']
        )

        # Plot model line for sequential runtime. Find monotone non-decreasing lower fit.
        x = np.arange(sizes.min(), sizes.max(), 64)
        x_ext = np.arange(sizes.min(), sizes.max() + 1024, 64)
        y = [model.optimal_seq_runtime(4, n_rows, e // 64) for e in x_ext]
        y_monotone = []
        x_monotone = []
        for i, e in enumerate(y):
            accept = True
            for j in range(i, len(y)):
                if y[j] < e:
                    accept = False
                    break
            if accept and i < len(x):
                y_monotone.append(y[i])
                x_monotone.append(x[i])
        ax.plot(x_monotone, y_monotone, label='Model (seq)', color=colors['seq'])

        # Plot model line for tree runtime
        y = [model.tree_runtime(4, n_rows, e // 64) for e in x]
        ax.plot(x, y, label='Model (tree)', color=colors['tree'])

        # Plot model line for hardware runtime
        y = [model.hw_runtime(4, e // 64) for e in x]
        ax.plot(x, y, label='Model (hw)', color=colors['hw'])

        ax.set_xticks(sizes, [str(size) if size != 2048 else "" for size in sizes])
        ax.set_xlabel('Size')
        ax.set_ylabel('Runtime')
        ax.grid(True, linestyle='--', alpha=0.4)
        ax.legend()

    plot_runtime_vs_speedup(ax[0][0], n_rows=1)
    plot_runtime_vs_speedup(ax[0][1], n_rows=2)
    plot_runtime_vs_speedup(ax[1][0], n_rows=4)
    plt.tight_layout()
    plt.show()


def plot3(df):
    """Plot runtime dependency with delta."""

    # Get only hardware implementation results
    df = df[df['impl'] == 'hw']

    # Retrieve single-row experiments
    n_rows = 1
    df = df[df['n_rows'] == n_rows]

    # Get actual runtimes
    df['cycles'] = df['results'].apply(experiments.hw_cycles)

    # Choose consistent colors and markers for the plots
    colors = {"seq": "C1", "hw": "C2"}

    # Plot measured runtimes
    _, ax = plt.subplots()

    # Plot model line for hardware runtime
    x = np.arange(df['size'].min(), df['size'].max(), 64)
    y = [model.hw_runtime(4, e // 64) for e in x]
    ax.plot(x, y, label='hw', color=colors['hw'])

    # Plot model lines for sequential runtime (varying delta).
    for alpha_delta in range(model.DELTA + model.SEQ_ALPHA, -1, -8):
        alpha = alpha_delta // 2
        delta = alpha_delta - alpha
        x_ext = np.arange(df['size'].min(), df['size'].max() + 1024, 64)
        y = [model.optimal_seq_runtime(4, n_rows, e // 64, delta, alpha) for e in x_ext]
        y_monotone = []
        x_monotone = []
        for i, e in enumerate(y):
            accept = True
            for j in range(i, len(y)):
                if y[j] < e:
                    accept = False
                    break
            if accept and i < len(x):
                y_monotone.append(y[i])
                x_monotone.append(x[i])
        ax.plot(x_monotone, y_monotone, label=f'seq (delta={delta}, alpha={alpha})',
                color=colors['seq'])

    ax.set_xticks(df['size'], [str(size) if size != 2048 else "" for size in df['size']])
    ax.set_xlabel('Size')
    ax.set_ylabel('Runtime')
    ax.grid(True, linestyle='--', alpha=0.4)
    ax.legend()

    plt.tight_layout()
    plt.show()


def main():
    # Load results
    df = experiments.results()

    # Parse arguments
    functions = [plot1, plot2, plot3]
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
        plot1(df)
    if requested('plot2'):
        plot2(df)
    if requested('plot3'):
        plot3(df)


if __name__ == "__main__":
    main()
