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

N_CLUSTERS = 4
N_CLUSTERS_PER_ROW = 4
WIDE_DATA_WIDTH = 64  # bytes
TCK = 5


###############
# Experiments #
###############

class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        keys = ['impl', 'n_rows', 'size']
        if experiment['impl'] == 'seq':
            keys.append('batch')
        return eu.derive_axes_from_keys(experiment, keys)

    def derive_cdefines(self, experiment):
        cdefs = {
            'IMPL': experiment['impl'].upper(),
            'LOG2_N_ROWS': int(math.log2(experiment['n_rows'])),
            'SIZE': experiment['size'],
            'BATCH': experiment['batch'],
        }
        return cdefs


def gen_experiments():
    experiments = []
    for impl in ['seq', 'tree', 'hw']:
        # for n_rows in [1]:
        for n_rows in [1, 2, 4]:
            # for size in [1024]:
            for size in [1024, 2048, 4096, 8192, 16384, 32768]:
                # for n_batches in [1]:
                for n_batches in [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]:

                    # Only sequential implementation supports batching, for all other
                    # implementations we only accept n_batches = 1
                    batch_size = int(size // n_batches)
                    batch_beats = int(batch_size // WIDE_DATA_WIDTH)
                    if impl == 'seq':
                        valid_n_batches = batch_beats > 8 and batch_beats < 1024
                    else:
                        valid_n_batches = n_batches == 1

                    # If the current setting for n_batches is valid, add the experiment
                    if valid_n_batches:
                        experiments.append({
                            'impl': impl,
                            'n_rows': n_rows,
                            'size': size,
                            'batch': batch_size,
                            'app': 'dma_multicast_v2',
                            'cmd': pb.sim_and_verify_cmd(Path.cwd() / 'verify.py'),
                            'roi': Path.cwd() / f'roi/{impl}.json.tpl',
                        })
    return experiments


def dma_core(cluster_idx):
    return f'hart_{1 + cluster_idx * 9 + 8}'


###########
# Results #
###########

def tree_cycles(sim_results, n_rows):
    n_levels = int(math.log2(N_CLUSTERS_PER_ROW * n_rows) + 1)
    start = SimRegion(dma_core(0 * N_CLUSTERS_PER_ROW), 'level 0', 0)
    end = SimRegion(dma_core(2 * N_CLUSTERS_PER_ROW), f'level {n_levels-1}', 0)
    return sim_results.get_timespan(start, end) // TCK


# Cluster to cluster (C2C) transfer cycles
def tree_c2c_cycles(sim_results):
    roi = SimRegion(dma_core(0), 'level 1', 0)
    return sim_results.get_timespan(roi) // TCK


# Memory to cluster (M2C) transfer cycles
def tree_m2c_cycles(sim_results):
    roi = SimRegion(dma_core(0), 'level 0', 0)
    return sim_results.get_timespan(roi) // TCK


def seq_cycles(sim_results, n_batches, n_rows):
    start = SimRegion(dma_core(0), 'batch 0', 1)
    end = SimRegion(dma_core(12 + n_rows - 1), f'batch {n_batches-1}', 1)
    return sim_results.get_timespan(start, end) // TCK


def seq_batch_cycles(sim_results, batch_idx, cluster_idx=0):
    start = SimRegion(dma_core(cluster_idx), f'batch {batch_idx}', 1)
    return sim_results.get_timespan(start) // TCK


def hw_cycles(sim_results):
    roi = SimRegion(dma_core(0), 'transfer', 1)
    return sim_results.get_timespan(roi) // TCK


def results(manager=None):
    if manager is None:
        manager = ExperimentManager(gen_experiments(), parse_args=False)
    return manager.get_results()


########
# Main #
########

def main():

    manager = ExperimentManager(gen_experiments())
    manager.run()
    df = results(manager)
    print(df)


if __name__ == '__main__':
    main()
