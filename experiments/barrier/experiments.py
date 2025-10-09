#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import math
from pathlib import Path
import picobello as pb
import snitch.util.experiments.experiment_utils as eu
from snitch.util.experiments.SimResults import SimRegion

TCK = 5
DIR = Path(__file__).parent


class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        return eu.derive_axes_from_keys(experiment, ['impl', 'n_clusters'])

    def derive_cdefines(self, experiment):
        cdefs = {
            'IMPL': experiment['impl'].upper(),
            'N_ROWS': experiment['n_rows'],
            'N_COLS': experiment['n_cols'],
        }
        return cdefs


def gen_experiments():
    experiments = []
    # for impl in ['sw']:
        # for n_clusters in [8]:
    for impl in ['sw', 'hw']:
        for n_clusters in [2, 4, 8, 16]:
            experiments.append({
                'app': 'barrier_benchmark',
                'cmd': pb.sim_cmd,
                'impl': impl,
                'n_clusters': n_clusters,
                'n_rows': int(math.ceil(n_clusters / 4)),
                'n_cols': n_clusters % 4 if n_clusters % 4 != 0 else 4,
            })
    return experiments


def dma_core(row_idx, col_idx):
    cluster_idx = row_idx + col_idx * 4
    return 1 + cluster_idx * 9 + 8


def get_total_cycles(sim_results):
    roi = SimRegion(f'hart_{dma_core(0, 1)}', 'barrier', 1)
    return sim_results.get_timespan(roi) // TCK


def results(manager=None):
    if manager is None:
        manager = ExperimentManager(gen_experiments(), dir=DIR, parse_args=False)
    return manager.get_results()


def main():
    manager = ExperimentManager(gen_experiments(), dir=DIR)
    manager.run()
    df = results(manager)
    print(df)


if __name__ == '__main__':
    main()
