# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>

from pathlib import Path
import snitch.util.experiments.experiment_utils as eu
from snitch.util.experiments import common

root = Path(__file__).resolve().parents[1]
sim_cmd = [
    'bash', '-c',
    f'make vsim-run-batch -C {str(root)} SIM_DIR=${{run_dir}} '
    f'CHS_BINARY={str(root)}/sw/cheshire/tests/simple_offload.spm.elf '
    f'SN_BINARY=${{elf}} PRELMODE=3; '
    f'grep -q "] SUCCESS" ${{run_dir}}/transcript;'
]


def sim_and_verify_cmd(verify_script):
    return [
        'bash', '-c',
        f'make vsim-run-batch-verify -C {str(root)} SIM_DIR=${{run_dir}} '
        f'CHS_BINARY={str(root)}/sw/cheshire/tests/simple_offload.spm.elf '
        f'SN_BINARY=${{elf}} VERIFY_PY={verify_script} PRELMODE=3;'
    ]


def sw_callback(target=None, build_dir=None, defines=None, dry_run=False, sync=False, **kwargs):
    env = {
        'SN_TESTS_RISCV_CFLAGS': common.join_cdefines(defines),
    }
    vars = {
        'SN_TESTS_BUILDDIR': build_dir,
        'DEBUG': 'ON',
    }
    env = common.extend_environment(env)
    return common.make(
        target, flags=['-j'], dir=root, vars=vars, env=env, sync=sync,
        dry_run=dry_run
    )


callbacks = {
    'sw': sw_callback
}


class ExperimentManager(eu.ExperimentManager):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, callbacks=callbacks, **kwargs)
