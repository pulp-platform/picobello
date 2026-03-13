#!/usr/bin/env python3
# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import sys

import numpy as np
import snitch.util.sim.data_utils as du


np.random.seed(42)


class TemplateDataGen(du.DataGen):

    def emit_header(self, **kwargs):
        header = [super().emit_header()]

        m = kwargs['m']

        mat = du.generate_random_array((m, m), 8, seed=42).flatten()

        header += [du.format_scalar_definition('extern const uint32_t', 'M', m)]
        header += [du.format_array_declaration('extern double', 'mat', mat.shape)]
        header += [du.format_array_definition('double', 'mat', mat,
                                              section=kwargs.get('section'))]

        header = '\n\n'.join(header)
        return header


if __name__ == '__main__':
    sys.exit(TemplateDataGen().main())
