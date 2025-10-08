#!/usr/bin/env python3
# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm
from matplotlib.colors import ListedColormap

PULP_COLORS = {
    "PULP Blue":   "#3067AB",
    "PULP Petrol": "#84B5E9",
    "PULP Green":  "#168638",
    "PULP Bronze": "#E59955",
    "PULP Red":    "#9B3B32",
    "PULP Purple": "#851B66",
    "PULP Grey":   "#6F6F6F"
}


def plot_multicast_speedup(clusters, transfer_sizes, speedups,
                           colors=None,
                           title="Multicast Speedup",
                           xlabel="Number of Clusters",
                           ylabel="Speedup",
                           legend_loc="upper left",
                           legend_ncol=1,
                           legend_frame=True,
                           save_name=None):
    """
    Plots a bar chart of multicast speedup.

    Parameters:
    - clusters: list of cluster counts (x-axis categories)
    - transfer_sizes: list of transfer sizes (legend categories)
    - speedups: 2D list of speedups where each row corresponds to clusters[i]
                and each column corresponds to transfer_sizes[j]
    - colors: list of colors for each transfer size
    - title, xlabel, ylabel: strings for plot customization
    - legend_loc: legend location (e.g., 'upper left', 'upper right')
    - legend_ncol: number of columns in legend
    - legend_frame: whether to show frame around legend
    """

    # Number of clusters and transfer sizes
    n_clusters = len(clusters)
    n_sizes = len(transfer_sizes)

    # Default colors if none are provided
    if colors is None:
        colors = plt.cm.viridis(np.linspace(0, 1, n_sizes))

    # X positions for cluster groups
    x = np.arange(n_clusters)

    # Width of each bar
    bar_width = 0.8 / n_sizes

    fig, ax = plt.subplots(figsize=(10, 6))

    # Plot each transfer size group
    for i, size in enumerate(transfer_sizes):
        offsets = x + i * bar_width - (bar_width * (n_sizes - 1) / 2)
        ax.bar(offsets,
               [speedups[j][i] for j in range(n_clusters)],
               width=bar_width,
               color=colors[i],
               label=f"{size}")

    # Labels and title
    ax.set_xlabel(xlabel, fontsize=14)
    ax.set_ylabel(ylabel, fontsize=14)
    ax.set_title(title, fontsize=16)
    ax.set_xticks(x)
    ax.set_xticklabels(clusters)
    ax.tick_params(axis='both', which='major', labelsize=14)

    # Legend customization
    ax.legend(title="Transfer Size", loc=legend_loc, ncol=legend_ncol, frameon=legend_frame, fontsize=14, title_fontsize=16)

    # Grid for readability
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    fig.tight_layout()

    # Save plot if a name is provided
    if save_name:
        plots_dir = os.path.join(os.getcwd(), "plots")
        os.makedirs(plots_dir, exist_ok=True)
        file_path = os.path.join(plots_dir, f"{save_name}.svg")
        plt.savefig(file_path, format="svg", bbox_inches="tight")
        print(f"Plot saved to: {file_path}")

    return fig, ax


def _add_gradient_legend_inset(
    ax_main, colors1, colors2, transfer_sizes, sw1_label, sw2_label,
    inset_width=0.3, bar_height=0.04, gap=0.01, x0=0.02, y_top=0.92
):
    """Place two gradient bars in the top-left; bottom=SW1 (with labels), top=SW2 (no labels)."""

    # Top bar = SW2 (no labels)
    ax_sw2 = ax_main.inset_axes([x0, y_top - bar_height, inset_width, bar_height],
                                transform=ax_main.transAxes)
    # Bottom bar = SW1 (with labels)
    ax_sw1 = ax_main.inset_axes([x0, y_top - 2*bar_height - gap, inset_width, bar_height],
                                transform=ax_main.transAxes)

    def draw_bar(ax_bar, colors, title, show_labels=False, lgn_title=False):
        data = np.arange(len(colors)).reshape(1, len(colors))
        cmap = ListedColormap(colors)
        ax_bar.imshow(data, aspect='auto', cmap=cmap, extent=[0, len(colors), 0, 1])

        if show_labels:
            centers = np.arange(len(colors)) + 0.5
            ax_bar.set_xticks(centers)
            ax_bar.set_xticklabels(transfer_sizes, fontsize=8, rotation=45, ha="right")
        else:
            ax_bar.set_xticks([])

        ax_bar.set_yticks([])
        ax_bar.set_xlim(0, len(colors))

        for spine in ax_bar.spines.values():
            spine.set_visible(False)

        # Title to the right
        ax_bar.text(len(colors) + 0.2, 0.5, title,
                    fontsize=9, va='center', ha='left', transform=ax_bar.transData)

        # DMA Transfer Size label centered over the 6 colors
        if lgn_title:
            ax_bar.text(3, 1.4, "DMA Transfer Size",  # x=3 is center of 0..6 range
                        fontsize=9, ha='center', va='bottom', fontweight="bold",
                        transform=ax_bar.transData)

    # Draw bars
    draw_bar(ax_sw2, colors2, sw2_label, show_labels=False, lgn_title=True)
    draw_bar(ax_sw1, colors1, sw1_label, show_labels=True, lgn_title=False)


def plot_two_software_speedup(
    clusters,
    transfer_sizes,
    sw1_speedups,
    sw2_speedups,
    sw1_label="Software 1",
    sw2_label="Software 2",
    cmap1="viridis",
    cmap2="magma",
    title="Speedup by Transfer Size and Software",
    xlabel="Number of Clusters",
    ylabel="Speedup",
    save_name=None
):
    n_clusters = len(clusters)
    x = np.arange(n_clusters)
    bars_per_group = 12
    bar_width = 0.8 / bars_per_group

    colors1 = cm.get_cmap(cmap1)(np.linspace(0.15, 0.85, 6))
    colors2 = cm.get_cmap(cmap2)(np.linspace(0.15, 0.85, 6))

    fig, ax = plt.subplots(figsize=(12, 6))

    for i in range(6):
        offsets_sw1 = x + i * bar_width - (bar_width * (bars_per_group - 1) / 2)
        offsets_sw2 = x + (6 + i) * bar_width - (bar_width * (bars_per_group - 1) / 2)

        ax.bar(offsets_sw1, [sw1_speedups[j][i] for j in range(n_clusters)],
               width=bar_width, color=colors1[i])
        ax.bar(offsets_sw2, [sw2_speedups[j][i] for j in range(n_clusters)],
               width=bar_width, color=colors2[i])

    ax.set_title(title, fontsize=16)
    ax.set_xlabel(xlabel, fontsize=14)
    ax.set_ylabel(ylabel, fontsize=14)
    ax.set_xticks(x)
    ax.set_xticklabels(clusters)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    # Add gradient legend in top-left corner
    _add_gradient_legend_inset(ax, colors1, colors2, transfer_sizes, sw1_label, sw2_label)

    fig.tight_layout()

    # Save plot if a name is provided
    if save_name:
        plots_dir = os.path.join(os.getcwd(), "plots")
        os.makedirs(plots_dir, exist_ok=True)
        file_path = os.path.join(plots_dir, f"{save_name}.svg")
        plt.savefig(file_path, format="svg", bbox_inches="tight")
        print(f"Plot saved to: {file_path}")

    return fig, ax


# ===== Example Usage =====
def main():
    df = pd.read_csv('results.csv')

    clusters = df['n_clusters'].unique().tolist()
    transfer_sizes = [f'{size} B' for size in df['length'].unique().tolist()]

    cycles = {
        mode: grp.drop(columns='mode')
                 .set_index(['n_clusters', 'length'])
                 .sort_index(level=['n_clusters', 'length'])
        for mode, grp in df.groupby("mode", sort=False)
    }

    speedups_mcast_unopt = cycles['SW_UNOPT'] / cycles['HW_MCAST']
    speedups_sw1_unopt = cycles['SW_UNOPT'] / cycles['SW_OPT']
    speedups_sw2_unopt = cycles['SW_UNOPT'] / cycles['SW_OPT2']
    speedups_sw2_sw1 = cycles['SW_OPT'] / cycles['SW_OPT2']
    speedups_mcast_sw2 = cycles['SW_OPT2'] / cycles['HW_MCAST']

    speedups_mcast_unopt = speedups_mcast_unopt.values.reshape((len(clusters), len(transfer_sizes))).tolist()
    speedups_sw1_unopt = speedups_sw1_unopt.values.reshape((len(clusters), len(transfer_sizes))).tolist()
    speedups_sw2_unopt = speedups_sw2_unopt.values.reshape((len(clusters), len(transfer_sizes))).tolist()
    speedups_sw2_sw1 = speedups_sw2_sw1.values.reshape((len(clusters), len(transfer_sizes))).tolist()
    speedups_mcast_sw2 = speedups_mcast_sw2.values.reshape((len(clusters), len(transfer_sizes))).tolist()

    # Select PULP colors for the 6 transfer sizes
    custom_colors = [
        PULP_COLORS["PULP Blue"],
        PULP_COLORS["PULP Petrol"],
        PULP_COLORS["PULP Green"],
        PULP_COLORS["PULP Bronze"],
        PULP_COLORS["PULP Red"],
        PULP_COLORS["PULP Purple"]
    ]

    plot_multicast_speedup(
        clusters, transfer_sizes, speedups_mcast_unopt,
        title="Multicast Speedup against unoptimized software version",
        xlabel="Number of Clusters",
        ylabel="Speedup",
        legend_loc="upper left",
        legend_ncol=2,
        save_name="mcast_vs_unopt"
    )

    plot_multicast_speedup(
        clusters, transfer_sizes, speedups_sw2_sw1,
        title="Speedup of SW OPT2 implementation against SW OPT1",
        xlabel="Number of Clusters",
        ylabel="Speedup",
        legend_loc="upper left",
        legend_ncol=2,
        save_name="sw2_vs_sw1"
    )

    plot_multicast_speedup(
        clusters, transfer_sizes, speedups_mcast_sw2,
        title="Multicast Speedup against best software version",
        xlabel="Number of Clusters",
        ylabel="Speedup",
        legend_loc="upper left",
        legend_ncol=2,
        save_name="mcast_vs_optimized"
    )

    plot_two_software_speedup(
        clusters,
        transfer_sizes,
        speedups_sw1_unopt, speedups_sw2_unopt,
        sw1_label="Column first",
        sw2_label="Binary tree",
        cmap1="viridis",
        cmap2="magma",
        title="Speedup of different Software schemes",
        xlabel="Number of Clusters",
        ylabel="Speedup",
        save_name="sw_comparison"
    )

    plt.show()


if __name__ == '__main__':
    main()
