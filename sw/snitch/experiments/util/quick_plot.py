#!/usr/bin/env python3
# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm
from matplotlib.patches import Patch
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
    fig = ax_main.figure

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
  clusters = [4, 8, 16]
  transfer_sizes = ["1 KiB", "2 KiB", "4 KiB", "8 KiB", "16 KiB", "32 KiB"]

  # Example speedups (rows = clusters, cols = transfer sizes)
  speedups_mcast_unopt = [
    [3.92, 3.953846154, 3.76, 3.915151515, 3.969491525, 3.992857143],  # For 4 clusters
    [7.7, 7.738461538, 7.45, 7.848484848, 7.983050847, 7.859649123],   # For 8 clusters
    [15.24, 15.66153846, 15.02, 15.73939394, 15.88813559, 15.67894737] # For 16 clusters
]

  speedups_sw1_unopt = [
    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],                       # For 4 clusters
    [0.891203704, 0.994071146, 1.125377644, 1.29241517,   # For 8 clusters
     1.424682396, 1.509942703],
    [1.448669202, 1.583203733, 1.796650718, 1.965934898,  # For 16 clusters
     2.099910394, 2.192590775]
  ]

  speedups_sw2_unopt = [
    [1.02617801, 1.088983051, 1.153374233, 1.216572505, 1.271444083, 1.303030303],  # For 4 clusters
    [1.370106762, 1.462209302, 1.616052061, 1.75951087, 1.875, 1.942758023],        # For 8 clusters
    [2.01055409, 2.237362637, 2.486754967, 2.736564805, 2.931207004, 3.066918325]   # For 16 clusters
]

  speedups_sw2_sw1 = [
    [1.02617801, 1.088983051, 1.153374233, 1.216572505, 1.271444083, 1.303030303],  # For 4 clusters
    [1.537366548, 1.470930233, 1.436008677, 1.361413043, 1.316082803, 1.286643539], # For 8 clusters
    [1.387862797, 1.413186813, 1.38410596, 1.39199157, 1.39587242, 1.398764585]     # For 16 clusters
  ]

  speedups_optimized = [
      [3.82, 3.630769231, 3.26, 3.218181818, 3.122033898, 3.064285714],  # For 4 clusters
      [5.62, 5.292307692, 4.61, 4.460606061, 4.257627119, 4.045614035],  # For 8 clusters
      [7.58, 7.0, 6.04, 5.751515152, 5.420338983, 5.112280702]           # For 16 clusters
  ]

  # Select PULP colors for the 6 transfer sizes
  custom_colors = [
    PULP_COLORS["PULP Blue"],
    PULP_COLORS["PULP Petrol"],
    PULP_COLORS["PULP Green"],
    PULP_COLORS["PULP Bronze"],
    PULP_COLORS["PULP Red"],
    PULP_COLORS["PULP Purple"]
  ]

  plot_multicast_speedup(clusters, transfer_sizes, speedups_mcast_unopt,
                        title="Multicast Speedup against unoptimized software version",
                        xlabel="Number of Clusters",
                        ylabel="Speedup",
                        legend_loc="upper left",
                        legend_ncol=2,
                        save_name="mcast_vs_unopt")

  plot_multicast_speedup(clusters, transfer_sizes, speedups_sw2_sw1,
                        title="Speedup of SW OPT2 implementation against SW OPT1",
                        xlabel="Number of Clusters",
                        ylabel="Speedup",
                        legend_loc="upper left",
                        legend_ncol=2,
                        save_name="sw2_vs_sw1")

  plot_multicast_speedup(clusters, transfer_sizes, speedups_optimized,
                        title="Multicast Speedup against best software version",
                        xlabel="Number of Clusters",
                        ylabel="Speedup",
                        legend_loc="upper left",
                        legend_ncol=2,
                        save_name="mcast_vs_optimized")

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
