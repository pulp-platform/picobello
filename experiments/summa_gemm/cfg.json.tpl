// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

//{
//    setup_ssr: 1,
//    parallelize_m: 1,
//    parallelize_k: 0,
//    m_tiles: 4, // number of tiles in M dimension
//    n_tiles: ${4 * experiment['n_tiles']}, // number of tiles in N dimension
//    k_tiles: 1, // number of tiles in K dimension
//    load_a: 1,
//    load_b: 1,
//    load_c: 1,
//    double_buffer: 1,
//    partition_banks: 0,
//    transa: false,
//    transb: false, // must be true for SIMD
//    m: 32,
//    n: ${32 * experiment['n_tiles']},
//    k: 8,
//    alpha: 1,
//    beta: 0,
//    gemm_fp: "gemm_fp64_opt"
//}
{
    setup_ssr: 1,
    parallelize_m: 1,
    parallelize_k: 0,
    m_tiles: 4, // number of tiles in M dimension
    n_tiles: ${4 * experiment['n_tiles']}, // number of tiles in N dimension
    k_tiles: 1, // number of tiles in K dimension
    load_a: 1,
    load_b: 1,
    load_c: 1,
    double_buffer: 1,
    partition_banks: 0,
    transa: false,
    transb: false, // must be true for SIMD
    m: 64,
    n: ${64 * experiment['n_tiles']},
    k: 128,
    alpha: 1,
    beta: 0,
    gemm_fp: "gemm_fp64_opt"
}
