#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import argparse
import matplotlib.pyplot as plt
from barrier import experiments


def plot1(show=True):
    """Plot runtime vs number of clusters."""

    # Load results
    df = experiments.results()

    # Get actual runtimes
    df['cycles'] = df['results'].apply(experiments.get_total_cycles)

    # Plot
    ax = df.pivot(index="n_clusters", columns="impl", values="cycles").plot(kind="bar", width=0.65)
    ax.set_xlabel("Nr. clusters")
    ax.set_ylabel("Runtime [cycles]")
    ax.tick_params(axis='x', labelrotation=0)
    ax.set_axisbelow(True)
    ax.grid(axis="y", color="gainsboro")
    ax.legend(handlelength=1, ncol=2, columnspacing=0.5, handletextpad=0.3)
    plt.tight_layout()
    if show:
        plt.show()


def main():

    # Parse arguments
    functions = [plot1]
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


if __name__ == "__main__":
    main()
