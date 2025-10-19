#!/usr/bin/env python3
# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Chen Wu <chenwu@iis.ee.ethz.ch>

# Verification script for `dma_reduction.c`

import sys
import snitch.util.sim.verif_utils as vu
import numpy as np

class Verifier(vu.Verifier):

    OUTPUT_UIDS = ['output']

    def __init__(self):
        super().__init__()

    def get_actual_results(self):
        return self.get_output_from_symbol(self.OUTPUT_UIDS[0], 'double')

    def get_expected_results(self):
        length = int(self.get_input_from_symbol('length', 'uint32_t')[0])
        n_rows = int(self.get_input_from_symbol('n_rows', 'uint32_t')[0])
        n_clusters_per_row = int(self.get_input_from_symbol('n_clusters_per_row', 'uint32_t')[0])
        n_clusters_per_col = int(self.get_input_from_symbol('n_clusters_per_col', 'uint32_t')[0])
        mesh = np.fromfunction(
            lambda x, y, i: 15 + i + x + y * n_clusters_per_col,
            (n_rows, n_clusters_per_row, length),
            dtype=np.float64
        )
        result = mesh.sum(axis=(0, 1))
        return result.tolist()
        

    def check_results(self, *args):
        return super().check_results(*args, atol=1e-6)
    
if __name__ == "__main__":
    sys.exit(Verifier().main())