# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# TB top
add wave -noupdate -group {tb} {/tb_picobello_fpga/*}

# DUT top
add wave -noupdate -group {picobello} -group {top} {/tb_picobello_fpga/dut/*}

# AXI4 host interface
add wave -noupdate -group {picobello} -group {host} -group {axi_host_req_i} {/tb_picobello_fpga/dut/axi_host_req_i}
add wave -noupdate -group {picobello} -group {host} -group {axi_host_rsp_o} {/tb_picobello_fpga/dut/axi_host_rsp_o}

# # AXI4 tg configuration interface
add wave -noupdate -group {picobello} -group {host} -group {axi_tg_cfg_req_i} {/tb_picobello_fpga/dut/axi_tg_cfg_req_i}
add wave -noupdate -group {picobello} -group {host} -group {axi_tg_cfg_rsp_o} {/tb_picobello_fpga/dut/axi_tg_cfg_rsp_o}

# Host AXI4-Lite interface
add wave -noupdate -group {picobello} -group {host} -group {axi_lite_tg_cfg_req_i} {/tb_picobello_fpga/dut/axi_lite_tg_cfg_req_i}
add wave -noupdate -group {picobello} -group {host} -group {axi_lite_tg_cfg_rsp_o} {/tb_picobello_fpga/dut/axi_lite_tg_cfg_rsp_o}

# Cluster tiles
add wave -noupdate -group {picobello} -group {cluster_tile[0]} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[0]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[0]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[0]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[0]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[0]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[0]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[1]} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[1]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[1]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[1]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[1]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[1]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[1]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[2]} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[2]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[2]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[2]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[2]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[2]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[2]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[3]} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[3]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[3]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[3]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[3]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[3]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[3]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[4]} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[4]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[4]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[4]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[4]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[4]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[4]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[5]} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[5]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[5]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[5]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[5]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[5]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[5]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[6]} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[6]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[6]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[6]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[6]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[6]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[6]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[7]} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[7]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[7]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[7]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[7]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[7]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[7]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[8]} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[8]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[8]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[8]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[8]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[8]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[8]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[9]} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[9]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[9]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[9]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[9]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[9]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[9]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[10]} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[10]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[10]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[10]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[10]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[10]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[10]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[11]} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[11]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[11]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[11]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[11]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[11]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[11]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[12]} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[12]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[12]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[12]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[12]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[12]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[12]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[13]} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[13]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[13]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[13]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[13]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[13]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[13]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[14]} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[14]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[14]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[14]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[14]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[14]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[14]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

add wave -noupdate -group {picobello} -group {cluster_tile[15]} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/*}
add wave -noupdate -group {picobello} -group {cluster_tile[15]} -group {router} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cluster_tile[15]} -group {ni} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cluster_tile[15]} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cluster_tile[15]} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cluster_tile[15]} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/gen_clusters[15]/i_cluster_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

# Memory tiles
add wave -noupdate -group {picobello} -group {mem_tile[0]} {/tb_picobello_fpga/dut/gen_memtile[0]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[0]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[0]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[0]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[0]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[0]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[0]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[1]} {/tb_picobello_fpga/dut/gen_memtile[1]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[1]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[1]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[1]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[1]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[1]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[1]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[2]} {/tb_picobello_fpga/dut/gen_memtile[2]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[2]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[2]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[2]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[2]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[2]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[2]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[3]} {/tb_picobello_fpga/dut/gen_memtile[3]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[3]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[3]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[3]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[3]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[3]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[3]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[4]} {/tb_picobello_fpga/dut/gen_memtile[4]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[4]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[4]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[4]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[4]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[4]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[4]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[5]} {/tb_picobello_fpga/dut/gen_memtile[5]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[5]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[5]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[5]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[5]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[5]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[5]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[6]} {/tb_picobello_fpga/dut/gen_memtile[6]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[6]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[6]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[6]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[6]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[6]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[6]/i_mem_tile/i_axi_to_obi/*}

add wave -noupdate -group {picobello} -group {mem_tile[7]} {/tb_picobello_fpga/dut/gen_memtile[7]/i_mem_tile/*}
add wave -noupdate -group {picobello} -group {mem_tile[7]} -group {router} {/tb_picobello_fpga/dut/gen_memtile[7]/i_mem_tile/i_router/*}
add wave -noupdate -group {picobello} -group {mem_tile[7]} -group {ni} {/tb_picobello_fpga/dut/gen_memtile[7]/i_mem_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {mem_tile[7]} -group {axi_to_obi} {/tb_picobello_fpga/dut/gen_memtile[7]/i_mem_tile/i_axi_to_obi/*}

# Cheshire tile
add wave -noupdate -group {picobello} -group {cheshire_tile} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/*}
add wave -noupdate -group {picobello} -group {cheshire_tile} -group {router} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/i_router/*}
add wave -noupdate -group {picobello} -group {cheshire_tile} -group {ni} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {cheshire_tile} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {cheshire_tile} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {cheshire_tile} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/i_cheshire_tg_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

# SPU tile
add wave -noupdate -group {picobello} -group {fhg_spu_tile} {/tb_picobello_fpga/dut/i_fhg_spu_tile/*}
add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {ni} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_chimney/*}
add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {router} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_router/*}
add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/*}
add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}

# Dummy tiles
add wave -noupdate -group {picobello} -group {dummy_tile[0]} {/tb_picobello_fpga/dut/gen_dummytiles[0]/i_dummy_tile/*}
add wave -noupdate -group {picobello} -group {dummy_tile[0]} -group {router} {/tb_picobello_fpga/dut/gen_dummytiles[0]/i_dummy_tile/i_router/*}

add wave -noupdate -group {picobello} -group {dummy_tile[1]} {/tb_picobello_fpga/dut/gen_dummytiles[1]/i_dummy_tile/*}
add wave -noupdate -group {picobello} -group {dummy_tile[1]} -group {router} {/tb_picobello_fpga/dut/gen_dummytiles[1]/i_dummy_tile/i_router/*}

quietly wave cursor active 1
configure wave -namecolwidth 271
configure wave -valuecolwidth 483
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update