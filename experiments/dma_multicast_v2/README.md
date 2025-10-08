All commands are assumed to be run from this folder.

To run the experiments:
```shell
./sw_experiments.py --actions sw run visual-trace -j
```

To manually verify a simulation:
```shell
./verify.py placeholder <build_dir>/dma_multicast_v2.elf --no-ipc --memdump <sim_dir>/l2mem.bin --memaddr 0x70000000
```

To manually generate the traces for a simulation:
```shell
make -C ../../ annotate -j DEBUG=ON SIM_DIR=<sim_dir>
```

To manually build the visual trace for a simulation:
```shell
make -C ../../ sn-visual-trace -j DEBUG=ON SIM_DIR=<sim_dir> SN_ROI_SPEC=<sim_dir>/roi_spec.json
```

To fit the HW multicast model to the data:
```shell
./fit.py
```
Verify that `beta=1`, and plug `alpha`s in `model.py`. This file contains runtime models for the hardware and software multicast.

To plot the results (uses `model.py` behind the scenes):
```shell
./plot.py
```
