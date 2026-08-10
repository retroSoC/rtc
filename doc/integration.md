# Integration Guide

Instantiate `apb4_rtc` with the Common `apb4_if` and `rtc_if` interfaces and
set `RTC_CLOCK_HZ` to the nominal frequency presented on `rtc_clk_i`. The reset
value also initializes `SECOND_CYCLES`; software may recalibrate it before
enabling the counter.

`apb4.pclk` and `rtc_clk_i` are asynchronous. The implementation uses Common
`async_reqack` mailboxes for commands and responses, and `cdc_sync` for sticky
event and status levels. Integrators must include these crossings in CDC and
timing inventories and place the two clocks in asynchronous timing groups.

`irq_o` belongs to the APB domain and can connect to the normal interrupt
controller. `wake_o` belongs to the RTC domain and is intended for an
always-on power controller. Connecting it only to a system-clocked status
register provides observability but does not make it a functional deep-sleep
wake source.

The IP has no retention implementation. A product claiming time across system
power loss must provide a qualified RTC clock, isolated backup supply, retained
state, power-aware verification, and physical implementation constraints.
