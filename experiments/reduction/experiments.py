#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from functools import cache
import math
from pathlib import Path
import picobello as pb
import snitch.util.experiments.experiment_utils as eu
from snitch.util.experiments.SimResults import SimRegion

BEAT_BYTES = 64
TCK = 5
DIR = Path(__file__).parent


###############
# Experiments #
###############


class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        keys = ['impl', 'n_rows', 'size']
        if experiment['impl'] in ['seq', 'tree']:
            keys.append('batch')
        return eu.derive_axes_from_keys(experiment, keys)

    def derive_cdefines(self, experiment):
        cdefs = {
            'IMPL': experiment['impl'].upper(),
            'LOG2_N_ROWS': int(math.log2(experiment['n_rows'])),
            'SIZE': experiment['size'],
        }
        if experiment['impl'] in ['seq', 'tree']:
            cdefs['BATCH'] = experiment['batch']
        return cdefs

    def derive_hw_cfg(self, experiment):
        return pb.hw_cfg


def gen_experiments(ci=False):
    # Define axes
    impls = ['seq', 'tree', 'hw']
    n_rows_list = [1, 2, 4]
    sizes = [1024, 2048, 4096, 8192, 16384, 32768]
    n_batches_list = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
    if ci:
        impls = ['hw']
        n_rows_list = [4]
        sizes = [32768]
        n_batches_list = [1024, 2048]

    # Generate experiments list
    experiments = []
    for impl in impls:
        for n_rows in n_rows_list:
            for size in sizes:
                for n_batches in n_batches_list:

                    # Only sequential and tree implementations supports batching, for all other
                    # implementations we only accept n_batches = 1
                    batch_size = int(size // n_batches)
                    batch_beats = int(batch_size // BEAT_BYTES)
                    if impl in ['seq', 'tree']:
                        valid_n_batches = batch_beats > 8 and batch_beats < 256
                    else:
                        valid_n_batches = n_batches == 1 if not ci else n_batches in n_batches_list

                    # If the current setting for n_batches is valid, add the experiment
                    if valid_n_batches:
                        experiment = {
                            'impl': impl,
                            'n_rows': n_rows,
                            'size': size,
                            'batch': batch_size,
                            'app': 'reduction_benchmark',
                            'roi': Path.cwd() / f'roi/{impl}.json.tpl',
                        }
                        experiment['cmd'] = pb.sim_and_verify_cmd(Path.cwd() / 'verify.py')
                        experiments.append(experiment)
    return experiments


###########
# Results #
###########

def dma_core(cluster_idx):
    return f'hart_{1 + cluster_idx * 9 + 8}'


def compute_core(cluster_idx, core_idx):
    return f'hart_{1 + cluster_idx * 9 + core_idx}'


# Assumes DMA transfers on all clusters, and for all batches to be equal.
# Therefore we only sample cluster 12's first transfer.
def seq_dma_cycles(sim_results):
    roi = SimRegion(dma_core(12), 'd_0', 1)
    return sim_results.get_timespan(roi) // TCK


# Assumes computation on all clusters, and for all batches to be equal.
# Therefore we only sample cluster 0's first computation.
def seq_compute_cycles(sim_results):
    roi = SimRegion(compute_core(0, 0), 'c_0', 1)
    return sim_results.get_timespan(roi) // TCK


def seq_cycles(sim_results, c, r, n_batches):
    start = SimRegion(dma_core(12), 'd_0', 1)
    end = SimRegion(compute_core(0, 0), f'c{"" if r == 1 else 2}_{n_batches-1}', 1)
    return sim_results.get_timespan(start, end) // TCK


# Assumes DMA transfers on all clusters, and all levels of the tree to be equal.
# Therefore we only sample cluster 4's first transfer.
def tree_dma_cycles(sim_results):
    roi = SimRegion(dma_core(4), '4 > 0', 0)
    return sim_results.get_timespan(roi) // TCK


# Assumes computation on all clusters, and all levels of the tree to be equal.
# Therefore we only sample cluster 0's first computation.
def tree_compute_cycles(sim_results):
    roi = SimRegion(compute_core(0, 0), 'comp l0', 0)
    return sim_results.get_timespan(roi) // TCK


def tree_cycles(sim_results, c, r, n_batches):
    n_levels = int(math.log2(c * r))
    start = SimRegion(dma_core(4), '4 > 0', 0)
    end = SimRegion(compute_core(0, 0), f'comp l{n_levels-1}', n_batches - 1)
    return sim_results.get_timespan(start, end) // TCK


def hw_dma_cycles(sim_results):
    roi = SimRegion(dma_core(0), 'row reduction', 1)
    return sim_results.get_timespan(roi) // TCK


def hw_cycles(sim_results):
    start = SimRegion(dma_core(0), 'row reduction', 1)
    end = SimRegion(dma_core(0), 'column reduction', 1)
    return sim_results.get_timespan(start, end) // TCK


@cache
def results(manager=None):
    if manager is None:
        manager = ExperimentManager(gen_experiments(), dir=DIR, parse_args=False)
    return manager.get_results()


########
# Main #
########

def main():

    parser = ExperimentManager.parser()
    parser.add_argument('--ci', action='store_true',
                        help='Reduce experiment space for CI runs')
    args = parser.parse_args()
    manager = ExperimentManager(gen_experiments(ci=args.ci), dir=DIR, args=args, parse_args=False)
    manager.run()
    df = results(manager)
    print(df)


if __name__ == '__main__':
    main()
