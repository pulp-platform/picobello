#!/usr/bin/env python3
# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Colagrande <colluca@iis.ee.ethz.ch>
# 
# Verification script for `reduction_benchmark.c`

import sys
import snitch.util.sim.verif_utils as vu


class Verifier(vu.Verifier):

    OUTPUT_UIDS = ['output']

    def __init__(self):
        super().__init__()

    def get_actual_results(self):
        return self.get_output_from_symbol(self.OUTPUT_UIDS[0], 'double')

    def get_expected_results(self):
        length = int(self.get_input_from_symbol('length', 'uint32_t')[0])
        n_clusters = int(self.get_input_from_symbol('n_clusters', 'uint32_t')[0])
        print(n_clusters)
        print(sum(range(n_clusters)))
        return [i * n_clusters + sum(range(n_clusters)) for i in range(length)]

    def check_results(self, *args):
        return super().check_results(*args, atol=0)


if __name__ == "__main__":
    sys.exit(Verifier().main())
