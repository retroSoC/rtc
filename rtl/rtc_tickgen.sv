// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "rtc_define.svh"

module rtc_tickgen (
    // verilog_format: off
    input  logic               clk_i,
    input  logic               rst_n_i,
    input  logic               enable_i,
    input  logic [31:0]        second_cycles_i,
    input  logic signed [15:0] calibration_ppm_i,
    input  logic               reconfigure_i,
    input  logic               load_i,
    input  logic [7:0]         load_subsecond_i,
    output logic               subsecond_tick_o,
    output logic               second_tick_o,
    output logic [7:0]         subsecond_o
    // verilog_format: on
);

  localparam logic [20:0] CALIBRATION_DENOMINATOR = 21'd1_000_000;

  logic [32:0] s_phase_d, s_phase_q;
  logic [20:0] s_calibration_accumulator_d, s_calibration_accumulator_q;
  logic [7:0] s_subsecond_d, s_subsecond_q;
  logic [15:0] s_calibration_magnitude;
  logic [20:0] s_calibration_sum;
  logic [ 8:0] s_phase_step;
  logic [32:0] s_phase_sum;
  logic        s_calibration_adjust;
  logic s_subsecond_tick_d, s_subsecond_tick_q;
  logic s_second_tick_d, s_second_tick_q;

  assign s_calibration_magnitude = calibration_ppm_i[15] ?
      (~calibration_ppm_i + 16'd1) : calibration_ppm_i;
  assign s_calibration_sum = s_calibration_accumulator_q + ({5'd0, s_calibration_magnitude} << 8);
  assign s_calibration_adjust = s_calibration_sum >= CALIBRATION_DENOMINATOR;

  always_comb begin
    s_phase_step = 9'd256;
    if (s_calibration_adjust && (calibration_ppm_i > 0)) begin
      s_phase_step = 9'd257;
    end else if (s_calibration_adjust && (calibration_ppm_i < 0)) begin
      s_phase_step = 9'd255;
    end
  end

  assign s_phase_sum = s_phase_q + {{24{1'b0}}, s_phase_step};

  always_comb begin
    s_phase_d                   = s_phase_q;
    s_calibration_accumulator_d = s_calibration_accumulator_q;
    s_subsecond_d               = s_subsecond_q;
    s_subsecond_tick_d          = 1'b0;
    s_second_tick_d             = 1'b0;

    if (reconfigure_i) begin
      s_phase_d                   = '0;
      s_calibration_accumulator_d = '0;
    end
    if (load_i) begin
      s_phase_d                   = '0;
      s_calibration_accumulator_d = '0;
      s_subsecond_d               = load_subsecond_i;
    end else if (enable_i) begin
      if (calibration_ppm_i == 0) begin
        s_calibration_accumulator_d = '0;
      end else if (s_calibration_adjust) begin
        s_calibration_accumulator_d = s_calibration_sum - CALIBRATION_DENOMINATOR;
      end else begin
        s_calibration_accumulator_d = s_calibration_sum[20:0];
      end

      if (s_phase_sum >= {1'b0, second_cycles_i}) begin
        s_phase_d          = s_phase_sum - {1'b0, second_cycles_i};
        s_subsecond_tick_d = 1'b1;
        if (s_subsecond_q == `RTC_SUBSECOND_MAX) begin
          s_subsecond_d   = '0;
          s_second_tick_d = 1'b1;
        end else begin
          s_subsecond_d = s_subsecond_q + 8'd1;
        end
      end else begin
        s_phase_d = s_phase_sum[32:0];
      end
    end
  end

  dffr #(
      .DATA_WIDTH(33)
  ) u_phase_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_phase_d),
      .dat_o  (s_phase_q)
  );

  dffr #(
      .DATA_WIDTH(21)
  ) u_calibration_accumulator_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_calibration_accumulator_d),
      .dat_o  (s_calibration_accumulator_q)
  );

  dffr #(
      .DATA_WIDTH(8)
  ) u_subsecond_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_subsecond_d),
      .dat_o  (s_subsecond_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_subsecond_tick_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_subsecond_tick_d),
      .dat_o  (s_subsecond_tick_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_second_tick_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_second_tick_d),
      .dat_o  (s_second_tick_q)
  );

  assign subsecond_tick_o = s_subsecond_tick_q;
  assign second_tick_o    = s_second_tick_q;
  assign subsecond_o      = s_subsecond_q;

endmodule
