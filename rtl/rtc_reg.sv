// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "rtc_define.svh"

module rtc_reg #(
    parameter logic [31:0] RTC_CLOCK_HZ = 32'd32_768
) (
    // verilog_format: off
    input  logic                    pclk_i,
    input  logic                    presetn_i,
    input  logic [11:0]             paddr_i,
    input  logic                    psel_i,
    input  logic                    penable_i,
    input  logic                    pwrite_i,
    input  logic [31:0]             pwdata_i,
    input  logic [3:0]              pstrb_i,
    output logic                    pready_o,
    output logic [31:0]             prdata_o,
    output logic                    pslverr_o,
    output logic                    command_valid_o,
    input  logic                    command_ready_i,
    output rtc_pkg::rtc_command_t   command_o,
    input  logic                    response_valid_i,
    output logic                    response_ready_o,
    input  rtc_pkg::rtc_response_t  response_i,
    input  logic [4:0]              event_i,
    input  logic [4:0]              interrupt_enable_i,
    input  logic [4:0]              wake_enable_i,
    input  logic [4:0]              rtc_status_i,
    output logic                    irq_o
    // verilog_format: on
);

  import rtc_pkg::*;

  localparam int COMMAND_WIDTH = $bits(rtc_command_t);
  localparam logic [COMMAND_WIDTH-1:0] STAGING_RESET = {
    RTC_CMD_NONE,
    1'b0,
    RTC_CLOCK_HZ,
    16'd0,
    64'd0,
    8'd0,
    64'd0,
    8'd0,
    64'd0,
    8'd0,
    2'd0,
    32'd0,
    2'd0,
    5'd0,
    5'd0,
    5'd0
  };

  logic s_transfer;
  logic s_read;
  logic s_write;
  logic s_read_mapped;
  logic s_write_mapped;
  logic s_write_value_valid;
  logic s_staging_write;
  logic s_command_accept;
  logic s_command_busy_d, s_command_busy_q;
  logic s_command_done_d, s_command_done_q;
  logic s_command_error_d, s_command_error_q;
  logic [2:0] s_last_opcode_d, s_last_opcode_q;
  logic [2:0] s_last_response_d, s_last_response_q;
  logic s_snapshot_valid_d, s_snapshot_valid_q;
  logic [63:0] s_snapshot_seconds_d, s_snapshot_seconds_q;
  logic [7:0] s_snapshot_subsecond_d, s_snapshot_subsecond_q;
  logic [4:0] s_event_clear_d, s_event_clear_q;
  logic [4:0] s_event_test_d, s_event_test_q;
  rtc_command_t s_staging_d, s_staging_q;

  function automatic logic [31:0] merge_bytes(input logic [31:0] current, input logic [31:0] value,
                                              input logic [3:0] strobe);
    logic [31:0] merged;
    merged = current;
    for (int byte_index = 0; byte_index < 4; byte_index++) begin
      if (strobe[byte_index]) begin
        merged[byte_index*8+:8] = value[byte_index*8+:8];
      end
    end
    return merged;
  endfunction

  function automatic logic merge_bit(input logic current, input logic value, input logic strobe);
    return strobe ? value : current;
  endfunction

  function automatic logic [1:0] merge_2bits(input logic [1:0] current, input logic [1:0] value,
                                             input logic strobe);
    return strobe ? value : current;
  endfunction

  function automatic logic [4:0] merge_5bits(input logic [4:0] current, input logic [4:0] value,
                                             input logic strobe);
    return strobe ? value : current;
  endfunction

  function automatic logic [7:0] merge_8bits(input logic [7:0] current, input logic [7:0] value,
                                             input logic strobe);
    return strobe ? value : current;
  endfunction

  function automatic logic [15:0] merge_16bits(input logic [15:0] current, input logic [15:0] value,
                                               input logic [1:0] strobe);
    logic [15:0] merged;
    merged = current;
    if (strobe[0]) begin
      merged[7:0] = value[7:0];
    end
    if (strobe[1]) begin
      merged[15:8] = value[15:8];
    end
    return merged;
  endfunction

  assign s_transfer = psel_i && penable_i;
  assign s_read     = s_transfer && !pwrite_i;
  assign s_write    = s_transfer && pwrite_i;
  assign pready_o   = 1'b1;

  always_comb begin
    s_read_mapped = 1'b1;
    unique case (paddr_i)
      `RTC_CTRL_OFFSET,
      `RTC_STATUS_OFFSET,
      `RTC_COMMAND_STATUS_OFFSET,
      `RTC_TIME_LOAD_LO_OFFSET,
      `RTC_TIME_LOAD_HI_OFFSET,
      `RTC_TIME_LOAD_SUBSEC_OFFSET,
      `RTC_SNAPSHOT_TIME_LO_OFFSET,
      `RTC_SNAPSHOT_TIME_HI_OFFSET,
      `RTC_SNAPSHOT_SUBSEC_OFFSET,
      `RTC_SECOND_CYCLES_OFFSET,
      `RTC_CALIB_PPM_OFFSET,
      `RTC_ALARM0_TIME_LO_OFFSET,
      `RTC_ALARM0_TIME_HI_OFFSET,
      `RTC_ALARM0_SUBSEC_OFFSET,
      `RTC_ALARM1_TIME_LO_OFFSET,
      `RTC_ALARM1_TIME_HI_OFFSET,
      `RTC_ALARM1_SUBSEC_OFFSET,
      `RTC_ALARM_ENABLE_OFFSET,
      `RTC_PERIOD_RELOAD_OFFSET,
      `RTC_PERIOD_CTRL_OFFSET,
      `RTC_EVENT_RAW_OFFSET,
      `RTC_INTR_ENABLE_OFFSET,
      `RTC_INTR_STATE_OFFSET,
      `RTC_WAKE_ENABLE_OFFSET,
      `RTC_WAKE_STATE_OFFSET,
      `RTC_CLOCK_HZ_OFFSET,
      `RTC_IP_ID_OFFSET,
      `RTC_IP_VERSION_OFFSET,
      `RTC_CAPABILITY_OFFSET: begin
      end
      default: s_read_mapped = 1'b0;
    endcase
  end

  always_comb begin
    s_write_mapped      = 1'b1;
    s_staging_write     = 1'b1;
    s_write_value_valid = |pstrb_i;
    unique case (paddr_i)
      `RTC_CTRL_OFFSET: begin
        s_write_value_valid = s_write_value_valid && ((pwdata_i & ~`RTC_CTRL_VALID_MASK) == 0);
      end
      `RTC_TIME_LOAD_LO_OFFSET,
      `RTC_TIME_LOAD_HI_OFFSET,
      `RTC_SECOND_CYCLES_OFFSET,
      `RTC_CALIB_PPM_OFFSET,
      `RTC_ALARM0_TIME_LO_OFFSET,
      `RTC_ALARM0_TIME_HI_OFFSET,
      `RTC_ALARM1_TIME_LO_OFFSET,
      `RTC_ALARM1_TIME_HI_OFFSET,
      `RTC_PERIOD_RELOAD_OFFSET: begin
      end
      `RTC_TIME_LOAD_SUBSEC_OFFSET, `RTC_ALARM0_SUBSEC_OFFSET, `RTC_ALARM1_SUBSEC_OFFSET: begin
        s_write_value_valid = s_write_value_valid && ((pwdata_i & 32'hFFFF_FF00) == 0);
      end
      `RTC_ALARM_ENABLE_OFFSET: begin
        s_write_value_valid = s_write_value_valid && ((pwdata_i & 32'hFFFF_FFFC) == 0);
      end
      `RTC_PERIOD_CTRL_OFFSET: begin
        s_write_value_valid = s_write_value_valid &&
            ((pwdata_i & ~`RTC_PERIOD_CTRL_VALID_MASK) == 0);
      end
      `RTC_EVENT_CLEAR_OFFSET,
      `RTC_EVENT_TEST_OFFSET,
      `RTC_INTR_ENABLE_OFFSET,
      `RTC_WAKE_ENABLE_OFFSET: begin
        s_write_value_valid = s_write_value_valid && ((pwdata_i & 32'hFFFF_FFE0) == 0);
      end
      `RTC_COMMAND_OFFSET: begin
        s_staging_write = 1'b0;
        s_write_value_valid = pstrb_i[0] && ((pwdata_i & ~`RTC_COMMAND_VALID_MASK) == 0) &&
            (pwdata_i[2:0] >= `RTC_COMMAND_APPLY_CONFIG) &&
            (pwdata_i[2:0] <= `RTC_COMMAND_INJECT_EVENTS) &&
            command_ready_i && !s_command_busy_q;
      end
      `RTC_COMMAND_STATUS_OFFSET: begin
        s_staging_write = 1'b0;
        s_write_value_valid = pstrb_i[0] &&
            ((pwdata_i & ~(`RTC_COMMAND_STATUS_DONE_MASK |
                           `RTC_COMMAND_STATUS_ERROR_MASK)) == 0);
      end
      default: begin
        s_write_mapped  = 1'b0;
        s_staging_write = 1'b0;
      end
    endcase
    if (s_staging_write && s_command_busy_q) begin
      s_write_value_valid = 1'b0;
    end
  end

  assign pslverr_o = s_transfer && ((paddr_i[1:0] != 2'b00) ||
      (pwrite_i ? (!s_write_mapped || !s_write_value_valid) : !s_read_mapped));
  assign s_command_accept = s_write && (paddr_i == `RTC_COMMAND_OFFSET) &&
      s_write_mapped && s_write_value_valid && (paddr_i[1:0] == 2'b00);
  assign command_valid_o = s_command_accept;
  assign response_ready_o = 1'b1;

  always_comb begin
    command_o = s_staging_q;
    command_o.opcode = rtc_command_e'(pwdata_i[2:0]);
    command_o.event_mask = (pwdata_i[2:0] == `RTC_COMMAND_CLEAR_EVENTS) ?
        s_event_clear_q : s_event_test_q;
  end

  always_comb begin
    s_staging_d     = s_staging_q;
    s_event_clear_d = s_event_clear_q;
    s_event_test_d  = s_event_test_q;
    if (s_write && s_write_mapped && s_write_value_valid && !s_command_busy_q) begin
      unique case (paddr_i)
        `RTC_CTRL_OFFSET: begin
          s_staging_d.enable = merge_bit(s_staging_q.enable, pwdata_i[0], pstrb_i[0]);
        end
        `RTC_TIME_LOAD_LO_OFFSET: begin
          s_staging_d.load_seconds[31:0] =
              merge_bytes(s_staging_q.load_seconds[31:0], pwdata_i, pstrb_i);
        end
        `RTC_TIME_LOAD_HI_OFFSET: begin
          s_staging_d.load_seconds[63:32] =
              merge_bytes(s_staging_q.load_seconds[63:32], pwdata_i, pstrb_i);
        end
        `RTC_TIME_LOAD_SUBSEC_OFFSET: begin
          s_staging_d.load_subsecond =
              merge_8bits(s_staging_q.load_subsecond, pwdata_i[7:0], pstrb_i[0]);
        end
        `RTC_SECOND_CYCLES_OFFSET: begin
          s_staging_d.second_cycles = merge_bytes(s_staging_q.second_cycles, pwdata_i, pstrb_i);
        end
        `RTC_CALIB_PPM_OFFSET: begin
          s_staging_d.calibration_ppm =
              merge_16bits(s_staging_q.calibration_ppm, pwdata_i[15:0], pstrb_i[1:0]);
        end
        `RTC_ALARM0_TIME_LO_OFFSET: begin
          s_staging_d.alarm0_seconds[31:0] =
              merge_bytes(s_staging_q.alarm0_seconds[31:0], pwdata_i, pstrb_i);
        end
        `RTC_ALARM0_TIME_HI_OFFSET: begin
          s_staging_d.alarm0_seconds[63:32] =
              merge_bytes(s_staging_q.alarm0_seconds[63:32], pwdata_i, pstrb_i);
        end
        `RTC_ALARM0_SUBSEC_OFFSET: begin
          s_staging_d.alarm0_subsecond =
              merge_8bits(s_staging_q.alarm0_subsecond, pwdata_i[7:0], pstrb_i[0]);
        end
        `RTC_ALARM1_TIME_LO_OFFSET: begin
          s_staging_d.alarm1_seconds[31:0] =
              merge_bytes(s_staging_q.alarm1_seconds[31:0], pwdata_i, pstrb_i);
        end
        `RTC_ALARM1_TIME_HI_OFFSET: begin
          s_staging_d.alarm1_seconds[63:32] =
              merge_bytes(s_staging_q.alarm1_seconds[63:32], pwdata_i, pstrb_i);
        end
        `RTC_ALARM1_SUBSEC_OFFSET: begin
          s_staging_d.alarm1_subsecond =
              merge_8bits(s_staging_q.alarm1_subsecond, pwdata_i[7:0], pstrb_i[0]);
        end
        `RTC_ALARM_ENABLE_OFFSET: begin
          s_staging_d.alarm_enable =
              merge_2bits(s_staging_q.alarm_enable, pwdata_i[1:0], pstrb_i[0]);
        end
        `RTC_PERIOD_RELOAD_OFFSET: begin
          s_staging_d.period_reload = merge_bytes(s_staging_q.period_reload, pwdata_i, pstrb_i);
        end
        `RTC_PERIOD_CTRL_OFFSET: begin
          s_staging_d.period_control =
              merge_2bits(s_staging_q.period_control, pwdata_i[1:0], pstrb_i[0]);
        end
        `RTC_EVENT_CLEAR_OFFSET: begin
          s_event_clear_d = merge_5bits(s_event_clear_q, pwdata_i[4:0], pstrb_i[0]);
        end
        `RTC_EVENT_TEST_OFFSET: begin
          s_event_test_d = merge_5bits(s_event_test_q, pwdata_i[4:0], pstrb_i[0]);
        end
        `RTC_INTR_ENABLE_OFFSET: begin
          s_staging_d.interrupt_enable =
              merge_5bits(s_staging_q.interrupt_enable, pwdata_i[4:0], pstrb_i[0]);
        end
        `RTC_WAKE_ENABLE_OFFSET: begin
          s_staging_d.wake_enable = merge_5bits(s_staging_q.wake_enable, pwdata_i[4:0], pstrb_i[0]);
        end
        default: begin
        end
      endcase
    end
  end

  always_comb begin
    s_command_busy_d       = s_command_busy_q;
    s_command_done_d       = s_command_done_q;
    s_command_error_d      = s_command_error_q;
    s_last_opcode_d        = s_last_opcode_q;
    s_last_response_d      = s_last_response_q;
    s_snapshot_valid_d     = s_snapshot_valid_q;
    s_snapshot_seconds_d   = s_snapshot_seconds_q;
    s_snapshot_subsecond_d = s_snapshot_subsecond_q;

    if (s_write && (paddr_i == `RTC_COMMAND_STATUS_OFFSET) && s_write_value_valid) begin
      if (pwdata_i[1]) begin
        s_command_done_d = 1'b0;
      end
      if (pwdata_i[2]) begin
        s_command_error_d = 1'b0;
      end
    end
    if (s_command_accept) begin
      s_command_busy_d  = 1'b1;
      s_command_done_d  = 1'b0;
      s_command_error_d = 1'b0;
      if (pwdata_i[2:0] == `RTC_COMMAND_SET_TIME) begin
        s_snapshot_valid_d = 1'b0;
      end
    end
    if (response_valid_i) begin
      s_command_busy_d  = 1'b0;
      s_command_done_d  = 1'b1;
      s_command_error_d = response_i.response != RTC_RSP_OK;
      s_last_opcode_d   = response_i.opcode;
      s_last_response_d = response_i.response;
      if ((response_i.opcode == RTC_CMD_SNAPSHOT) && (response_i.response == RTC_RSP_OK)) begin
        s_snapshot_valid_d     = 1'b1;
        s_snapshot_seconds_d   = response_i.snapshot_seconds;
        s_snapshot_subsecond_d = response_i.snapshot_subsecond;
      end
    end
  end

  dffrc #(
      .DATA_WIDTH(COMMAND_WIDTH),
      .RESET_VAL (STAGING_RESET)
  ) u_staging_dffrc (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_staging_d),
      .dat_o  (s_staging_q)
  );

  dffr #(
      .DATA_WIDTH(5)
  ) u_event_clear_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_event_clear_d),
      .dat_o  (s_event_clear_q)
  );
  dffr #(
      .DATA_WIDTH(5)
  ) u_event_test_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_event_test_d),
      .dat_o  (s_event_test_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_command_busy_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_command_busy_d),
      .dat_o  (s_command_busy_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_command_done_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_command_done_d),
      .dat_o  (s_command_done_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_command_error_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_command_error_d),
      .dat_o  (s_command_error_q)
  );
  dffr #(
      .DATA_WIDTH(3)
  ) u_last_opcode_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_last_opcode_d),
      .dat_o  (s_last_opcode_q)
  );
  dffr #(
      .DATA_WIDTH(3)
  ) u_last_response_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_last_response_d),
      .dat_o  (s_last_response_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_snapshot_valid_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_snapshot_valid_d),
      .dat_o  (s_snapshot_valid_q)
  );
  dffr #(
      .DATA_WIDTH(64)
  ) u_snapshot_seconds_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_snapshot_seconds_d),
      .dat_o  (s_snapshot_seconds_q)
  );
  dffr #(
      .DATA_WIDTH(8)
  ) u_snapshot_subsecond_dffr (
      .clk_i  (pclk_i),
      .rst_n_i(presetn_i),
      .dat_i  (s_snapshot_subsecond_d),
      .dat_o  (s_snapshot_subsecond_q)
  );

  always_comb begin
    prdata_o = '0;
    if (s_read && s_read_mapped && (paddr_i[1:0] == 2'b00)) begin
      unique case (paddr_i)
        `RTC_CTRL_OFFSET: prdata_o = {31'd0, s_staging_q.enable};
        `RTC_STATUS_OFFSET: begin
          prdata_o = {
            21'd0,
            rtc_status_i[4:2],
            1'b0,
            command_ready_i,
            s_snapshot_valid_q,
            s_command_error_q,
            s_command_done_q,
            s_command_busy_q,
            rtc_status_i[1],
            rtc_status_i[0]
          };
        end
        `RTC_COMMAND_STATUS_OFFSET: begin
          prdata_o = {
            16'd0,
            5'd0,
            s_last_response_q,
            1'b0,
            s_last_opcode_q,
            1'b0,
            s_command_error_q,
            s_command_done_q,
            s_command_busy_q
          };
        end
        `RTC_TIME_LOAD_LO_OFFSET: prdata_o = s_staging_q.load_seconds[31:0];
        `RTC_TIME_LOAD_HI_OFFSET: prdata_o = s_staging_q.load_seconds[63:32];
        `RTC_TIME_LOAD_SUBSEC_OFFSET: prdata_o = {24'd0, s_staging_q.load_subsecond};
        `RTC_SNAPSHOT_TIME_LO_OFFSET: prdata_o = s_snapshot_seconds_q[31:0];
        `RTC_SNAPSHOT_TIME_HI_OFFSET: prdata_o = s_snapshot_seconds_q[63:32];
        `RTC_SNAPSHOT_SUBSEC_OFFSET: prdata_o = {24'd0, s_snapshot_subsecond_q};
        `RTC_SECOND_CYCLES_OFFSET: prdata_o = s_staging_q.second_cycles;
        `RTC_CALIB_PPM_OFFSET:
        prdata_o = {{16{s_staging_q.calibration_ppm[15]}}, s_staging_q.calibration_ppm};
        `RTC_ALARM0_TIME_LO_OFFSET: prdata_o = s_staging_q.alarm0_seconds[31:0];
        `RTC_ALARM0_TIME_HI_OFFSET: prdata_o = s_staging_q.alarm0_seconds[63:32];
        `RTC_ALARM0_SUBSEC_OFFSET: prdata_o = {24'd0, s_staging_q.alarm0_subsecond};
        `RTC_ALARM1_TIME_LO_OFFSET: prdata_o = s_staging_q.alarm1_seconds[31:0];
        `RTC_ALARM1_TIME_HI_OFFSET: prdata_o = s_staging_q.alarm1_seconds[63:32];
        `RTC_ALARM1_SUBSEC_OFFSET: prdata_o = {24'd0, s_staging_q.alarm1_subsecond};
        `RTC_ALARM_ENABLE_OFFSET: prdata_o = {30'd0, s_staging_q.alarm_enable};
        `RTC_PERIOD_RELOAD_OFFSET: prdata_o = s_staging_q.period_reload;
        `RTC_PERIOD_CTRL_OFFSET: prdata_o = {30'd0, s_staging_q.period_control};
        `RTC_EVENT_RAW_OFFSET: prdata_o = {27'd0, event_i};
        `RTC_INTR_ENABLE_OFFSET: prdata_o = {27'd0, s_staging_q.interrupt_enable};
        `RTC_INTR_STATE_OFFSET: prdata_o = {27'd0, event_i & interrupt_enable_i};
        `RTC_WAKE_ENABLE_OFFSET: prdata_o = {27'd0, s_staging_q.wake_enable};
        `RTC_WAKE_STATE_OFFSET: prdata_o = {27'd0, event_i & wake_enable_i};
        `RTC_CLOCK_HZ_OFFSET: prdata_o = RTC_CLOCK_HZ;
        `RTC_IP_ID_OFFSET: prdata_o = `RTC_IP_ID_VALUE;
        `RTC_IP_VERSION_OFFSET: prdata_o = `RTC_IP_VERSION_VALUE;
        `RTC_CAPABILITY_OFFSET: begin
          prdata_o = {`RTC_ABI_VERSION, 8'd2, 8'd8, `RTC_CAPABILITY_FEATURES};
        end
        default: prdata_o = '0;
      endcase
    end
  end

  assign irq_o = |(event_i & interrupt_enable_i);

endmodule
