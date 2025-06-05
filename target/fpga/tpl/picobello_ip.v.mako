// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
  
module picobello_ip (
  ${port('clk', 1, False)},\
  ${port('rst', 1, False, True)},
  ${axi_ports('slv', False, aw_ps2pl, dw, iw_ps2pl, uw_ps2pl)}
);

  ${logic(iw)} slv_aw_id;     
  ${logic(iw)} slv_b_id;                   
  ${logic(iw)} slv_ar_id;        
  ${logic(iw)} slv_r_id;
  
  ${logic(aw)} slv_aw_addr;                               
  ${logic(aw)} slv_ar_addr;     

  ${logic(8)} slv_aw_len;                                
  ${logic(8)} slv_ar_len;

  ${logic(3)} slv_aw_size;     
  ${logic(3)} slv_ar_size;

  ${logic(2)} slv_aw_burst;    
  ${logic(2)} slv_ar_burst;

  ${logic(1)} slv_aw_lock;     
  ${logic(1)} slv_ar_lock;
  
  ${logic(4)} slv_aw_cache;    
  ${logic(4)} slv_ar_cache;
  
  ${logic(3)} slv_aw_prot;     
  ${logic(3)} slv_ar_prot;
  
  ${logic(4)} slv_aw_qos;      
  ${logic(4)} slv_ar_qos;

  ${logic(4)} slv_aw_region;   
  ${logic(4)} slv_ar_region;
  
  ${logic(6)} slv_aw_atop;
  
  ${logic(uw)} slv_aw_user;   
  ${logic(uw)} slv_b_user;   
  ${logic(uw)} slv_w_user;   
  ${logic(uw)} slv_ar_user;      
  ${logic(uw)} slv_r_user;
           
  ${logic(1)} slv_aw_valid;  
  ${logic(1)} slv_b_valid;  
  ${logic(1)} slv_w_valid;  
  ${logic(1)} slv_ar_valid;     
  ${logic(1)} slv_r_valid;
  ${logic(1)} slv_aw_ready;  
  ${logic(1)} slv_b_ready;  
  ${logic(1)} slv_w_ready;  
  ${logic(1)} slv_ar_ready;     
  ${logic(1)} slv_r_ready;
    
  ${logic(dw)} slv_w_data;        
  ${logic(dw)} slv_r_data;
     
  ${logic(dw/8)} slv_w_strb;
    
  ${logic(2)} slv_b_resp;         
  ${logic(2)} slv_r_resp;
  
  ${logic(1)} slv_w_last;        
  ${logic(1)} slv_r_last;
 
  axi_iw_converter_flat #(
    .AXI_SLV_PORT_ID_WIDTH        (${iw_ps2pl}),
    .AXI_MST_PORT_ID_WIDTH        (${iw}),
    .AXI_SLV_PORT_MAX_UNIQ_IDS    (4),
    .AXI_SLV_PORT_MAX_TXNS_PER_ID (1),
    .AXI_SLV_PORT_MAX_TXNS        (4),
    .AXI_MST_PORT_MAX_UNIQ_IDS    (4),
    .AXI_MST_PORT_MAX_TXNS_PER_ID (1),
    .AXI_ADDR_WIDTH               (${aw}),
    .AXI_DATA_WIDTH               (${dw}),
    .AXI_USER_WIDTH               (${uw})
  ) i_iw_converter_slv (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),

    .slv_aw_id_i     (slv_aw_id_i),
    .slv_aw_addr_i   ({{${aw-aw_ps2pl}{1'b0}}, slv_aw_addr_i}),
    .slv_aw_len_i    (slv_aw_len_i),
    .slv_aw_size_i   (slv_aw_size_i),
    .slv_aw_burst_i  (slv_aw_burst_i),
    .slv_aw_lock_i   (slv_aw_lock_i),
    .slv_aw_cache_i  (slv_aw_cache_i),
    .slv_aw_prot_i   (slv_aw_prot_i),
    .slv_aw_qos_i    (slv_aw_qos_i),
    .slv_aw_region_i ({4{1'b0}}),
    .slv_aw_atop_i   ({6{1'b0}}),
    .slv_aw_user_i   (slv_aw_user_i[${uw-1}:0]),
    .slv_aw_valid_i  (slv_aw_valid_i),
    .slv_aw_ready_o  (slv_aw_ready_o),
    .slv_w_data_i    (slv_w_data_i),
    .slv_w_strb_i    (slv_w_strb_i),
    .slv_w_last_i    (slv_w_last_i),
    .slv_w_user_i    ({${uw}{1'b0}}),
    .slv_w_valid_i   (slv_w_valid_i),
    .slv_w_ready_o   (slv_w_ready_o),
    .slv_b_id_o      (slv_b_id_o),
    .slv_b_resp_o    (slv_b_resp_o),
    .slv_b_user_o    (/* unused */),
    .slv_b_valid_o   (slv_b_valid_o),
    .slv_b_ready_i   (slv_b_ready_i),
    .slv_ar_id_i     (slv_ar_id_i),
    .slv_ar_addr_i   ({{${aw-aw_ps2pl}{1'b0}}, slv_ar_addr_i}),
    .slv_ar_len_i    (slv_ar_len_i),
    .slv_ar_size_i   (slv_ar_size_i),
    .slv_ar_burst_i  (slv_ar_burst_i),
    .slv_ar_lock_i   (slv_ar_lock_i),
    .slv_ar_cache_i  (slv_ar_cache_i),
    .slv_ar_prot_i   (slv_ar_prot_i),
    .slv_ar_qos_i    (slv_ar_qos_i),
    .slv_ar_region_i ({4{1'b0}}),
    .slv_ar_user_i   (slv_ar_user_i[${uw-1}:0]),
    .slv_ar_valid_i  (slv_ar_valid_i),
    .slv_ar_ready_o  (slv_ar_ready_o),
    .slv_r_id_o      (slv_r_id_o),
    .slv_r_data_o    (slv_r_data_o),
    .slv_r_resp_o    (slv_r_resp_o),
    .slv_r_last_o    (slv_r_last_o),
    .slv_r_user_o    (/* unused */),
    .slv_r_valid_o   (slv_r_valid_o),
    .slv_r_ready_i   (slv_r_ready_i),

    .mst_aw_id_o      (slv_aw_id),
    .mst_aw_addr_o    (slv_aw_addr),
    .mst_aw_len_o     (slv_aw_len),
    .mst_aw_size_o    (slv_aw_size),
    .mst_aw_burst_o   (slv_aw_burst),
    .mst_aw_lock_o    (slv_aw_lock),
    .mst_aw_cache_o   (slv_aw_cache),
    .mst_aw_prot_o    (slv_aw_prot),
    .mst_aw_qos_o     (slv_aw_qos),
    .mst_aw_region_o  (slv_aw_region),
    .mst_aw_atop_o    (slv_aw_atop),
    .mst_aw_user_o    (slv_aw_user),
    .mst_aw_valid_o   (slv_aw_valid),
    .mst_aw_ready_i   (slv_aw_ready),
    .mst_w_data_o     (slv_w_data),
    .mst_w_strb_o     (slv_w_strb),
    .mst_w_last_o     (slv_w_last),
    .mst_w_user_o     (slv_w_user),
    .mst_w_valid_o    (slv_w_valid),
    .mst_w_ready_i    (slv_w_ready),
    .mst_b_id_i       (slv_b_id),
    .mst_b_resp_i     (slv_b_resp),
    .mst_b_user_i     (slv_b_user),
    .mst_b_valid_i    (slv_b_valid),
    .mst_b_ready_o    (slv_b_ready),
    .mst_ar_id_o      (slv_ar_id),
    .mst_ar_addr_o    (slv_ar_addr),
    .mst_ar_len_o     (slv_ar_len),
    .mst_ar_size_o    (slv_ar_size),
    .mst_ar_burst_o   (slv_ar_burst),
    .mst_ar_lock_o    (slv_ar_lock),
    .mst_ar_cache_o   (slv_ar_cache),
    .mst_ar_prot_o    (slv_ar_prot),
    .mst_ar_qos_o     (slv_ar_qos),
    .mst_ar_region_o  (slv_ar_region),
    .mst_ar_user_o    (slv_ar_user),
    .mst_ar_valid_o   (slv_ar_valid),
    .mst_ar_ready_i   (slv_ar_ready),
    .mst_r_id_i       (slv_r_id),
    .mst_r_data_i     (slv_r_data),
    .mst_r_resp_i     (slv_r_resp),
    .mst_r_last_i     (slv_r_last),
    .mst_r_user_i     (slv_r_user),
    .mst_r_valid_i    (slv_r_valid),
    .mst_r_ready_o    (slv_r_ready)
  );
  
  fpga_picobello_top_wrapper i_picobello_top_wrapper (
    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni), 
    .axi_host_in_aw_id_i      (slv_aw_id),
    .axi_host_in_aw_addr_i    (slv_aw_addr),
    .axi_host_in_aw_len_i     (slv_aw_len),
    .axi_host_in_aw_size_i    (slv_aw_size),
    .axi_host_in_aw_burst_i   (slv_aw_burst),
    .axi_host_in_aw_lock_i    (slv_aw_lock),
    .axi_host_in_aw_cache_i   (slv_aw_cache),
    .axi_host_in_aw_prot_i    (slv_aw_prot),
    .axi_host_in_aw_qos_i     (slv_aw_qos),
    .axi_host_in_aw_region_i  (slv_aw_region),
    .axi_host_in_aw_atop_i    (slv_aw_atop),
    .axi_host_in_aw_user_i    (slv_aw_user),
    .axi_host_in_aw_valid_i   (slv_aw_valid),
    .axi_host_in_aw_ready_o   (slv_aw_ready),
    .axi_host_in_w_data_i     (slv_w_data),
    .axi_host_in_w_strb_i     (slv_w_strb),
    .axi_host_in_w_last_i     (slv_w_last),
    .axi_host_in_w_user_i     (slv_w_user),
    .axi_host_in_w_valid_i    (slv_w_valid),
    .axi_host_in_w_ready_o    (slv_w_ready),
    .axi_host_in_b_id_o       (slv_b_id),
    .axi_host_in_b_resp_o     (slv_b_resp),
    .axi_host_in_b_user_o     (slv_b_user),
    .axi_host_in_b_valid_o    (slv_b_valid),
    .axi_host_in_b_ready_i    (slv_b_ready),
    .axi_host_in_ar_id_i      (slv_ar_id),
    .axi_host_in_ar_addr_i    (slv_ar_addr),
    .axi_host_in_ar_len_i     (slv_ar_len),
    .axi_host_in_ar_size_i    (slv_ar_size),
    .axi_host_in_ar_burst_i   (slv_ar_burst),
    .axi_host_in_ar_lock_i    (slv_ar_lock),
    .axi_host_in_ar_cache_i   (slv_ar_cache),
    .axi_host_in_ar_prot_i    (slv_ar_prot),
    .axi_host_in_ar_qos_i     (slv_ar_qos),
    .axi_host_in_ar_region_i  (slv_ar_region),
    .axi_host_in_ar_user_i    (slv_ar_user),
    .axi_host_in_ar_valid_i   (slv_ar_valid),
    .axi_host_in_ar_ready_o   (slv_ar_ready),
    .axi_host_in_r_id_o       (slv_r_id),
    .axi_host_in_r_data_o     (slv_r_data),
    .axi_host_in_r_resp_o     (slv_r_resp),
    .axi_host_in_r_last_o     (slv_r_last),
    .axi_host_in_r_user_o     (slv_r_user),
    .axi_host_in_r_valid_o    (slv_r_valid),
    .axi_host_in_r_ready_i    (slv_r_ready)
  );

endmodule

<%
  # Definition of template-based functions to support generation
%>

<%def name="logic(width)">\
  <%
    if width == 1:
      typ = 'wire        '
    else:
      typ = "wire [%3d:0]" % (width - 1)
  %>
  ${typ}\
</%def>\
<%def name="port(name, width, output, active_low=False)">\
  <%
    if output:
      direction = 'output'
      suffix = 'o'
    else:
      direction = 'input '
      suffix = 'i'
    if width == 1:
      typ = '        '
    else:
      typ = "[%3d:0] " % (width - 1)
    if active_low:
      suffix = 'n' + suffix
    name = name + '_' + suffix
  %>
  % if width > 0:
  ${direction} ${typ} ${name}\
  % endif
</%def>\
<%def name="axi_ax_ports(prefix, master, aw, iw, uw)">\
  ${port(prefix + '_id', iw, master)},\
  ${port(prefix + '_addr', aw, master)},\
  ${port(prefix + '_len', 8, master)},\
  ${port(prefix + '_size', 3, master)},\
  ${port(prefix + '_burst', 2, master)},\
  ${port(prefix + '_lock', 1, master)},\
  ${port(prefix + '_cache', 4, master)},\
  ${port(prefix + '_prot', 3, master)},\
  ${port(prefix + '_qos', 4, master)},\
  ${port(prefix + '_user', uw, master)},\
  ${port(prefix + '_valid', 1, master)},\
  ${port(prefix + '_ready', 1, not master)}\
</%def>\
<%def name="axi_w_ports(prefix, master, dw)">\
  ${port(prefix + '_data', dw, master)},\
  ${port(prefix + '_strb', dw/8, master)},\
  ${port(prefix + '_last', 1, master)},\
  ${port(prefix + '_valid', 1, master)},\
  ${port(prefix + '_ready', 1, not master)}\
</%def>\
<%def name="axi_b_ports(prefix, master, iw)">\
  ${port(prefix + '_id', iw, not master)},\
  ${port(prefix + '_resp', 2, not master)},\
  ${port(prefix + '_valid', 1, not master)},\
  ${port(prefix + '_ready', 1, master)}\
</%def>\
<%def name="axi_r_ports(prefix, master, dw, iw)">\
  ${port(prefix + '_id', iw, not master)},\
  ${port(prefix + '_data', dw, not master)},\
  ${port(prefix + '_resp', 2, not master)},\
  ${port(prefix + '_last', 1, not master)},\
  ${port(prefix + '_valid', 1, not master)},\
  ${port(prefix + '_ready', 1, master)}\
</%def>\
<%def name="axi_ports(prefix, master, aw, dw, iw, uw)">\
  ${axi_ax_ports(prefix + '_aw', master, aw, iw, uw)},\
  ${axi_w_ports(prefix + '_w', master, dw)},\
  ${axi_b_ports(prefix + '_b', master, iw)},\
  ${axi_ax_ports(prefix + '_ar', master, aw, iw, uw)},\
  ${axi_r_ports(prefix + '_r', master, dw, iw)}\
</%def>\
<%def name="axi_lite_ax_ports(prefix, master, aw)">\
  ${port(prefix + '_addr', aw, master)},\
  ${port(prefix + '_prot', 3, master)},\
  ${port(prefix + '_valid', 1, master)},\
  ${port(prefix + '_ready', 1, not master)}\
</%def>\
<%def name="axi_lite_w_ports(prefix, master, dw)">\
  ${port(prefix + '_data', dw, master)},\
  ${port(prefix + '_strb', dw/8, master)},\
  ${port(prefix + '_valid', 1, master)},\
  ${port(prefix + '_ready', 1, not master)}\
</%def>\
<%def name="axi_lite_b_ports(prefix, master)">\
  ${port(prefix + '_resp', 2, not master)},\
  ${port(prefix + '_valid', 1, not master)},\
  ${port(prefix + '_ready', 1, master)}\
</%def>\
<%def name="axi_lite_r_ports(prefix, master, dw)">\
  ${port(prefix + '_data', dw, not master)},\
  ${port(prefix + '_resp', 2, not master)},\
  ${port(prefix + '_valid', 1, not master)},\
  ${port(prefix + '_ready', 1, master)}\
</%def>\
<%def name="axi_lite_ports(prefix, master, aw, dw)">\
  ${axi_lite_ax_ports(prefix + '_aw', master, aw)},\
  ${axi_lite_w_ports(prefix + '_w', master, dw)},\
  ${axi_lite_b_ports(prefix + '_b', master)},\
  ${axi_lite_ax_ports(prefix + '_ar', master, aw)},\
  ${axi_lite_r_ports(prefix + '_r', master, dw)}\
</%def>\
