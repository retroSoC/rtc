// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module rtc_formal;
  import rtc_pkg::*;

  (* gclk *)logic                                     clk;
  (* anyseq *)logic                                     rst_n;
  (* anyseq *)logic                                     command_valid;
  (* anyseq *)logic          [$bits(rtc_command_t)-1:0] command_bits;

  rtc_command_t                             command;
  rtc_response_t                            response;
  logic                                     command_ready;
  logic                                     response_valid;
  logic          [                     4:0] event_state;
  logic          [                     4:0] interrupt_enable;
  logic          [                     4:0] wake_enable;
  logic          [                     4:0] status;
  logic                                     wake;

  assign command = command_bits;

  rtc_core #(
      .RTC_CLOCK_HZ(32'd256)
  ) u_dut (
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

  initial begin
    assume (!rst_n);
  end

  always @(posedge clk) begin
    assert (command_ready);
    assert (response_valid == command_valid);
    assert (response.opcode == command.opcode);
    if (!rst_n) begin
      assert (event_state == 0);
      assert (interrupt_enable == 0);
      assert (wake_enable == 0);
      assert (status == 0);
      assert (!wake);
    end

    if (command_valid && (command.opcode == RTC_CMD_APPLY_CONFIG) &&
        (command.second_cycles < 32'd256)) begin
      assert (response.response == RTC_RSP_INVALID_CONFIG);
    end
    cover (rst_n && status[0] && status[1]);
    cover (rst_n && |event_state);
    cover (rst_n && wake);
  end

endmodule
