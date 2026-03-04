## How to reproduce MLSys paper results

### General setup

```bash
source iis-env.sh
make all -j
make vsim-compile -j
make sw -j
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

### GEMM experiments (Fig. 8)

```bash
cd experiments/summa_gemm
./plot.py
```
