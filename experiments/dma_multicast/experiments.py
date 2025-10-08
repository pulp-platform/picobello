#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import picobello as pb
import snitch.util.experiments.experiment_utils as eu
from snitch.util.experiments.SimResults import SimRegion


class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        return eu.derive_axes_from_keys(experiment, ['length', 'mode', 'n_clusters'])

    def derive_cdefines(self, experiment):
        cdefs = {
            'N_CLUSTERS_TO_USE': experiment['n_clusters'],
            'MODE': experiment['mode'],
            'LENGTH': experiment['length'],
        }
        return cdefs


def gen_experiments():
    experiments = []
    # for length in [256]:#, 512, 1024, 2048, 4096, 8192]:
        # for mode in ['SW_UNOPT']:#, 'SW_OPT', 'SW_OPT2', 'HW_MCAST']:
            # for n_clusters in [4]:#, 8, 16]:
    for length in [256, 512, 1024, 2048, 4096, 8192]:
        for mode in ['SW_UNOPT', 'SW_OPT', 'SW_OPT2', 'HW_MCAST']:
            for n_clusters in [4, 8, 16]:
                experiments.append({
                    'app': 'dma_multicast',
                    'cmd': pb.sim_cmd,
                    'length': length,
                    'mode': mode,
                    'n_clusters': n_clusters,
                })
    return experiments


def main():

    manager = ExperimentManager(gen_experiments())
    manager.run()

    df = manager.get_results()
    print(df)

    if not manager.perf_results_available:
        return

    # Get runtime of region 3 (second invocation of `dma_broadcast_to_clusters`)
    def get_cycles(row):
        return row['results'].get_metric(SimRegion('hart_9', 3), 'cycles')

    df['cycles'] = df.apply(get_cycles, axis=1)
    df.drop(labels=['results'], inplace=True, axis=1)
    df.to_csv('results.csv', index=False)
    print(df)


if __name__ == '__main__':
    main()
