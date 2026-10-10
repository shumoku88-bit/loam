#!/usr/bin/env python3
"""Actual -> single Event -> existing writers, using temporary synthetic data only."""
from __future__ import annotations

import argparse
import datetime
import fcntl
import importlib.util
import os
from pathlib import Path
import re
import statistics
import struct
import tempfile
import termios

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
DETAIL = b"Actual / Transaction detail"
ACTUAL = b"Household Actuals Workspace"


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    elapsed, output = terminal.capture(expected)
    return elapsed, probe.ANSI.sub(b"", output)


def resize(terminal, rows, cols):
    fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    _, output = terminal.capture(DETAIL)
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions)
    assert b"\n" not in output and b"\r" not in output
    clean = probe.ANSI.sub(b"", output)
    assert b"Household Day" not in clean and b"Scheduled" not in clean and b"Actuals [active]" not in clean
    return clean


def sections(root):
    header, remaining = (root / "household.loam").read_text().split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2"
    result = {}
    while remaining:
        framing, remaining = remaining.split("\n", 1)
        tag, name, count = framing.split("\t")
        assert tag == "SECTION"
        size = int(count)
        result[name], remaining = remaining[:size], remaining[size:]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", type=int, default=4, help="synthetic history size (minimum 4)")
    args = parser.parse_args()
    assert args.events >= 4
    with tempfile.TemporaryDirectory(prefix="loam-actual-detail-pty-") as tmp:
        root = Path(tmp)
        probe.fixture(root, events=args.events, days=500)
        frozen = probe.digest(root)
        original = sections(root)
        terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        try:
            # A unique description query selects the last synthetic Event even in a large history.
            index = args.events - 1
            query = f"synthetic resource {index}".encode()
            send(terminal, b"a/" + query + b"\r", b"Search: /" + query)
            elapsed, opened = send(terminal, b"\r", DETAIL)
            identity = f"resource-{index}".encode()
            assert identity in opened and query in opened and b"Status: Current" in opened
            assert b"Household Day" not in opened and b"Scheduled" not in opened
            assert b"Actuals [active]" not in opened and b"synthetic resource 0" not in opened
            for label in (b"Correct contents", b"Change date", b"Reverse", b"Merchant", b"Manage Loci", b"Record new"):
                assert label in opened, (label, opened)
            assert terminal.idle(.2) == 0, "focused detail emitted output while idle"
            latencies = []
            for rows, cols in ((14, 48), (10, 32), (6, 32), (24, 80), (40, 144)):
                resize(terminal, rows, cols)
                if rows >= 24:  # All content fits; boundary keys correctly emit no diff.
                    continue
                send(terminal, b"\x1b[F", b"End: actions")
                send(terminal, b"\x1b[H", b"Status:")
                latencies.append(send(terminal, b"\x1b[6~", b"End: actions")[0])
                send(terminal, b"\x1b[H", b"Status:")
            # Both back keys return in one step and keep query/selection.
            _, restored = send(terminal, b"q", ACTUAL)
            assert b"Search: /" + query in restored and identity in restored
            send(terminal, b"\r", DETAIL)
            send(terminal, b"\x1b", ACTUAL)
            send(terminal, b"\r", DETAIL)
            assert probe.digest(root) == frozen, "read-only focused navigation wrote evidence"

            # Every Actual-side action still reaches the old editor/session; cancels publish nothing.
            for key, marker in ((b"c", b"Correction / Edit"), (b"d", b"Actual Date / Edit"),
                                (b"r", b"Actual / Reverse / Date"), (b"m", b"Event Merchant / Edit"),
                                (b"n", b"Record / Edit"), (b"g", b"Locus Administration")):
                send(terminal, key, marker)
                _, returned = send(terminal, b"\x1b", DETAIL)
                assert identity in returned and probe.digest(root) == frozen, (key, returned)

            # Date correction retains the Event, follows its new date, and requires confirmation.
            send(terminal, b"d", b"Actual Date / Edit")
            changed_date = str(datetime.date.today() - datetime.timedelta(days=1)).encode()
            send(terminal, b"\x7f" * 10 + changed_date + b"\r", b"Actual Date / Preview")
            assert probe.digest(root) == frozen, "date preview published"
            _, dated = send(terminal, b"\r", DETAIL)
            assert identity in dated and b"Date: " + changed_date in dated
            after_date = probe.digest(root)
            send(terminal, b"q", ACTUAL)
            send(terminal, b"\r", DETAIL)

            # Description-only correction uses the prefilled postings and explicit existing Preview.
            send(terminal, b"c", b"Correction / Edit")
            send(terminal, b"-corrected" + b"\t" * 5 + b"\r", b"Correction / Preview")
            assert probe.digest(root) == after_date, "correction preview published"
            _, corrected = send(terminal, b"\r", DETAIL)
            assert b"no longer current" in corrected and identity in corrected
            assert query not in corrected and b"Effects (" not in corrected, "corrected detail showed stale contents"
            send(terminal, b"q", ACTUAL)
            _, successor = send(terminal, b"\r", DETAIL)
            assert query + b"-corrected" in successor and b"Date: " + changed_date in successor
            assert b"no longer current" not in successor

            send(terminal, b"m", b"Event Merchant / Edit")
            send(terminal, b"\t\r", b"Event Merchant / Preview")
            send(terminal, b"\r", b"Published Nonmerchant")
            send(terminal, b"m", b"Merchant already classified: Nonmerchant")
            send(terminal, b"r", b"Actual / Reverse / Date")
            send(terminal, b"\r", b"Actual / Reverse / Preview")
            before_reversal = probe.digest(root)
            assert "REVERSAL-OF" not in sections(root)["Actual"]
            _, reversed_detail = send(terminal, b"\r", DETAIL)
            assert b"Reversed " in reversed_detail and query + b"-corrected" in reversed_detail
            assert b"Reversed by:" in reversed_detail and b"Merchant: Nonmerchant" in reversed_detail
            assert b"[r] Reverse" not in reversed_detail and b"[c] Correct" not in reversed_detail
            assert probe.digest(root) != before_reversal
            send(terminal, b"q", ACTUAL)
            send(terminal, b"q", b"LOAM Home")
            terminal.quit()
            current = sections(root)
            assert "REPLACES\t" + identity.decode() in current["Actual"]
            assert "REVERSAL-OF\t" in current["Actual"] and "NONMERCHANT" in current["Actual"]
            assert "-corrected" in current["Actual"]
            assert {k: v for k, v in current.items() if k != "Actual"} == {
                k: v for k, v in original.items() if k != "Actual"}, "focused actions changed another canonical family"
            after = probe.digest(root)
            allowed = {"household.loam", "household.loam.prev"}
            assert {k: v for k, v in after.items() if k not in allowed} == {
                k: v for k, v in frozen.items() if k not in allowed}, "focused actions changed config/other files"
            print(f"Actual detail PTY passed: {args.events} synthetic Events; open {elapsed:.1f}ms; "
                  f"median focused paging {statistics.median(latencies):.1f}ms. "
                  "Actions/cancels, date/correction/Merchant/reversal publication, reload, return and resize passed.")
        finally:
            terminal.close()


if __name__ == "__main__":
    main()
