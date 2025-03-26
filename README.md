# picobello 👌🏻

*picobello* is an open-source research platform focusing on AI and Machine Learning acceleration.

*picobello* is developed as part of the [PULP (Parallel Ultra-Low Power) project](https://pulp-platform.org/), a joint effort between ETH Zurich and the University of Bologna. *picobello* is also supported by the [EUPilot project](https://eupilot.eu), under the name MLS.

## 🚧 Getting started (currently in early development)
The first requirement you need to install is [Bender](https://github.com/pulp-platform/bender). Check if there is any pre-compiled release for your Operating System, otherwise follow the intructions to build your own binary using Rust.

At this point, the `make help` command prompts all the available make options on your terminal.

### RTL code generation
Generate the RTL code for Cheshire, FlooNoC, and Snitch by running `make all`.

### Compile software tests
Compiling the software tests requires two different toolchains to be exported.
* Snitch software tests require the Clang compiler extended with Snitch-specific instructions. There are some precompiled releases available on the [PULP Platform LLVM Project](https://github.com/pulp-platform/llvm-project/releases/download/0.12.0/riscv32-pulp-llvm-ubuntu2004-0.12.0.tar.gz) fork that are ready to be downloaded and unzipped.
* Cheshire requires a 64-bit GCC toolchain that can be installed from the [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) git following the *Installation (Newlib)* intructions.

Once LLVM and GCC are obtained, export a `LLVM_BINROOT` environment variable to the binary folder of the LLVM toolchain installation. Then, add the GCC binary folder to your `$PATH`.
Only at this point, run `make sw` to build the tests for both Cheshire and Snitch.

### Platform simulation
The Picobello simulation flow currently only supports Questasim. The `make vsim-compile` command will build the RTL code.
Tests can be executed by setting all the required command-line variable for Cheshire, see the [Cheshire Docs](https://pulp-platform.github.io/cheshire/gs/) for more details.
To run a simple Chehire helloworld in Picobello, do the following:
```
make vsim-run CHS_BINARY=sw/cheshire/tests/helloworld.spm.elf
```
To run an offloading example test for Snitch, do:
```
make vsim-run CHS_BINARY=sw/cheshire/tests/simple_offload.spm.elf SN_BINARY=sw/snitch/tests/build/simple.elf
```
Use the `vsim-run-batch` command to run tests in batch mode with RTL optimizations to reduce the Questasim runtime.

## 🔐 License
Unless specified otherwise in the respective file headers, all code checked into this repository is made available under a permissive license. All hardware sources are licensed under the Solderpad Hardware License 0.51 (see [`LICENSE`](LICENSE)), and all software sources are licensed under the Apache License 2.0.
