// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

#include "snrt.h"

#include "alloc.c"
#include "alloc_v2.c"
#include "cls.c"
#include "cluster_interrupts.c"
#include "dm.c"
#include "dma.c"
#include "eu.c"
#include "kmp.c"
#include "omp.c"
#include "printf.c"
#include "putchar.c"
#include "riscv.c"
#include "snitch_cluster_start.c"
#include "sync.c"
#include "team.c"
