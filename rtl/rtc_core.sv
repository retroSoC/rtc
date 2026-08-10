// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "rtc_define.svh"

module rtc_core #(
    parameter logic [31:0] RTC_CLOCK_HZ = 32'd32_768
) (
    // verilog_format: off
    input  logic                    clk_i,
    input  logic                    rst_n_i,
    input  logic                    command_valid_i,
    output logic                    command_ready_o,
    input  rtc_pkg::rtc_command_t   command_i,
    output logic                    response_valid_o,
    input  logic                    response_ready_i,
    output rtc_pkg::rtc_response_t  response_o,
    output logic [4:0]              event_o,
    output logic [4:0]              interrupt_enable_o,
    output logic [4:0]              wake_enable_o,
    output logic [4:0]              status_o,
    output logic                    wake_o
    // verilog_format: on
);

  import rtc_pkg::*;

  logic       s_command_fire;
  logic       s_apply_valid;
  logic       s_apply_illegal_state;
  logic       s_tick_reconfigure;
  logic       s_tick_load;
  logic       s_subsecond_tick;
  logic       s_second_tick;
  logic [7:0] s_subsecond;

  logic s_enable_d, s_enable_q;
  logic s_time_valid_d, s_time_valid_q;
  logic [31:0] s_second_cycles_d, s_second_cycles_q;
  logic signed [15:0] s_calibration_ppm_d, s_calibration_ppm_q;
  logic [63:0] s_seconds_d, s_seconds_q;
  logic [63:0] s_alarm0_seconds_d, s_alarm0_seconds_q;
  logic [7:0] s_alarm0_subsecond_d, s_alarm0_subsecond_q;
  logic [63:0] s_alarm1_seconds_d, s_alarm1_seconds_q;
  logic [7:0] s_alarm1_subsecond_d, s_alarm1_subsecond_q;
  logic [1:0] s_alarm_config_enable_d, s_alarm_config_enable_q;
  logic [1:0] s_alarm_active_d, s_alarm_active_q;
  logic [31:0] s_period_reload_d, s_period_reload_q;
  logic [31:0] s_period_count_d, s_period_count_q;
  logic [1:0] s_period_control_d, s_period_control_q;
  logic s_period_active_d, s_period_active_q;
  logic [4:0] s_event_d, s_event_q;
  logic [4:0] s_interrupt_enable_d, s_interrupt_enable_q;
  logic [4:0] s_wake_enable_d, s_wake_enable_q;
  logic [ 4:0] s_event_set;
  logic [ 4:0] s_event_clear;
  logic [63:0] s_visible_seconds;

  function automatic logic time_reached(input logic [63:0] seconds, input logic [7:0] subsecond,
                                        input logic [63:0] target_seconds,
                                        input logic [7:0] target_subsecond);
    return (seconds > target_seconds) ||
        ((seconds == target_seconds) && (subsecond >= target_subsecond));
  endfunction

  assign command_ready_o = response_ready_i;
  assign response_valid_o = command_valid_i;
  assign s_command_fire = command_valid_i && command_ready_o;

  assign s_apply_valid = (command_i.second_cycles >= `RTC_SECOND_CYCLES_MIN) &&
      (command_i.calibration_ppm >= `RTC_CALIB_PPM_MIN) &&
      (command_i.calibration_ppm <= `RTC_CALIB_PPM_MAX) &&
      (!command_i.period_control[0] || (command_i.period_reload != 0));
  assign s_apply_illegal_state = s_enable_q && command_i.enable &&
      (command_i.second_cycles != s_second_cycles_q);
  assign s_visible_seconds = (s_enable_q && s_second_tick) ?
      ((&s_seconds_q) ? 64'd0 : (s_seconds_q + 64'd1)) : s_seconds_q;

  always_comb begin
    response_o                    = '0;
    response_o.opcode             = command_i.opcode;
    response_o.response           = RTC_RSP_OK;
    response_o.snapshot_seconds   = s_visible_seconds;
    response_o.snapshot_subsecond = s_subsecond;
    if (command_i.opcode == RTC_CMD_APPLY_CONFIG) begin
      if (!s_apply_valid) begin
        response_o.response = RTC_RSP_INVALID_CONFIG;
      end else if (s_apply_illegal_state) begin
        response_o.response = RTC_RSP_ILLEGAL_STATE;
      end
    end else if ((command_i.opcode == RTC_CMD_NONE) ||
                 (command_i.opcode > RTC_CMD_INJECT_EVENTS)) begin
      response_o.response = RTC_RSP_INVALID_CONFIG;
    end
  end

  always_comb begin
    s_enable_d              = s_enable_q;
    s_time_valid_d          = s_time_valid_q;
    s_second_cycles_d       = s_second_cycles_q;
    s_calibration_ppm_d     = s_calibration_ppm_q;
    s_seconds_d             = s_seconds_q;
    s_alarm0_seconds_d      = s_alarm0_seconds_q;
    s_alarm0_subsecond_d    = s_alarm0_subsecond_q;
    s_alarm1_seconds_d      = s_alarm1_seconds_q;
    s_alarm1_subsecond_d    = s_alarm1_subsecond_q;
    s_alarm_config_enable_d = s_alarm_config_enable_q;
    s_alarm_active_d        = s_alarm_active_q;
    s_period_reload_d       = s_period_reload_q;
    s_period_count_d        = s_period_count_q;
    s_period_control_d      = s_period_control_q;
    s_period_active_d       = s_period_active_q;
    s_interrupt_enable_d    = s_interrupt_enable_q;
    s_wake_enable_d         = s_wake_enable_q;
    s_event_set             = '0;
    s_event_clear           = '0;
    s_tick_reconfigure      = 1'b0;
    s_tick_load             = 1'b0;

    if (s_enable_q && s_second_tick) begin
      s_event_set[0] = 1'b1;
      s_seconds_d    = s_visible_seconds;
      if (&s_seconds_q) begin
        s_event_set[4] = 1'b1;
      end
    end

    if (s_enable_q && s_alarm_active_q[0] && time_reached(
            s_visible_seconds, s_subsecond, s_alarm0_seconds_q, s_alarm0_subsecond_q
        )) begin
      s_event_set[1]      = 1'b1;
      s_alarm_active_d[0] = 1'b0;
    end
    if (s_enable_q && s_alarm_active_q[1] && time_reached(
            s_visible_seconds, s_subsecond, s_alarm1_seconds_q, s_alarm1_subsecond_q
        )) begin
      s_event_set[2]      = 1'b1;
      s_alarm_active_d[1] = 1'b0;
    end

    if (s_enable_q && s_period_active_q && s_subsecond_tick) begin
      if (s_period_count_q <= 32'd1) begin
        s_event_set[3] = 1'b1;
        if (s_period_control_q[1]) begin
          s_period_count_d = s_period_reload_q;
        end else begin
          s_period_count_d  = '0;
          s_period_active_d = 1'b0;
        end
      end else begin
        s_period_count_d = s_period_count_q - 32'd1;
      end
    end

    if (s_command_fire) begin
      unique case (command_i.opcode)
        RTC_CMD_APPLY_CONFIG: begin
          if (response_o.response == RTC_RSP_OK) begin
            s_enable_d          = command_i.enable;
            s_second_cycles_d   = command_i.second_cycles;
            s_calibration_ppm_d = command_i.calibration_ppm;
            if ((command_i.alarm_enable[0] != s_alarm_config_enable_q[0]) ||
                (command_i.alarm0_seconds != s_alarm0_seconds_q) ||
                (command_i.alarm0_subsecond != s_alarm0_subsecond_q)) begin
              s_alarm_active_d[0] = command_i.alarm_enable[0];
            end
            if ((command_i.alarm_enable[1] != s_alarm_config_enable_q[1]) ||
                (command_i.alarm1_seconds != s_alarm1_seconds_q) ||
                (command_i.alarm1_subsecond != s_alarm1_subsecond_q)) begin
              s_alarm_active_d[1] = command_i.alarm_enable[1];
            end
            s_alarm0_seconds_d      = command_i.alarm0_seconds;
            s_alarm0_subsecond_d    = command_i.alarm0_subsecond;
            s_alarm1_seconds_d      = command_i.alarm1_seconds;
            s_alarm1_subsecond_d    = command_i.alarm1_subsecond;
            s_alarm_config_enable_d = command_i.alarm_enable;
            s_period_reload_d       = command_i.period_reload;
            if ((command_i.period_reload != s_period_reload_q) ||
                (command_i.period_control != s_period_control_q)) begin
              s_period_count_d  = command_i.period_reload;
              s_period_active_d = command_i.period_control[0];
            end
            s_period_control_d = command_i.period_control;
            s_interrupt_enable_d = command_i.interrupt_enable;
            s_wake_enable_d = command_i.wake_enable;
            s_tick_reconfigure   =
                (command_i.second_cycles != s_second_cycles_q) ||
                (command_i.calibration_ppm != s_calibration_ppm_q);
          end
        end
        RTC_CMD_SET_TIME: begin
          s_seconds_d    = command_i.load_seconds;
          s_time_valid_d = 1'b1;
          s_tick_load    = 1'b1;
        end
        RTC_CMD_CLEAR_EVENTS: begin
          s_event_clear = command_i.event_mask;
        end
        RTC_CMD_INJECT_EVENTS: begin
          s_event_set = s_event_set | command_i.event_mask;
        end
        default: begin
        end
      endcase
    end

    s_event_d = (s_event_q & ~s_event_clear) | s_event_set;
  end

  rtc_tickgen u_rtc_tickgen (
      .clk_i            (clk_i),
      .rst_n_i          (rst_n_i),
      .enable_i         (s_enable_q),
      .second_cycles_i  (s_second_cycles_q),
      .calibration_ppm_i(s_calibration_ppm_q),
      .reconfigure_i    (s_tick_reconfigure),
      .load_i           (s_tick_load),
      .load_subsecond_i (command_i.load_subsecond),
      .subsecond_tick_o (s_subsecond_tick),
      .second_tick_o    (s_second_tick),
      .subsecond_o      (s_subsecond)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_enable_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_enable_d),
      .dat_o  (s_enable_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_time_valid_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_time_valid_d),
      .dat_o  (s_time_valid_q)
  );
  dffrc #(
      .DATA_WIDTH(32),
      .RESET_VAL (RTC_CLOCK_HZ)
  ) u_second_cycles_dffrc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_second_cycles_d),
      .dat_o  (s_second_cycles_q)
  );
  dffr #(
      .DATA_WIDTH(16)
  ) u_calibration_ppm_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_calibration_ppm_d),
      .dat_o  (s_calibration_ppm_q)
  );
  dffr #(
      .DATA_WIDTH(64)
  ) u_seconds_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_seconds_d),
      .dat_o  (s_seconds_q)
  );
  dffr #(
      .DATA_WIDTH(64)
  ) u_alarm0_seconds_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm0_seconds_d),
      .dat_o  (s_alarm0_seconds_q)
  );
  dffr #(
      .DATA_WIDTH(8)
  ) u_alarm0_subsecond_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm0_subsecond_d),
      .dat_o  (s_alarm0_subsecond_q)
  );
  dffr #(
      .DATA_WIDTH(64)
  ) u_alarm1_seconds_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm1_seconds_d),
      .dat_o  (s_alarm1_seconds_q)
  );
  dffr #(
      .DATA_WIDTH(8)
  ) u_alarm1_subsecond_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm1_subsecond_d),
      .dat_o  (s_alarm1_subsecond_q)
  );
  dffr #(
      .DATA_WIDTH(2)
  ) u_alarm_active_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm_active_d),
      .dat_o  (s_alarm_active_q)
  );
  dffr #(
      .DATA_WIDTH(2)
  ) u_alarm_config_enable_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_alarm_config_enable_d),
      .dat_o  (s_alarm_config_enable_q)
  );
  dffr #(
      .DATA_WIDTH(32)
  ) u_period_reload_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_period_reload_d),
      .dat_o  (s_period_reload_q)
  );
  dffr #(
      .DATA_WIDTH(32)
  ) u_period_count_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_period_count_d),
      .dat_o  (s_period_count_q)
  );
  dffr #(
      .DATA_WIDTH(2)
  ) u_period_control_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_period_control_d),
      .dat_o  (s_period_control_q)
  );
  dffr #(
      .DATA_WIDTH(1)
  ) u_period_active_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_period_active_d),
      .dat_o  (s_period_active_q)
  );
  dffr #(
      .DATA_WIDTH(5)
  ) u_event_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_event_d),
      .dat_o  (s_event_q)
  );
  dffr #(
      .DATA_WIDTH(5)
  ) u_interrupt_enable_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_interrupt_enable_d),
      .dat_o  (s_interrupt_enable_q)
  );
  dffr #(
      .DATA_WIDTH(5)
  ) u_wake_enable_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_wake_enable_d),
      .dat_o  (s_wake_enable_q)
  );

  assign event_o            = s_event_q;
  assign interrupt_enable_o = s_interrupt_enable_q;
  assign wake_enable_o      = s_wake_enable_q;
  assign status_o           = {s_period_active_q, s_alarm_active_q, s_time_valid_q, s_enable_q};
  assign wake_o             = |(s_event_q & s_wake_enable_q);

endmodule
