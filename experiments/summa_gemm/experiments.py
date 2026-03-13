#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from pathlib import Path
import picobello as pb
from summa_gemm import model
import snitch.util.experiments.experiment_utils as eu

TCK = 5
VERIFY_PY = Path(__file__).parent / '../../.deps/snitch_cluster/sw/kernels/blas/gemm/scripts/verify.py'


class ExperimentManager(pb.ExperimentManager):

    def derive_axes(self, experiment):
        return eu.derive_axes_from_keys(experiment, ['m'])

    def derive_data_cfg(self, experiment):
        return eu.derive_data_cfg_from_template(experiment)

    def derive_hw_cfg(self, experiment):
        return pb.hw_cfg


def gen_experiments():
    experiments = []
    for m in [model.max_square_problem_size()]:
        experiments.append({
            'app': 'power_benchmarks',
            'cmd': pb.sim_cmd(),
            'm': m,
            'roi': Path.cwd() / f'roi.json.tpl',
        })
    return experiments


def main():
    manager = ExperimentManager(gen_experiments())
    manager.run()


if __name__ == '__main__':
    main()
