// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

interface rtc_if (
    input logic rtc_clk_i,
    input logic rtc_rst_n_i
);
  logic irq_o;
  logic wake_o;

  modport dut(input rtc_clk_i, input rtc_rst_n_i, output irq_o, output wake_o);
  modport tb(input rtc_clk_i, input rtc_rst_n_i, input irq_o, input wake_o);
endinterface
