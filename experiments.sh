#!/bin/bash

TRAN_LEN_VALUES=(256 512 1024 2048 4096 8192)
MODE_VALUES=(SW_UNOPT SW_OPT SW_OPT2)
N_CLUSTERS_VALUES=(4 8 16)

for N_CLUSTERS in "${N_CLUSTERS_VALUES[@]}"; do
  for MODE in "${MODE_VALUES[@]}"; do
    for TRAN_LEN in "${TRAN_LEN_VALUES[@]}"; do

      echo "=== Running with TRAN_LEN=${TRAN_LEN}, MODE=${MODE}, N_CLUSTERS=${N_CLUSTERS} ==="

      # Remove old ELF
      rm -f sw/snitch/tests/build/dma_multicast.elf

      # Build
      make sw DEBUG=ON TRAN_LEN=${TRAN_LEN} MODE=${MODE} N_CLUSTERS=${N_CLUSTERS} -j

      # Run simulation
      make vsim-run-batch CHS_BINARY=sw/cheshire/tests/simple_offload.spm.elf \
                          SN_BINARY=sw/snitch/tests/build/dma_multicast.elf \
                          PRELMODE=3

      # Annotate
      make annotate DEBUG=ON -j

      # Move logs
      DEST_DIR="logs_${TRAN_LEN}_${MODE}_${N_CLUSTERS}"
      mkdir -p results/"${DEST_DIR}"
      mv logs/*.s results/"${DEST_DIR}"

      echo "Logs saved to results/${DEST_DIR}"
      echo "------------------------------------------------------------"

    done
  done
done
