// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps

`include "rtc_define.svh"

module apb4_rtc_tb;
  logic pclk;
  logic presetn;
  logic rtc_clk;
  logic rtc_rst_n;
  apb4_if apb4 (
      .pclk   (pclk),
      .presetn(presetn)
  );
  rtc_if rtc (
      .rtc_clk_i  (rtc_clk),
      .rtc_rst_n_i(rtc_rst_n)
  );

  always #5 pclk = ~pclk;
  always #7 rtc_clk = ~rtc_clk;

  apb4_rtc #(
      .RTC_CLOCK_HZ(32'd256)
  ) u_apb4_rtc (
      .apb4(apb4),
      .rtc (rtc)
  );

  task automatic apb_read(input logic [11:0] address, output logic [31:0] data, output logic error);
    @(negedge pclk);
    apb4.paddr   = {20'd0, address};
    apb4.pprot   = '0;
    apb4.psel    = 1'b1;
    apb4.penable = 1'b0;
    apb4.pwrite  = 1'b0;
    apb4.pwdata  = '0;
    apb4.pstrb   = '0;
    @(negedge pclk);
    apb4.penable = 1'b1;
    @(posedge pclk);
    if (!apb4.pready) begin
      $fatal(1, "RTC APB read inserted an unexpected wait state");
    end
    data  = apb4.prdata;
    error = apb4.pslverr;
    @(negedge pclk);
    apb4.psel    = 1'b0;
    apb4.penable = 1'b0;
  endtask

  task automatic apb_write(input logic [11:0] address, input logic [31:0] data,
                           input logic [3:0] strobe, output logic error);
    @(negedge pclk);
    apb4.paddr   = {20'd0, address};
    apb4.pprot   = '0;
    apb4.psel    = 1'b1;
    apb4.penable = 1'b0;
    apb4.pwrite  = 1'b1;
    apb4.pwdata  = data;
    apb4.pstrb   = strobe;
    @(negedge pclk);
    apb4.penable = 1'b1;
    @(posedge pclk);
    if (!apb4.pready) begin
      $fatal(1, "RTC APB write inserted an unexpected wait state");
    end
    error = apb4.pslverr;
    @(negedge pclk);
    apb4.psel    = 1'b0;
    apb4.penable = 1'b0;
    apb4.pwrite  = 1'b0;
    apb4.pstrb   = '0;
  endtask

  task automatic require_read(input logic [11:0] address, input logic [31:0] expected);
    logic [31:0] data;
    logic        error;
    apb_read(address, data, error);
    if (error || (data !== expected)) begin
      $fatal(1, "RTC read 0x%08x returned 0x%08x error=%0d", address, data, error);
    end
  endtask

  task automatic require_write(input logic [11:0] address, input logic [31:0] data,
                               input logic [3:0] strobe);
    logic error;
    apb_write(address, data, strobe, error);
    if (error) begin
      $fatal(1, "RTC write 0x%08x unexpectedly failed", address);
    end
  endtask

  task automatic execute_command(input logic [2:0] opcode);
    logic [31:0] status;
    logic        error;
    int          timeout;
    require_write(`RTC_COMMAND_STATUS_OFFSET,
                  `RTC_COMMAND_STATUS_DONE_MASK | `RTC_COMMAND_STATUS_ERROR_MASK, 4'b0001);
    apb_read(`RTC_STATUS_OFFSET, status, error);
    if (error || !status[`RTC_STATUS_LINK_READY_BIT]) begin
      $fatal(1, "RTC command link is not ready: status=0x%08x", status);
    end
    require_write(`RTC_COMMAND_OFFSET, {29'd0, opcode}, 4'b0001);
    status  = '0;
    timeout = 100;
    while (!status[1] && (timeout != 0)) begin
      apb_read(`RTC_COMMAND_STATUS_OFFSET, status, error);
      if (error) begin
        $fatal(1, "RTC command status read failed");
      end
      timeout--;
    end
    if ((timeout == 0) || status[2]) begin
      $fatal(1, "RTC command %0d failed with status 0x%08x", opcode, status);
    end
  endtask

  initial begin
    logic [31:0] data;
    logic        error;

    pclk         = 1'b0;
    presetn      = 1'b0;
    rtc_clk      = 1'b0;
    rtc_rst_n    = 1'b0;
    apb4.paddr   = '0;
    apb4.pprot   = '0;
    apb4.psel    = 1'b0;
    apb4.penable = 1'b0;
    apb4.pwrite  = 1'b0;
    apb4.pwdata  = '0;
    apb4.pstrb   = '0;

    repeat (4) @(posedge pclk);
    presetn = 1'b1;
    repeat (3) @(posedge rtc_clk);
    rtc_rst_n = 1'b1;
    repeat (10) @(posedge pclk);

    require_read(`RTC_IP_ID_OFFSET, `RTC_IP_ID_VALUE);
    require_read(`RTC_IP_VERSION_OFFSET, `RTC_IP_VERSION_VALUE);
    require_read(`RTC_CLOCK_HZ_OFFSET, 32'd256);

    apb_read(12'h070, data, error);
    if (!error) begin
      $fatal(1, "RTC unmapped read did not return PSLVERR");
    end
    apb_read(12'h0F5, data, error);
    if (!error) begin
      $fatal(1, "RTC misaligned read did not return PSLVERR");
    end
    apb_write(`RTC_CTRL_OFFSET, 32'h0000_0002, 4'b0001, error);
    if (!error) begin
      $fatal(1, "RTC reserved control write did not return PSLVERR");
    end
    require_read(`RTC_CTRL_OFFSET, 32'h0000_0000);

    require_write(`RTC_SECOND_CYCLES_OFFSET, 32'h0000_0100, 4'b1111);
    require_write(`RTC_SECOND_CYCLES_OFFSET, 32'h0000_0080, 4'b0001);
    require_read(`RTC_SECOND_CYCLES_OFFSET, 32'h0000_0180);
    require_write(`RTC_CTRL_OFFSET, `RTC_CTRL_ENABLE_MASK, 4'b0001);
    require_write(`RTC_CTRL_OFFSET, 32'h0000_0000, 4'b0010);
    require_read(`RTC_CTRL_OFFSET, `RTC_CTRL_ENABLE_MASK);
    require_write(`RTC_INTR_ENABLE_OFFSET, {27'd0, `RTC_EVENT_SECOND_MASK}, 4'b0001);
    require_write(`RTC_WAKE_ENABLE_OFFSET, {27'd0, `RTC_EVENT_SECOND_MASK}, 4'b0001);
    execute_command(`RTC_COMMAND_APPLY_CONFIG);

    require_write(`RTC_TIME_LOAD_LO_OFFSET, 32'd42, 4'b1111);
    require_write(`RTC_TIME_LOAD_HI_OFFSET, 32'd0, 4'b1111);
    require_write(`RTC_TIME_LOAD_SUBSEC_OFFSET, 32'd0, 4'b0001);
    execute_command(`RTC_COMMAND_SET_TIME);
    execute_command(`RTC_COMMAND_SNAPSHOT);
    require_read(`RTC_SNAPSHOT_TIME_LO_OFFSET, 32'd42);
    require_read(`RTC_SNAPSHOT_TIME_HI_OFFSET, 32'd0);

    require_write(`RTC_EVENT_TEST_OFFSET, {27'd0, `RTC_EVENT_SECOND_MASK}, 4'b0001);
    execute_command(`RTC_COMMAND_INJECT_EVENTS);
    repeat (6) @(posedge pclk);
    apb_read(`RTC_EVENT_RAW_OFFSET, data, error);
    if (error || (data !== 32'h0000_0001) || !rtc.irq_o || !rtc.wake_o) begin
      $fatal(1, "RTC injected event did not assert event, IRQ, and wake");
    end
    require_write(`RTC_EVENT_CLEAR_OFFSET, {27'd0, `RTC_EVENT_SECOND_MASK}, 4'b0001);
    execute_command(`RTC_COMMAND_CLEAR_EVENTS);
    repeat (6) @(posedge pclk);
    apb_read(`RTC_EVENT_RAW_OFFSET, data, error);
    if (error || (data !== 32'h0000_0000) || rtc.irq_o || rtc.wake_o) begin
      $fatal(1, "RTC event clear did not deassert event, IRQ, and wake");
    end

    $display("RTC_APB_ASYNC_TEST_PASS");
    $finish;
  end
endmodule
