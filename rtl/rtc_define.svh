// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// rtc is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_RTC_DEF_SV
`define INC_RTC_DEF_SV

/* register mapping
 * RTC_CTRL:
 * BITS:   | 31:5   | 4  | 3    | 2      | 1    | 0   |
 * FIELDS: | RES    | EN | OVIE | ALRMIE | SCIE | CMF |
 * PERMS:  | NONE   | RW | RW   | RW     | RW   | RW  |
 * ----------------------------------------------------
 * RTC_PSCR: WRITE-PROTECTED by LWOFF in CMF mode
 * BITS:   | 31:20 | 19:0 |
 * FIELDS: | RES   | PSCR |
 * PERMS:  | NONE  | RW   |
 * ----------------------------------------------------
 * RTC_CNT: WRITE-PROTECTED by LWOFF in CMF mode
 * BITS:   | 31:0 |
 * FIELDS: | CNT  |
 * PERMS:  | RW   |
* -----------------------------------------------------
 * RTC_ALRM: WRITE-PROTECTED by LWOFF in CMF mode
 * BITS:   | 31:0 |
 * FIELDS: | ALRM |
 * PERMS:  | RW   |
 * ----------------------------------------------------
 * RTC_ISTA
 * BITS:   | 31:3 | 2     | 1      | 0     |
 * FIELDS: | RES  | OVIF  | ALRMIF | SCIF  |
 * PERMS:  | NONE | RC_W0 | RC_W0  | RC_W0 |
 * ----------------------------------------------------
 * RTC_SSTA
 * BITS:   | 31:2 | 1     | 0     |
 * FIELDS: | RES  | LWOFF | RSYNF |
 * PERMS:  | NONE | RO    | RO    |
 * ----------------------------------------------------
*/

// verilog_format: off
`define RTC_CTRL 4'b0000 // BASEADDR + 0x00
`define RTC_PSCR 4'b0001 // BASEADDR + 0x04
`define RTC_CNT  4'b0010 // BASEADDR + 0x08
`define RTC_ALRM 4'b0011 // BASEADDR + 0x0C
`define RTC_ISTA 4'b0100 // BASEADDR + 0x10
`define RTC_SSTA 4'b0101 // BASEADDR + 0x14

`define RTC_CTRL_ADDR {26'b0, `RTC_CTRL, 2'b00}
`define RTC_PSCR_ADDR {26'b0, `RTC_PSCR, 2'b00}
`define RTC_CNT_ADDR  {26'b0, `RTC_CNT , 2'b00}
`define RTC_ALRM_ADDR {26'b0, `RTC_ALRM, 2'b00}
`define RTC_ISTA_ADDR {26'b0, `RTC_ISTA, 2'b00}
`define RTC_SSTA_ADDR {26'b0, `RTC_SSTA, 2'b00}

`define RTC_CTRL_WIDTH 5
`define RTC_PSCR_WIDTH 20
`define RTC_CNT_WIDTH  32
`define RTC_ALRM_WIDTH 32
`define RTC_ISTA_WIDTH 3
`define RTC_SSTA_WIDTH 2

`define RTC_PSCR_MIN_VAL {{(`RTC_PSCR_WIDTH-2){1'b0}}, 2'd2}
// verilog_format: on

interface rtc_if (
    input logic rtc_clk_i,
    input logic rtc_rst_n_i
);
  logic irq_o;

  modport dut(input rtc_clk_i, input rtc_rst_n_i, output irq_o);
  modport tb(input rtc_clk_i, input rtc_rst_n_i, input irq_o);
endinterface

`endif
