# RTC

RTC V2 is an APB4 real-time clock controller with an independent timekeeping
clock domain. It provides a 64-bit Unix-epoch counter, 1/256-second resolution,
two alarms, a periodic wake timer, smooth digital calibration, interrupts, and
a dedicated wake request.

The APB and RTC clocks may be asynchronous. Software submits bounded commands
through one-entry Common asynchronous mailboxes; APB transfers never wait for
the slow clock. Time reads use an explicit atomic snapshot.

The register ABI is manually encoded in
[`rtl/rtc_define.svh`](rtl/rtc_define.svh) and
[`sw/include/rtc_regs.h`](sw/include/rtc_regs.h). Run `make register-check`
whenever either definition changes.

```sh
make doctor
make format-check register-check lint
make test synth formal
```

See [`doc/datasheet.md`](doc/datasheet.md) for the programming model and
[`doc/integration.md`](doc/integration.md) for clock, reset, and wake-domain
requirements.
