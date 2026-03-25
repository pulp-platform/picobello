// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
[
    {
        // DMA core of cluster 0
        "thread": "${f'hart_9'}",
        "roi": [
            // First iteration
            {"idx": 1, "label": "init"},
            {"idx": 2, "label": "transfer"},
            // Second iteration
            {"idx": 4, "label": "init"},
            {"idx": 5, "label": "transfer"},
        ]
    },
]
