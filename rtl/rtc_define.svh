// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`ifndef RTC_DEFINE_SVH
`define RTC_DEFINE_SVH

// verilog_format: off
`define RTC_CTRL_OFFSET                  12'h000
`define RTC_STATUS_OFFSET                12'h004
`define RTC_COMMAND_OFFSET               12'h008
`define RTC_COMMAND_STATUS_OFFSET        12'h00C
`define RTC_TIME_LOAD_LO_OFFSET          12'h010
`define RTC_TIME_LOAD_HI_OFFSET          12'h014
`define RTC_TIME_LOAD_SUBSEC_OFFSET      12'h018
`define RTC_SNAPSHOT_TIME_LO_OFFSET      12'h01C
`define RTC_SNAPSHOT_TIME_HI_OFFSET      12'h020
`define RTC_SNAPSHOT_SUBSEC_OFFSET       12'h024
`define RTC_SECOND_CYCLES_OFFSET         12'h028
`define RTC_CALIB_PPM_OFFSET             12'h02C
`define RTC_ALARM0_TIME_LO_OFFSET        12'h030
`define RTC_ALARM0_TIME_HI_OFFSET        12'h034
`define RTC_ALARM0_SUBSEC_OFFSET         12'h038
`define RTC_ALARM1_TIME_LO_OFFSET        12'h03C
`define RTC_ALARM1_TIME_HI_OFFSET        12'h040
`define RTC_ALARM1_SUBSEC_OFFSET         12'h044
`define RTC_ALARM_ENABLE_OFFSET          12'h048
`define RTC_PERIOD_RELOAD_OFFSET         12'h04C
`define RTC_PERIOD_CTRL_OFFSET           12'h050
`define RTC_EVENT_RAW_OFFSET             12'h054
`define RTC_EVENT_CLEAR_OFFSET           12'h058
`define RTC_EVENT_TEST_OFFSET            12'h05C
`define RTC_INTR_ENABLE_OFFSET            12'h060
`define RTC_INTR_STATE_OFFSET             12'h064
`define RTC_WAKE_ENABLE_OFFSET            12'h068
`define RTC_WAKE_STATE_OFFSET             12'h06C
`define RTC_CLOCK_HZ_OFFSET                12'h0F0
`define RTC_IP_ID_OFFSET                   12'h0F4
`define RTC_IP_VERSION_OFFSET              12'h0F8
`define RTC_CAPABILITY_OFFSET              12'h0FC

`define RTC_CTRL_ENABLE_MASK               32'h0000_0001
`define RTC_CTRL_VALID_MASK                32'h0000_0001

`define RTC_STATUS_ENABLED_BIT             0
`define RTC_STATUS_TIME_VALID_BIT          1
`define RTC_STATUS_COMMAND_BUSY_BIT        2
`define RTC_STATUS_COMMAND_DONE_BIT        3
`define RTC_STATUS_COMMAND_ERROR_BIT       4
`define RTC_STATUS_SNAPSHOT_VALID_BIT      5
`define RTC_STATUS_LINK_READY_BIT           6
`define RTC_STATUS_ALARM0_ACTIVE_BIT        8
`define RTC_STATUS_ALARM1_ACTIVE_BIT        9
`define RTC_STATUS_PERIOD_ACTIVE_BIT        10

`define RTC_COMMAND_APPLY_CONFIG            3'd1
`define RTC_COMMAND_SET_TIME                3'd2
`define RTC_COMMAND_SNAPSHOT                3'd3
`define RTC_COMMAND_CLEAR_EVENTS            3'd4
`define RTC_COMMAND_INJECT_EVENTS           3'd5
`define RTC_COMMAND_VALID_MASK              32'h0000_0007

`define RTC_COMMAND_STATUS_DONE_MASK        32'h0000_0002
`define RTC_COMMAND_STATUS_ERROR_MASK       32'h0000_0004

`define RTC_PERIOD_CTRL_ENABLE_MASK         32'h0000_0001
`define RTC_PERIOD_CTRL_AUTO_RELOAD_MASK    32'h0000_0002
`define RTC_PERIOD_CTRL_VALID_MASK          32'h0000_0003

`define RTC_EVENT_SECOND_MASK               5'b00001
`define RTC_EVENT_ALARM0_MASK               5'b00010
`define RTC_EVENT_ALARM1_MASK               5'b00100
`define RTC_EVENT_PERIODIC_MASK             5'b01000
`define RTC_EVENT_OVERFLOW_MASK             5'b10000
`define RTC_EVENT_VALID_MASK                5'b11111

`define RTC_SUBSECOND_HZ                    32'd256
`define RTC_SUBSECOND_MAX                   8'hFF
`define RTC_SECOND_CYCLES_MIN               32'd256
`define RTC_CALIB_PPM_MIN                   -16'sd488
`define RTC_CALIB_PPM_MAX                   16'sd488

`define RTC_IP_ID_VALUE                     32'h5254_4332
`define RTC_IP_VERSION_VALUE                32'h0002_0000
`define RTC_ABI_VERSION                     8'h02
`define RTC_CAPABILITY_FEATURES             8'h7F
// verilog_format: on

`endif
