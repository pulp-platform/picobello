#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

import snitch.util.experiments.experiment_utils as eu
from snitch.util.experiments import common
from snitch.util.experiments.SimResults import SimRegion
from pathlib import Path

PB_ROOT = Path(__file__).resolve().parents[2]
PB_SIM_CMD = [
    'bash', '-c',
    f'"make vsim-run-batch -C {str(PB_ROOT)} SIM_DIR=${{run_dir}} '
    f'CHS_BINARY={str(PB_ROOT)}/sw/cheshire/tests/simple_offload.spm.elf '
    f'SN_BINARY=${{elf}} PRELMODE=3; '
    f'grep -q \\"] SUCCESS\\" ${{run_dir}}/transcript"'
]


class MulticastExperimentManager(eu.ExperimentManager):

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
                    'cmd': PB_SIM_CMD,
                    'length': length,
                    'mode': mode,
                    'n_clusters': n_clusters,
                })
    return experiments


def picobello_sw_callback(target=None, build_dir=None, defines=None, dry_run=False, **kwargs):
    env = {
        'SN_TESTS_RISCV_CFLAGS': common.join_cdefines(defines),
    }
    vars = {
        'SN_TESTS_BUILDDIR': build_dir,
        'DEBUG': 'ON',
    }
    env = common.extend_environment(env)
    return common.make(
        target, flags=['-j'], dir=PB_ROOT, vars=vars, env=env, sync=False,
        dry_run=dry_run
    )


def main():

    callbacks = {
        'sw': picobello_sw_callback
    }

    manager = MulticastExperimentManager(gen_experiments(), callbacks=callbacks)
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
