#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import argparse
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from reduction import model, experiments

pd.options.mode.copy_on_write = True
BEAT_BYTES = 64


# Find the monotone non-decreasing lower fit of an oscillating curve
def find_monotone_lower_fit(x, y):
    y_monotone = []
    x_monotone = []
    for i, e in enumerate(y):
        accept = True
        for j in range(i, len(y)):
            if y[j] < e:
                accept = False
                break
        if accept:
            y_monotone.append(y[i])
            x_monotone.append(x[i])
    return x_monotone, y_monotone


def get_actual_cycles(row):
    if row['impl'] == 'seq':
        n_batches = int(row['size'] // row['batch'])
        return experiments.seq_cycles(row['results'], 4, row['n_rows'], n_batches)
    elif row['impl'] == 'tree':
        n_batches = int(row['size'] // row['batch'])
        return experiments.tree_cycles(row['results'], 4, row['n_rows'], n_batches)
    elif row['impl'] == 'hw_simple':
        return experiments.hw_simple_cycles(row['results'])
    elif row['impl'] == 'hw_generic':
        return experiments.hw_generic_cycles(row['results'])


def get_expected_cycles(row):
    if row['impl'] == 'seq':
        cycles = model.optimal_seq_runtime(4, row['n_rows'], row['size'] // BEAT_BYTES)
    elif row['impl'] == 'tree':
        cycles = model.optimal_tree_runtime(4, row['n_rows'], row['size'] // BEAT_BYTES)
    elif row['impl'] == 'hw_generic':
        cycles = model.hw_generic_runtime(4, row['n_rows'], row['size'] // BEAT_BYTES)
    elif row['impl'] == 'hw_simple':
        cycles = model.hw_simple_runtime(4, row['n_rows'], row['size'] // BEAT_BYTES)
    return int(cycles)


def get_expected_batch_size(row):
    if row['impl'] == 'tree':
        optimal_k = model.optimal_tree_k(4, row['n_rows'], row['size'] // BEAT_BYTES)
        return int(row['size'] // optimal_k)
    elif row['impl'] == 'hw':
        return None


# Select optimal configuration (optimal k) for seq and tree runs
def select_best_configs(df):
    return df.loc[df.groupby(['impl', 'size', 'n_rows'])['cycles'].idxmin()] \
        .sort_values(['impl', 'n_rows', 'size']) \
        .reset_index(drop=True)


def seq_runtime_curve(xmin, xmax, c, r):
    x = np.arange(xmin, xmax, 64)
    y = [model.optimal_seq_runtime(c, r, e // BEAT_BYTES) for e in x]
    return x, y


# Filter optimal sequential runtime, by finding the monotone non-decreasing lower fit.
def monotone_seq_runtime_curve(xmin, xmax, c, r):
    x, y = seq_runtime_curve(xmin, xmax, c, r)
    return find_monotone_lower_fit(x, y)


def tree_runtime_curve(xmin, xmax, c, r):
    x = np.arange(xmin, xmax, 64)
    y = [model.optimal_tree_runtime(c, r, e // BEAT_BYTES) for e in x]
    return x, y


# Filter optimal tree runtime, by finding the monotone non-decreasing lower fit.
def monotone_tree_runtime_curve(xmin, xmax, c, r):
    x, y = tree_runtime_curve(xmin, xmax, c, r)
    return find_monotone_lower_fit(x, y)


def hw_generic_runtime_curve(xmin, xmax, c, r):
    x = np.arange(xmin, xmax, 64)
    y = [model.hw_generic_runtime(c, r, e // BEAT_BYTES) for e in x]
    return x, y


def hw_simple_runtime_curve(xmin, xmax, c, r):
    x = np.arange(xmin, xmax, 64)
    y = [model.hw_simple_runtime(c, r, e // BEAT_BYTES) for e in x]
    return x, y


# def sw_runtime_curve(xmin, xmax, n_rows):
#     x = np.arange(xmin, xmax, 64)
#     x, y_seq = seq_runtime_curve(xmin, xmax, n_rows)
#     _, y_tree = tree_runtime_curve(xmin, xmax, n_rows)
#     x, y_min = find_monotone_lower_fit(x, [min(a, b) for a, b in zip(y_seq, y_tree)])
#     return x, y_min


def plot1(y_label=None, hide_x_axis=False, show=True):
    """Plot actual and expected runtimes."""

    # Load single-row results
    c = 4
    r = 1
    df = experiments.results()
    df = df[df['n_rows'] == r]

    # Get expected and actual runtimes
    df['cycles'] = df.apply(get_actual_cycles, axis=1)
    df = select_best_configs(df)
    df['exp_cycles'] = df.apply(get_expected_cycles, axis=1)
    # df['exp_batch'] = df.apply(get_expected_batch_size, axis=1)

    # Drop results column for cleaner output
    df = df.drop(columns=['results'])

    # Choose consistent colors and markers for the plots
    colors = {"seq": "C0", "tree": "C1", "hw_simple": "C2", "hw_generic": "C3"}
    markers = {"expected": "o", "actual": "x"}

    # Create plot
    _, ax = plt.subplots()

    # Plot actual runtimes
    sizes = df['size'].unique()
    ax.scatter(
        sizes, df[df['impl'] == 'seq']['cycles'], label='Actual (seq)',
        marker=markers['actual'], color=colors['seq']
    )
    ax.scatter(
        sizes, df[df['impl'] == 'tree']['cycles'], label='Actual (tree)',
        marker=markers['actual'], color=colors['tree']
    )
    ax.scatter(
        sizes, df[df['impl'] == 'hw_simple']['cycles'], label='Actual (hw_simple)',
        marker=markers['actual'], color=colors['hw_simple']
    )
    # ax.scatter(
    #     sizes, df[df['impl'] == 'hw_generic']['cycles'], label='Actual (hw_generic)',
    #     marker=markers['actual'], color=colors['hw_generic']
    # )

    # # Plot expected runtimes
    # ax.scatter(
    #     sizes, df[df['impl'] == 'tree']['exp_cycles'], label='Expected (tree)',
    #     marker=markers['expected'], color=colors['tree']
    # )
    # ax.scatter(
    #     sizes, df[df['impl'] == 'hw_simple']['exp_cycles'], label='Expected (hw_simple)',
    #     marker=markers['expected'], color=colors['hw_simple']
    # )
    # ax.scatter(
    #     sizes, df[df['impl'] == 'hw_generic']['exp_cycles'], label='Expected (hw_generic)',
    #     marker=markers['expected'], color=colors['hw_generic']
    # )

    # Plot model line for seq runtime
    x, y = monotone_seq_runtime_curve(sizes.min(), sizes.max(), c, r)
    ax.plot(x, y, label='Model (seq)', linestyle='--', color=colors['seq'])

    # Plot model line for tree runtime
    x, y = monotone_tree_runtime_curve(sizes.min(), sizes.max(), c, r)
    ax.plot(x, y, label='Model (tree)', linestyle='--', color=colors['tree'])

    # # Plot model line for hw generic runtime
    # x, y = hw_generic_runtime_curve(sizes.min(), sizes.max(), c, r)
    # ax.plot(x, y, label='Model (hw_generic)', linestyle='--', color=colors['hw_generic'])

    # Plot model line for hw simple runtime
    x, y = hw_simple_runtime_curve(sizes.min(), sizes.max(), c, r)
    ax.plot(x, y, label='Model (hw_simple)', linestyle='--', color=colors['hw_simple'])

    # Plot formatting
    if hide_x_axis:
        ax.set_xlabel('')
        ax.set_xticks(sizes)
        ax.tick_params(
            axis='x',
            which='both',
            bottom=False, top=False,  # hide tick marks
            labelbottom=False         # hide labels
        )
    else:
        ax.set_xticks(sizes, [str(size) if size != 2048 else "" for size in sizes])
        ax.set_xlabel('Size [B]')
    if y_label is None:
        y_label = 'Runtime [cycles]'
    ax.set_ylabel(y_label)
    ax.set_xlim(0, sizes.max() * 1.1)
    ax.set_axisbelow(True)
    ax.grid(True, color='gainsboro')
    ax.legend()
    plt.tight_layout()
    if show:
        plt.show()

    return df


def plot2(y_label=None, show=True):
    """Plot actual and expected runtimes, for multiple number of rows."""

    # Load results
    c = 4
    df = experiments.results()

    # Get expected and actual runtimes
    df['cycles'] = df.apply(get_actual_cycles, axis=1)
    df = select_best_configs(df)
    df['exp_cycles'] = df.apply(get_expected_cycles, axis=1)
    df['exp_batch'] = df.apply(get_expected_batch_size, axis=1)

    # Drop results column for cleaner output
    df = df.drop(columns=['results'])

    # Choose consistent colors for the plots
    colors = {"sw": "C0", "hw_generic": "C1", "hw_simple": "C2"}

    # Create plot
    _, ax = plt.subplots()
    sizes = df['size'].unique()

    # Create function to plot runtimes for a given number of rows
    def plot_runtime_vs_speedup(ax, n_rows, show_label=False):
        res = df[df['n_rows'] == n_rows]
        best_sw_cycles = res[res['impl'].isin(['seq', 'tree'])].groupby('size')['cycles'].min()
        ax.scatter(
            sizes, best_sw_cycles, label='Actual (min(seq, tree))' if show_label else None,
            marker='x', color=colors['sw']
        )
        ax.scatter(
            sizes, res[res['impl'] == 'hw_simple']['cycles'], label='Actual (hw_simple)' if show_label else None,
            marker='x', color=colors['hw_simple']
        )
        # ax.scatter(
        #     sizes, res[res['impl'] == 'hw_generic']['cycles'], label='Actual (hw_generic)' if show_label else None,
        #     marker='x', color=colors['hw_generic']
        # )

        # Plot model line for best software implementation
        # TODO(colluca): use sw_runtime_curve once sequential implementation is integrated
        x, y = monotone_tree_runtime_curve(sizes.min(), sizes.max(), c, n_rows)
        ax.plot(
            x, y, label='Model (min(seq, tree))' if show_label else None,
            linestyle='--', color=colors['sw'])

        # Annotate sw model lines with number of rows, in correspondence with actual runtime
        ax.annotate(
            f'r={n_rows}',
            xy=(x[-1], best_sw_cycles[sizes.max()]),
            xytext=(sizes.max() * 0.0001, 0), textcoords='offset points',  # nudge right
            ha='left', va='center', clip_on=False)

        # Plot model line for hardware simple runtime
        x, y = hw_simple_runtime_curve(sizes.min(), sizes.max(), c, n_rows)
        ax.plot(
            x, y, label='Model (hw_simple)' if show_label else None, linestyle='--', color=colors['hw_simple'])

        # # Plot model line for hardware generic runtime
        # x, y = hw_generic_runtime_curve(sizes.min(), sizes.max(), c, n_rows)
        # ax.plot(
        #     x, y, label='Model (hw_generic)' if show_label else None, linestyle='--', color=colors['hw_generic'])

    for i, n_rows in enumerate(df['n_rows'].unique()):
        plot_runtime_vs_speedup(ax, n_rows=n_rows, show_label=(i == 0))

    ax.set_xticks(sizes, [str(size) if size != 2048 else "" for size in sizes])
    ax.set_xlim(0, sizes.max() * 1.1)
    ax.set_xlabel('Size [B]')
    if y_label is None:
        y_label = 'Runtime [cycles]'
    ax.set_ylabel(y_label)
    ax.set_axisbelow(True)
    ax.grid(True, color='gainsboro')
    ax.legend()

    plt.tight_layout()
    if show:
        plt.show()

    return df


def plot3(show=True):
    """Plot runtime dependency with delta."""

    # Load results
    df = experiments.results()

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

    # Plot model lines for sequential runtime (varying delta).
    x = np.arange(df['size'].min(), df['size'].max(), 64)
    for k, alpha_delta in enumerate([*range(model.DELTA + model.SEQ_ALPHA, -1, -12), 0]):
        alpha = alpha_delta // 2
        delta = alpha_delta - alpha
        x_ext = np.arange(df['size'].min(), df['size'].max() + 1024, 64)
        y = [model.optimal_seq_runtime(4, n_rows, e // 64, delta, alpha, model.SEQ_ALPHA)
             for e in x_ext]
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
        ax.plot(x_monotone, y_monotone, label='seq$(\\alpha_i+\\delta)$' if k == 0 else None,
                color=colors['seq'])
        ax.annotate(
            f'${alpha_delta}$',
            xy=(x[-1], y_monotone[-1]),
            xytext=(1, 0), textcoords='offset points',  # nudge right
            ha='left', va='center', clip_on=False)

    # Plot model line for hardware runtime
    y = [model.hw_runtime(4, n_rows, e // 64) for e in x]
    ax.plot(x, y, label='hw', linestyle='--', color=colors['hw'])

    ax.set_xticks(df['size'], [str(size) if size != 2048 else "" for size in df['size']])
    ax.set_xlabel('Size [B]')
    ax.set_ylabel('Runtime [cycles]')
    ax.set_axisbelow(True)
    ax.grid(True, linestyle='-', color='gainsboro')
    ax.legend()

    plt.tight_layout()
    if show:
        plt.show()


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
