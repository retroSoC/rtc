// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// rtc is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

interface rtc_if (
    input logic rtc_clk_i,
    input logic rtc_rst_n_i
);
  logic irq_o;

  modport dut(input rtc_clk_i, input rtc_rst_n_i, output irq_o);
  modport tb(input rtc_clk_i, input rtc_rst_n_i, input irq_o);
endinterface
