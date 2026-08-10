// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module apb4_rtc #(
    parameter logic [31:0] RTC_CLOCK_HZ = 32'd32_768
) (
    apb4_if.slave apb4,
    rtc_if.dut    rtc
);

  import rtc_pkg::*;

  rtc_command_t        s_command_apb;
  rtc_command_t        s_command_rtc;
  rtc_response_t       s_response_rtc;
  rtc_response_t       s_response_apb;
  logic                s_command_valid_apb;
  logic                s_command_ready_apb;
  logic                s_command_valid_rtc;
  logic                s_command_ready_rtc;
  logic                s_response_valid_rtc;
  logic                s_response_ready_rtc;
  logic                s_response_valid_apb;
  logic                s_response_ready_apb;
  logic          [4:0] s_event_rtc;
  logic          [4:0] s_event_apb;
  logic          [4:0] s_interrupt_enable_rtc;
  logic          [4:0] s_interrupt_enable_apb;
  logic          [4:0] s_wake_enable_rtc;
  logic          [4:0] s_wake_enable_apb;
  logic          [4:0] s_status_rtc;
  logic          [4:0] s_status_apb;

  rtc_reg #(
      .RTC_CLOCK_HZ(RTC_CLOCK_HZ)
  ) u_rtc_reg (
      .pclk_i            (apb4.pclk),
      .presetn_i         (apb4.presetn),
      .paddr_i           (apb4.paddr[11:0]),
      .psel_i            (apb4.psel),
      .penable_i         (apb4.penable),
      .pwrite_i          (apb4.pwrite),
      .pwdata_i          (apb4.pwdata),
      .pstrb_i           (apb4.pstrb),
      .pready_o          (apb4.pready),
      .prdata_o          (apb4.prdata),
      .pslverr_o         (apb4.pslverr),
      .command_valid_o   (s_command_valid_apb),
      .command_ready_i   (s_command_ready_apb),
      .command_o         (s_command_apb),
      .response_valid_i  (s_response_valid_apb),
      .response_ready_o  (s_response_ready_apb),
      .response_i        (s_response_apb),
      .event_i           (s_event_apb),
      .interrupt_enable_i(s_interrupt_enable_apb),
      .wake_enable_i     (s_wake_enable_apb),
      .rtc_status_i      (s_status_apb),
      .irq_o             (rtc.irq_o)
  );

  async_reqack #(
      .DATA_WIDTH ($bits(rtc_command_t)),
      .SYNC_STAGES(2)
  ) u_command_mailbox (
      .src_clk_i  (apb4.pclk),
      .src_rst_n_i(apb4.presetn),
      .src_valid_i(s_command_valid_apb),
      .src_ready_o(s_command_ready_apb),
      .src_data_i (s_command_apb),
      .dst_clk_i  (rtc.rtc_clk_i),
      .dst_rst_n_i(rtc.rtc_rst_n_i),
      .dst_valid_o(s_command_valid_rtc),
      .dst_ready_i(s_command_ready_rtc),
      .dst_data_o (s_command_rtc)
  );

  async_reqack #(
      .DATA_WIDTH ($bits(rtc_response_t)),
      .SYNC_STAGES(2)
  ) u_response_mailbox (
      .src_clk_i  (rtc.rtc_clk_i),
      .src_rst_n_i(rtc.rtc_rst_n_i),
      .src_valid_i(s_response_valid_rtc),
      .src_ready_o(s_response_ready_rtc),
      .src_data_i (s_response_rtc),
      .dst_clk_i  (apb4.pclk),
      .dst_rst_n_i(apb4.presetn),
      .dst_valid_o(s_response_valid_apb),
      .dst_ready_i(s_response_ready_apb),
      .dst_data_o (s_response_apb)
  );

  rtc_core #(
      .RTC_CLOCK_HZ(RTC_CLOCK_HZ)
  ) u_rtc_core (
      .clk_i             (rtc.rtc_clk_i),
      .rst_n_i           (rtc.rtc_rst_n_i),
      .command_valid_i   (s_command_valid_rtc),
      .command_ready_o   (s_command_ready_rtc),
      .command_i         (s_command_rtc),
      .response_valid_o  (s_response_valid_rtc),
      .response_ready_i  (s_response_ready_rtc),
      .response_o        (s_response_rtc),
      .event_o           (s_event_rtc),
      .interrupt_enable_o(s_interrupt_enable_rtc),
      .wake_enable_o     (s_wake_enable_rtc),
      .status_o          (s_status_rtc),
      .wake_o            (rtc.wake_o)
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(5)
  ) u_event_sync (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .dat_i  (s_event_rtc),
      .dat_o  (s_event_apb)
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(5)
  ) u_interrupt_enable_sync (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .dat_i  (s_interrupt_enable_rtc),
      .dat_o  (s_interrupt_enable_apb)
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(5)
  ) u_status_sync (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .dat_i  (s_status_rtc),
      .dat_o  (s_status_apb)
  );

  cdc_sync #(
      .STAGE     (2),
      .DATA_WIDTH(5)
  ) u_wake_enable_sync (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .dat_i  (s_wake_enable_rtc),
      .dat_o  (s_wake_enable_apb)
  );

endmodule
