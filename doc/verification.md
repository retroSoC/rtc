# Verification Contract

`make test` runs the accelerated RTC core scenario with Icarus and Verilator,
an asynchronous dual-clock APB wrapper scenario with Verilator, and
deterministic host C tests. The wrapper scenario covers mailbox commands,
PSTRB writes, protocol errors, coherent snapshots, IRQ, and wake. `make lint`
elaborates the complete APB wrapper and both Common asynchronous mailboxes.
`make synth` checks the synthesizable core after `sv2v` conversion.

`make formal` proves command response, active-status mapping, legal period and
calibration state, time stability without a tick or command, and wake/event
relations with SBY and Bitwuzla. Common owns the detailed mailbox protocol and
reset-barrier proofs; this repository verifies their RTC integration through
simulation and lint.
