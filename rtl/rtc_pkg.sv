// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

package rtc_pkg;

  typedef enum logic [2:0] {
    RTC_CMD_NONE          = 3'd0,
    RTC_CMD_APPLY_CONFIG  = 3'd1,
    RTC_CMD_SET_TIME      = 3'd2,
    RTC_CMD_SNAPSHOT      = 3'd3,
    RTC_CMD_CLEAR_EVENTS  = 3'd4,
    RTC_CMD_INJECT_EVENTS = 3'd5
  } rtc_command_e;

  typedef enum logic [2:0] {
    RTC_RSP_OK             = 3'd0,
    RTC_RSP_INVALID_CONFIG = 3'd1,
    RTC_RSP_ILLEGAL_STATE  = 3'd2,
    RTC_RSP_RESET_ABORTED  = 3'd3
  } rtc_response_e;

  typedef struct packed {
    rtc_command_e       opcode;
    logic               enable;
    logic [31:0]        second_cycles;
    logic signed [15:0] calibration_ppm;
    logic [63:0]        load_seconds;
    logic [7:0]         load_subsecond;
    logic [63:0]        alarm0_seconds;
    logic [7:0]         alarm0_subsecond;
    logic [63:0]        alarm1_seconds;
    logic [7:0]         alarm1_subsecond;
    logic [1:0]         alarm_enable;
    logic [31:0]        period_reload;
    logic [1:0]         period_control;
    logic [4:0]         event_mask;
    logic [4:0]         interrupt_enable;
    logic [4:0]         wake_enable;
  } rtc_command_t;

  typedef struct packed {
    rtc_command_e  opcode;
    rtc_response_e response;
    logic [63:0]   snapshot_seconds;
    logic [7:0]    snapshot_subsecond;
  } rtc_response_t;

endpackage
