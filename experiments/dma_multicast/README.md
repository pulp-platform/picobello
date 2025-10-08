From the present directory:
```shell
./experiments.py --actions sw run -j
```

Run `dma_multicast_v2.elf`:
```shell
questa-2023.4 vsim -work /usr/scratch2/vulcano/colluca/workspace/REPOS/PICOBELLO/dca-snitch/target/sim/vsim/work -suppress 3009 -suppress 8386 -suppress 13314 -quiet -64 +CHS_BINARY=sw/cheshire/tests/simple_offload.spm.elf +SN_BINARY=sw/snitch/tests/build/dma_multicast_v2.elf +PRELMODE=3 -voptargs=+acc tb_picobello_top -do "log -r /*; do wave.do; run -a;"
```

Verify `dma_multicast_v2.elf`:
```shell
./experiments/mcast/verify.py placeholder $PWD/sw/snitch/tests/build/dma_multicast_v2.elf --no-ipc --memdump $PWD/l2mem.bin --memaddr 0x70000000
```