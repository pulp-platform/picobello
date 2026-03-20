## How to reproduce MLSys paper results

### General setup

```bash
source iis-env.sh
make init-pd
make all -j
make vsim-compile -j
make sw -j
make elab-cluster_tile
```

### Barrier experiments (Fig. 2b)

```bash
cd experiments/barrier
./experiments.py --actions sw run visual-trace -j
./plot.py
```

### Multicast experiments (Fig. 4)

```bash
cd experiments/multicast
./experiments.py --actions sw run visual-trace -j
./plot.py plot2 plot3 plot4
```

### Reduction experiments (Fig. 6)

```bash
cd experiments/reduction
./experiments.py --actions sw run visual-trace -j
./plot.py plot1 plot2
```

### GEMM performance experiments (Fig. 8)

```bash
cd experiments/summa_gemm
./plot.py
```

### GEMM energy experiments (Fig. 9)

```bash
cd experiments/summa_gemm
./experiments.py --actions sw run visual-trace
```

Annotate VCD:
```bash
make vsim-compile-chip NETLISTS=cluster_tile FUSION_RUN=latest VCD=ON
make vsim-run-chip CHS_BINARY=sw/cheshire/tests/simple_offload.spm.elf SN_BINARY=sw/snitch/apps/power_benchmarks/build/power_benchmarks.elf PRELMODE=3 VCD=ON VCD_START=342261ns VCD_DURATION=4510ns
```

Report Power:
```bash
primetime-2022.03 pt_shell -x "set RUN_NAME cluster_tile_latest; source power.tcl"
```

