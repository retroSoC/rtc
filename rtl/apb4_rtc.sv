// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// rtc is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.svh"
`include "rtc_define.svh"

module apb4_rtc (
`ifdef __VERILOG__
    `apb4_slave_if(apb4),
    input  rtc_rtc_clk_i,
    input  rtc_rtc_rst_n_i,
    output rtc_irq_o
`else
    apb4_if.slave apb4,
    rtc_if.dut    rtc
`endif
);

`ifndef __VERILOG__
  `apb4_slave_if2wire(apb4, apb4);
  logic rtc_rtc_clk_i = rtc.rtc_clk_i;
  logic rtc_rtc_rst_n_i = rtc.rtc_rst_n_i;
  logic rtc_irq_o;
  assign rtc.rtc_irq_o = rtc_irq_o;
`endif

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`RTC_CTRL_WIDTH-1:0] s_rtc_ctrl_d, s_rtc_ctrl_q;
  logic s_rtc_ctrl_en;
  logic [`RTC_PSCR_WIDTH-1:0] s_rtc_pscr_d, s_rtc_pscr_q;
  logic s_rtc_pscr_en;
  logic [`RTC_CNT_WIDTH-1:0] s_rtc_cnt_d, s_rtc_cnt_q;
  logic s_rtc_cnt_en;
  logic [`RTC_ALRM_WIDTH-1:0] s_rtc_alrm_d, s_rtc_alrm_q;
  logic s_rtc_alrm_en;
  logic [`RTC_ISTA_WIDTH-1:0] s_rtc_ista_d, s_rtc_ista_q;
  logic [`RTC_SSTA_WIDTH-1:0] s_rtc_ssta_d, s_rtc_ssta_q;
  logic s_valid, s_done, s_done_sync, s_tc_trg, s_normal_mode;
  logic s_bit_cmf, s_bit_scie, s_bit_alrmie, s_bit_ovie, s_bit_en;
  logic s_bit_scif, s_bit_alrmif, s_bit_ovif, s_bit_rsynf, s_bit_lwoff;
  logic s_ov_irq_trg, s_alrm_irq_trg, s_tick_irq_trg;
  logic s_rtc_wr_valid, s_wr_pready, s_rd_pready, s_rd_pready_sync;
  logic s_wr_src_valid, s_wr_dst_valid, s_rd_src_valid, s_rd_dst_valid;
  logic [`RTC_CNT_WIDTH-1:0] s_wr_dst_data, s_rd_dst_data;
  logic [`RTC_CNT_WIDTH-1:0] s_rd_dst_tmp_d, s_rd_dst_tmp_q;
  logic s_rd_dst_tmp_en;
  logic s_wr_pready_re, s_rd_pready_sync_re;

  assign s_apb4_addr     = apb4_paddr[5:2];
  assign s_apb4_wr_hdshk = apb4_psel && apb4_penable && apb4_pwrite;
  assign s_apb4_rd_hdshk = apb4_psel && apb4_penable && (~apb4_pwrite);
  assign apb4_pslverr    = 1'b0;

  assign s_bit_cmf       = s_rtc_ctrl_q[0];
  assign s_bit_scie      = s_rtc_ctrl_q[1];
  assign s_bit_alrmie    = s_rtc_ctrl_q[2];
  assign s_bit_ovie      = s_rtc_ctrl_q[3];
  assign s_bit_en        = s_rtc_ctrl_q[4];
  assign s_bit_scif      = s_rtc_ista_q[0];
  assign s_bit_alrmif    = s_rtc_ista_q[1];
  assign s_bit_ovif      = s_rtc_ista_q[2];
  assign s_bit_rsynf     = s_rtc_ssta_q[0];
  assign s_bit_lwoff     = s_rtc_ssta_q[1];
  assign s_normal_mode   = s_bit_en & s_done_sync;
  assign s_rtc_wr_valid  = s_bit_cmf & s_bit_lwoff;
  assign rtc_irq_o       = |s_rtc_ista_q;

  edge_det_re #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_wr_pready_edge_det_re (
      .clk_i  (apb4_pclk),
      .rst_n_i(apb4_presetn),
      .dat_i  (s_wr_pready),
      .re_o   (s_wr_pready_re)
  );

  edge_det_re #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_rd_pready_sync_edge_det_re (
      .clk_i  (apb4_pclk),
      .rst_n_i(apb4_presetn),
      .dat_i  (s_rd_pready_sync),
      .re_o   (s_rd_pready_sync_re)
  );

  // backpressure
  assign apb4_pready = (s_apb4_addr == `RTC_CNT) ? (apb4_pwrite ? s_wr_pready_re : s_rd_pready_sync_re) : 1'b1;

  assign s_rtc_ctrl_en = s_apb4_wr_hdshk && s_apb4_addr == `RTC_CTRL;
  assign s_rtc_ctrl_d  = apb4_pwdata[`RTC_CTRL_WIDTH-1:0];
  dffer #(`RTC_CTRL_WIDTH) u_rtc_ctrl_dffer (
      apb4_pclk,
      apb4_presetn,
      s_rtc_ctrl_en,
      s_rtc_ctrl_d,
      s_rtc_ctrl_q
  );

  assign s_rtc_pscr_en = s_apb4_wr_hdshk && s_apb4_addr == `RTC_PSCR && s_rtc_wr_valid;
  assign s_rtc_pscr_d  = apb4_pwdata[`RTC_PSCR_WIDTH-1:0];
  dffer #(`RTC_PSCR_WIDTH) u_rtc_pscr_dffer (
      apb4_pclk,
      apb4_presetn,
      s_rtc_pscr_en,
      s_rtc_pscr_d,
      s_rtc_pscr_q
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_clk_div_done_cdc_sync (
      apb4_pclk,
      apb4_presetn,
      s_done,
      s_done_sync
  );

  cdc_2phase #(1) u_clk_div_valid_2phase (
      .src_clk_i  (apb4_pclk),
      .src_rst_n_i(apb4_presetn),
      .src_data_i (s_apb4_wr_hdshk && s_apb4_addr == `RTC_PSCR && s_rtc_wr_valid && s_done_sync),
      .src_valid_i(s_apb4_wr_hdshk && s_apb4_addr == `RTC_PSCR && s_rtc_wr_valid && s_done_sync),
      .src_ready_o(),

      .dst_clk_i  (rtc_rtc_clk_i),
      .dst_rst_n_i(rtc_rtc_rst_n_i),
      .dst_data_o (),
      .dst_valid_o(s_valid),
      .dst_ready_i(1'b1)
  );
  clk_int_div_simple #(`RTC_PSCR_WIDTH) u_clk_int_div_simple (
      .clk_i        (rtc_rtc_clk_i),
      .rst_n_i      (rtc_rtc_rst_n_i),
      .div_i        (s_rtc_pscr_q),
      .clk_init_i   (1'b0),
      .div_valid_i  (s_valid),
      .div_ready_o  (),
      .div_done_o   (s_done),
      .clk_cnt_o    (),
      .clk_fir_trg_o(),
      .clk_sec_trg_o(s_tc_trg),
      .clk_o        ()
  );

  assign s_wr_src_valid = s_apb4_wr_hdshk && s_apb4_addr == `RTC_CNT && s_rtc_wr_valid;
  cdc_2phase #(`RTC_CNT_WIDTH) u_wr_cdc_2phase (
      .src_clk_i  (apb4_pclk),
      .src_rst_n_i(apb4_presetn),
      .src_data_i (apb4_pwdata[`RTC_CNT_WIDTH-1:0]),
      .src_valid_i(s_wr_src_valid),
      .src_ready_o(s_wr_pready),

      .dst_clk_i  (rtc_rtc_clk_i),
      .dst_rst_n_i(rtc_rtc_rst_n_i),
      .dst_data_o (s_wr_dst_data),
      .dst_valid_o(s_wr_dst_valid),
      .dst_ready_i(s_tc_trg)
  );


  cdc_2phase #(1) u_rd_src_valid_2phase (
      .src_clk_i  (apb4_pclk),
      .src_rst_n_i(apb4_presetn),
      .src_data_i (s_apb4_rd_hdshk && s_apb4_addr == `RTC_CNT),
      .src_valid_i(s_apb4_rd_hdshk && s_apb4_addr == `RTC_CNT),
      .src_ready_o(),

      .dst_clk_i  (rtc_rtc_clk_i),
      .dst_rst_n_i(rtc_rtc_rst_n_i),
      .dst_data_o (),
      .dst_valid_o(s_rd_src_valid),
      .dst_ready_i(s_tc_trg)
  );

  cdc_2phase #(`RTC_CNT_WIDTH) u_rd_cdc_2phase (
      .src_clk_i  (rtc_rtc_clk_i),
      .src_rst_n_i(rtc_rtc_rst_n_i),
      .src_data_i (s_rtc_cnt_q),
      .src_valid_i(s_rd_src_valid && s_tc_trg),
      .src_ready_o(s_rd_pready),

      .dst_clk_i  (apb4_pclk),
      .dst_rst_n_i(apb4_presetn),
      .dst_data_o (s_rd_dst_data),
      .dst_valid_o(s_rd_dst_valid),
      .dst_ready_i(1'b1)
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_rd_pready_cdc_sync (
      apb4_pclk,
      apb4_presetn,
      s_rd_pready,
      s_rd_pready_sync
  );

  assign s_rd_dst_tmp_en = s_rd_dst_valid;
  assign s_rd_dst_tmp_d  = s_rd_dst_data;
  dffer #(`RTC_CNT_WIDTH) u_rd_dst_tmp_dffer (
      apb4_pclk,
      apb4_presetn,
      s_rd_dst_tmp_en,
      s_rd_dst_tmp_d,
      s_rd_dst_tmp_q
  );

  assign s_rtc_cnt_en = s_wr_dst_valid || (s_normal_mode && s_tc_trg);
  always_comb begin
    s_rtc_cnt_d = s_rtc_cnt_q;
    if (s_wr_dst_valid) begin  // cdc data is prepared
      s_rtc_cnt_d = s_wr_dst_data;
    end else if (s_normal_mode) begin
      s_rtc_cnt_d = s_rtc_cnt_q + 1'b1;
    end
  end
  dffer #(`RTC_CNT_WIDTH) u_rtc_cnt_dffer (
      rtc_rtc_clk_i,
      rtc_rtc_rst_n_i,
      s_rtc_cnt_en,
      s_rtc_cnt_d,
      s_rtc_cnt_q
  );

  assign s_rtc_alrm_en = s_apb4_wr_hdshk && s_apb4_addr == `RTC_ALRM && s_rtc_wr_valid;
  assign s_rtc_alrm_d  = apb4_pwdata[`RTC_ALRM_WIDTH-1:0];
  dffer #(`RTC_ALRM_WIDTH) u_rtc_alrm_dffer (
      apb4_pclk,
      apb4_presetn,
      s_rtc_alrm_en,
      s_rtc_alrm_d,
      s_rtc_alrm_q
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_ov_irq_cdc_sync (
      apb4_pclk,
      apb4_presetn,
      s_rtc_cnt_q == 32'hFFFF_FFFE,
      s_ov_irq_trg
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_alrm_irq_cdc_sync (
      apb4_pclk,
      apb4_presetn,
      s_rtc_cnt_q >= s_rtc_alrm_q,
      s_alrm_irq_trg
  );

  edge_det_re #(
      .STAGE     (2),
      .DATA_WIDTH(1)
  ) u_tick_edge_det_re (
      .clk_i  (apb4_pclk),
      .rst_n_i(apb4_presetn),
      .dat_i  (s_tc_trg),
      .re_o   (s_tick_irq_trg)
  );

  always_comb begin
    s_rtc_ista_d = s_rtc_ista_q;
    if (rtc_irq_o && s_apb4_rd_hdshk && s_apb4_addr == `RTC_ISTA) begin
      s_rtc_ista_d = '0;
    end else if (~s_bit_ovif && s_bit_en && s_bit_ovie && s_ov_irq_trg) begin
      s_rtc_ista_d[2] = 1'b1;
    end else if (~s_bit_alrmif && s_bit_en && s_bit_alrmie && s_alrm_irq_trg) begin
      s_rtc_ista_d[1] = 1'b1;
    end else if (~s_bit_scif && s_bit_en && s_bit_scie && s_tick_irq_trg) begin
      s_rtc_ista_d[0] = 1'b1;
    end
  end
  dffr #(`RTC_ISTA_WIDTH) u_rtc_ista_dffr (
      apb4_pclk,
      apb4_presetn,
      s_rtc_ista_d,
      s_rtc_ista_q
  );

  assign s_rtc_ssta_d[0] = s_rd_dst_valid;
  assign s_rtc_ssta_d[1] = s_wr_pready;
  dffr #(`RTC_SSTA_WIDTH) u_rtc_ssta_dffr (
      apb4_pclk,
      apb4_presetn,
      s_rtc_ssta_d,
      s_rtc_ssta_q
  );

  always_comb begin
    apb4_prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `RTC_CTRL: apb4_prdata[`RTC_CTRL_WIDTH-1:0] = s_rtc_ctrl_q;
        `RTC_PSCR: apb4_prdata[`RTC_PSCR_WIDTH-1:0] = s_rtc_pscr_q;
        `RTC_CNT:  apb4_prdata[`RTC_CNT_WIDTH-1:0] = s_rd_pready_sync ? s_rd_dst_tmp_q : '0;
        `RTC_ALRM: apb4_prdata[`RTC_ALRM_WIDTH-1:0] = s_rtc_alrm_q;
        `RTC_ISTA: apb4_prdata[`RTC_ISTA_WIDTH-1:0] = s_rtc_ista_q;
        `RTC_SSTA: apb4_prdata[`RTC_SSTA_WIDTH-1:0] = s_rtc_ssta_q;
        default:   apb4_prdata = '0;
      endcase
    end
  end
endmodule
