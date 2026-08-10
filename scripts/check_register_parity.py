#!/usr/bin/env python3
"""Check hand-written RTC SystemVerilog and C register offsets."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SV = ROOT / "rtl" / "rtc_define.svh"
C = ROOT / "sw" / "include" / "rtc_regs.h"
SV_RE = re.compile(r"`define\s+(RTC_[A-Z0-9_]+_OFFSET)\s+12'h([0-9A-Fa-f]+)")
C_RE = re.compile(
    r"#define\s+(RTC_[A-Z0-9_]+_OFFSET)\s+UINT32_C\(0x([0-9A-Fa-f]+)\)"
)


def offsets(path: Path, pattern: re.Pattern[str]) -> dict[str, int]:
    return {name: int(value, 16) for name, value in pattern.findall(path.read_text())}


def main() -> int:
    sv_offsets = offsets(SV, SV_RE)
    c_offsets = offsets(C, C_RE)
    if sv_offsets != c_offsets:
        missing_c = sorted(sv_offsets.keys() - c_offsets.keys())
        missing_sv = sorted(c_offsets.keys() - sv_offsets.keys())
        mismatched = sorted(
            name
            for name in sv_offsets.keys() & c_offsets.keys()
            if sv_offsets[name] != c_offsets[name]
        )
        raise SystemExit(
            f"RTC register mismatch: missing C={missing_c}, missing SV={missing_sv}, "
            f"values={mismatched}"
        )
    print(f"RTC register parity OK ({len(sv_offsets)} offsets)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
