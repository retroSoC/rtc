# RTC V2 Test Plan

## Register and Protocol

- reset values, ID, version, capability, and hand-written RTL/C parity;
- aligned/misaligned, mapped/unmapped, legal/illegal direction, `PSTRB`,
  reserved fields, busy commands, and no-side-effect APB errors;
- command completion, response errors, stopped-clock timeout, and independent
  APB/RTC reset recovery.

## Timekeeping

- set and coherent snapshot around subsecond and second rollover;
- positive, zero, and negative calibration, period validation, and live-period
  update rejection;
- two alarms, simultaneous and past alarms, one-shot disarm and explicit rearm;
- periodic one-shot/auto-reload, event set-dominant clearing, IRQ and wake masks;
- 64-bit overflow and event-test injection.

## Software

- invalid arguments and bounded timeout paths;
- Epoch/calendar conversion at 1970, leap years, non-leap centuries, year 9999,
  and out-of-range dates.
