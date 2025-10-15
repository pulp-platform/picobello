#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from pathlib import Path
import picobello as pb
import snitch.util.experiments.experiment_utils as eu

TCK = 5
VERIFY_PY = Path(__file__).parent / '../../.deps/snitch_cluster/sw/kernels/blas/gemm/scripts/verify.py'


class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        return eu.derive_axes_from_keys(experiment, ['mode', 'n_tiles'])

    def derive_cdefines(self, experiment):
        cdefs = {
            'MODE': experiment['mode'].upper(),
        }
        return cdefs

    def derive_data_cfg(self, experiment):
        return eu.derive_data_cfg_from_template(experiment)


def gen_experiments():
    experiments = []
    # for mode in ['hw']:
    for mode in ['sw_tree']:
        for n_tiles in [4]:
        # for mode in ['sw_naive', 'sw_tree', 'hw']:
            experiments.append({
                'app': 'summa_gemm',
                'cmd': pb.sim_and_verify_cmd(VERIFY_PY),
                'mode': mode,
                'n_tiles': n_tiles,
            })
    return experiments


def main():
    manager = ExperimentManager(gen_experiments())
    manager.run()


if __name__ == '__main__':
    main()
