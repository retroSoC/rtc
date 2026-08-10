# RTC V2 Datasheet

## Purpose

RTC V2 is a binary timekeeping block for SoCs with an APB programming clock
and an independent RTC source clock. Hardware stores seconds since the Unix
epoch plus an 8-bit subsecond value. Calendar, timezone, daylight-saving, and
leap-second policy remain software responsibilities.

RTC V2 does not provide a crystal oscillator, battery switch, retention cells,
tamper pins, or a power controller. Time is lost when `rtc_rst_n_i` is asserted.

## Features

- 64-bit seconds and 1/256-second subsecond time;
- programmable input cycles per second and smooth signed -488 to +488 ppm
  correction;
- two one-shot absolute alarms with subsecond comparison;
- 32-bit periodic timer in 1/256-second units, one-shot or auto-reload;
- sticky second, alarm, periodic, and overflow events;
- independent interrupt and wake masks plus test injection;
- explicit atomic snapshots and non-blocking APB-to-RTC commands;
- strict APB4 alignment, mapping, direction, strobe, and value checks.

## Command Model

Software writes staging registers and then writes one opcode to `COMMAND`.
`APPLY_CONFIG`, `SET_TIME`, `SNAPSHOT`, `CLEAR_EVENTS`, and `INJECT_EVENTS` are
supported. `COMMAND_STATUS.BUSY` remains set until the RTC response returns.
Software must use a bounded timeout because a stopped RTC clock cannot respond.

Changing `SECOND_CYCLES` while the RTC remains enabled is rejected. Disable the
RTC, apply the new period, then enable it. An alarm that has fired is not
re-armed by unrelated configuration writes; change its target or toggle its
enable bit to arm it again.

## Register Map

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW | Staged enable |
| `0x004` | `STATUS` | RO | Active, command, snapshot and link state |
| `0x008` | `COMMAND` | WO | Submit one command opcode |
| `0x00C` | `COMMAND_STATUS` | RO/RW1C | Busy, done, error, opcode and response |
| `0x010..0x018` | `TIME_LOAD_*` | RW | Staged seconds and subsecond load value |
| `0x01C..0x024` | `SNAPSHOT_*` | RO | Last coherent time snapshot |
| `0x028` | `SECOND_CYCLES` | RW | RTC input clocks per second, minimum 256 |
| `0x02C` | `CALIB_PPM` | RW | Signed smooth calibration |
| `0x030..0x048` | `ALARM*` | RW | Two absolute compare values and enable bits |
| `0x04C..0x050` | `PERIOD_*` | RW | Periodic timer reload and control |
| `0x054` | `EVENT_RAW` | RO | Sticky raw event causes |
| `0x058` | `EVENT_CLEAR` | WO | Staged event-clear mask |
| `0x05C` | `EVENT_TEST` | WO | Staged event-test mask |
| `0x060..0x064` | `INTR_*` | RW/RO | Interrupt mask and masked state |
| `0x068..0x06C` | `WAKE_*` | RW/RO | Wake mask and wake reason |
| `0x0F0` | `CLOCK_HZ` | RO | Nominal integrated RTC source frequency |
| `0x0F4` | `IP_ID` | RO | ASCII `RTC2`, `0x52544332` |
| `0x0F8` | `IP_VERSION` | RO | `0x00020000` |
| `0x0FC` | `CAPABILITY` | RO | ABI, alarm count, subsecond width and features |

Event bits 0 through 4 are second, alarm 0, alarm 1, periodic, and overflow.
Event setting wins over clearing in the same RTC cycle. `irq_o` is synchronous
to `apb4.pclk`; `wake_o` is an RTC-domain level that remains asserted while any
enabled wake event is pending.
