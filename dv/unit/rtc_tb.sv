// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps

module rtc_tb;
  import rtc_pkg::*;

  logic                clk;
  logic                rst_n;
  logic                command_valid;
  logic                command_ready;
  rtc_command_t        command;
  logic                response_valid;
  rtc_response_t       response;
  logic          [4:0] event_state;
  logic          [4:0] interrupt_enable;
  logic          [4:0] wake_enable;
  logic          [4:0] status;
  logic                wake;

  always #5 clk = ~clk;

  rtc_core #(
      .RTC_CLOCK_HZ(32'd256)
  ) u_rtc_core (
      .clk_i             (clk),
      .rst_n_i           (rst_n),
      .command_valid_i   (command_valid),
      .command_ready_o   (command_ready),
      .command_i         (command),
      .response_valid_o  (response_valid),
      .response_ready_i  (1'b1),
      .response_o        (response),
      .event_o           (event_state),
      .interrupt_enable_o(interrupt_enable),
      .wake_enable_o     (wake_enable),
      .status_o          (status),
      .wake_o            (wake)
  );

  task automatic issue_command(input rtc_command_t request, output rtc_response_t result);
    @(negedge clk);
    command       = request;
    command_valid = 1'b1;
    @(posedge clk);
    #1;
    if (!command_ready || !response_valid) begin
      $fatal(1, "RTC command handshake failed");
    end
    result = response;
    if (result.opcode != request.opcode) begin
      $fatal(1, "RTC response opcode does not match the request");
    end
    @(negedge clk);
    command_valid = 1'b0;
    command       = '0;
  endtask

  task automatic require_ok(input rtc_response_e response_code);
    if (response_code != RTC_RSP_OK) begin
      $fatal(1, "RTC command failed with response %0d", response_code);
    end
  endtask

  initial begin
    rtc_command_t  request;
    rtc_response_t result;
    int            timeout;

    clk           = 1'b0;
    rst_n         = 1'b0;
    command_valid = 1'b0;
    command       = '0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    request                  = '0;
    request.opcode           = RTC_CMD_APPLY_CONFIG;
    request.enable           = 1'b1;
    request.second_cycles    = 32'd256;
    request.interrupt_enable = 5'b11111;
    request.wake_enable      = 5'b11111;
    issue_command(request, result);
    if ((^result) === 1'bx) begin
      $fatal(1, "RTC response contains an unknown value");
    end
    require_ok(result.response);
    $display("RTC configure complete at %0t", $time);
    if ((interrupt_enable != 5'b11111) || (wake_enable != 5'b11111) || !status[0]) begin
      $fatal(1, "RTC active configuration is incorrect");
    end

    request                = '0;
    request.opcode         = RTC_CMD_SET_TIME;
    request.load_seconds   = 64'd100;
    request.load_subsecond = 8'd0;
    issue_command(request, result);
    require_ok(result.response);
    $display("RTC set time complete at %0t", $time);
    if (!status[1]) begin
      $fatal(1, "RTC time did not become valid");
    end

    request        = '0;
    request.opcode = RTC_CMD_SNAPSHOT;
    issue_command(request, result);
    require_ok(result.response);
    $display("RTC snapshot complete at %0t", $time);
    if ((result.snapshot_seconds != 64'd100) || (result.snapshot_subsecond > 8'd8)) begin
      $fatal(1, "RTC snapshot is not coherent");
    end

    request                = '0;
    request.opcode         = RTC_CMD_SET_TIME;
    request.load_seconds   = 64'd200;
    request.load_subsecond = 8'd254;
    issue_command(request, result);
    require_ok(result.response);
    repeat (2) @(posedge clk);
    request        = '0;
    request.opcode = RTC_CMD_SNAPSHOT;
    issue_command(request, result);
    require_ok(result.response);
    if ((result.snapshot_seconds != 64'd201) || (result.snapshot_subsecond > 8'd2)) begin
      $fatal(1, "RTC snapshot is not coherent across second rollover");
    end

    request                  = '0;
    request.opcode           = RTC_CMD_APPLY_CONFIG;
    request.enable           = 1'b1;
    request.second_cycles    = 32'd256;
    request.alarm0_seconds   = 64'd202;
    request.alarm_enable     = 2'b01;
    request.interrupt_enable = 5'b11111;
    request.wake_enable      = 5'b11111;
    issue_command(request, result);
    require_ok(result.response);
    $display("RTC alarm configured at %0t", $time);

    timeout = 400;
    while (!event_state[1] && (timeout != 0)) begin
      @(posedge clk);
      timeout--;
    end
    if ((timeout == 0) || !wake || status[3] || status[2]) begin
      $fatal(1, "RTC alarm did not fire once");
    end

    request            = '0;
    request.opcode     = RTC_CMD_CLEAR_EVENTS;
    request.event_mask = 5'b11111;
    issue_command(request, result);
    require_ok(result.response);
    repeat (3) @(posedge clk);
    if (event_state != 0) begin
      $fatal(1, "RTC event clear failed");
    end

    request                  = '0;
    request.opcode           = RTC_CMD_APPLY_CONFIG;
    request.enable           = 1'b1;
    request.second_cycles    = 32'd256;
    request.period_reload    = 32'd3;
    request.period_control   = 2'b11;
    request.interrupt_enable = 5'b11111;
    request.wake_enable      = 5'b11111;
    issue_command(request, result);
    require_ok(result.response);
    repeat (8) @(posedge clk);
    if (!event_state[3] || !status[4]) begin
      $fatal(1, "RTC periodic wake did not reload");
    end

    request               = '0;
    request.opcode        = RTC_CMD_APPLY_CONFIG;
    request.enable        = 1'b1;
    request.second_cycles = 32'd255;
    issue_command(request, result);
    if (result.response != RTC_RSP_INVALID_CONFIG) begin
      $fatal(1, "RTC accepted an invalid second period");
    end

    request               = '0;
    request.opcode        = RTC_CMD_APPLY_CONFIG;
    request.enable        = 1'b1;
    request.second_cycles = 32'd512;
    issue_command(request, result);
    if (result.response != RTC_RSP_ILLEGAL_STATE) begin
      $fatal(1, "RTC changed the second period while running");
    end

    request               = '0;
    request.opcode        = RTC_CMD_APPLY_CONFIG;
    request.enable        = 1'b0;
    request.second_cycles = 32'd512;
    issue_command(request, result);
    require_ok(result.response);

    $display("RTC_TEST_PASS");
    $finish;
  end

endmodule
