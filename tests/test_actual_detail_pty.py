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
from scheduled_pty_support import text_caret, no_text_caret

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
DETAIL = b"Actual / Transaction detail"
ACTUAL = b"Household Actuals Workspace"


def send_raw(terminal, keys, expected):
    os.write(terminal.fd, keys)
    return terminal.capture(expected)[1]


def resize_input(terminal, tail, root, frozen):
    for rows, cols in ((9, 32), (14, 48), (24, 80), (40, 120), (40, 144)):
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        _, output = terminal.capture(tail.encode())
        text_caret(output, rows, cols, tail)
        assert terminal.idle(.3) == 0, "idle Actual editor emitted output"
        assert probe.digest(root) == frozen, "Actual text-mode resize wrote authority"


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


def search_frame(terminal, keys, expected, rows, cols, active=True):
    if keys:
        os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions and all(1 <= int(r) <= rows and 1 <= int(c) < cols
                             for r, c in positions), output
    visibility = re.findall(rb"\x1b\[\?25([hl])", output)
    assert visibility and visibility[-1] == (b"h" if active else b"l"), output
    assert terminal.idle(.15) == 0, "Actual search caret emitted idle output"
    return tuple(map(int, positions[-1]))


def search_caret_navigation(terminal, root, frozen):
    search_frame(terminal, b"/", b"Search: /", 48, 160)
    query = ("日本語" * 45 + "末尾").encode()
    search_frame(terminal, b"\x1b[200~" + query + b"\x1b[201~",
                 "末尾".encode(), 48, 160)
    search_frame(terminal, b"\x7f", "末".encode(), 48, 160)
    for rows, cols in ((9, 32), (14, 48), (24, 80), (40, 120)):
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        search_frame(terminal, b"", "末".encode(), rows, cols)
    search_frame(terminal, b"\r", b"Search: /", 40, 120, active=False)
    search_frame(terminal, b"/", b"Search: /", 40, 120)
    search_frame(terminal, b"\x1b", b"All Current", 40, 120, active=False)
    assert probe.digest(root) == frozen, "search input/accept/cancel wrote household evidence"


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
            # Entry includes history before today without first toggling f.
            _, overview = send(terminal, b"a", ACTUAL)
            assert b"All Current" in overview and b"newest first" in overview
            # The fixture also retains one seeded paid Actual.
            assert f"1/{args.events + 1}".encode() in overview, overview
            search_caret_navigation(terminal, root, frozen)
            # A unique description query selects the last synthetic Event even in a large history.
            index = args.events - 1
            query = f"synthetic resource {index}".encode()
            send(terminal, b"/" + query + b"\r", b"Search: /" + query)
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
            for key, marker in ((b"c", b"Correction / Edit"), (b"d", b"Actual / Date / Edit"),
                                (b"r", b"Actual / Reverse / Date"), (b"m", b"Event Merchant / Edit"),
                                (b"n", b"Record / Edit"), (b"g", b"Locus Administration")):
                send(terminal, key, marker)
                _, returned = send(terminal, b"\x1b", DETAIL)
                assert identity in returned and probe.digest(root) == frozen, (key, returned)

            # Date correction stays over the selected Actual context when roomy.
            # The same retained target and input survive compact and roomy resizes.
            os.write(terminal.fd, b"d")
            _, raw_date_edit = terminal.capture(b"Actual / Date / Edit")
            assert b"\x1b[2J" not in raw_date_edit, "floating date editor cleared its parent"
            date_edit = probe.ANSI.sub(b"", raw_date_edit)
            assert all(label in date_edit for label in
                       (b"Current date:", b"New date:", b"Target Actual:", identity))
            original_date = re.search(rb"New date:\s*(\d{4}-\d{2}-\d{2})", date_edit).group(1).decode()
            text_caret(raw_date_edit, 40, 144, original_date)
            resize_input(terminal, original_date, root, frozen)
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 14, 48, 0, 0))
            _, compact_date = terminal.capture(b"Actual / Date / Edit")
            assert b"Current date:" in probe.ANSI.sub(b"", compact_date)
            assert probe.digest(root) == frozen, "date editor resize wrote authority"
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            _, resumed_date = terminal.capture(b"Actual / Date / Edit")
            assert identity in probe.ANSI.sub(b"", resumed_date), (
                "date editor resize lost selected Actual", resumed_date)
            changed_date = str(datetime.date.today() - datetime.timedelta(days=1)).encode()
            raw_preview = send_raw(terminal, b"\x7f" * 10 + changed_date + b"\r",
                                   b"Actual / Date / Preview")
            no_text_caret(raw_preview)
            date_preview = probe.ANSI.sub(b"", raw_preview)
            # The production renderer writes dirty rows only. Current date and
            # target identity remain on screen, but are not re-emitted in the
            # Edit -> Preview diff; the Lean view test checks the full frame.
            expected_changes = (b"Proposed date:", b"Publish date change",
                                b"Only the occurrence date changes.", changed_date)
            assert all(label in date_preview for label in expected_changes), (
                [label for label in expected_changes if label not in date_preview],
                date_preview[-1600:])
            assert probe.digest(root) == frozen, "date preview published"
            # The same review cannot Publish while compact geometry hides its
            # target/confirmation. The draft survives a subsequent enlargement.
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 9, 32, 0, 0))
            terminal.capture(b"Actual / Date / Preview")
            refused_date = send_raw(terminal, b"\r", b"Enlarge terminal")
            no_text_caret(refused_date)
            assert b"Enlarge terminal" in probe.ANSI.sub(b"", refused_date)
            assert probe.digest(root) == frozen, "compact date review wrote authority"
            text_caret(send_raw(terminal, b"e", b"New date:"), 9, 32, changed_date.decode())
            no_text_caret(send_raw(terminal, b"\r", b"Actual / Date / Preview"))
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            _, restored_preview = terminal.capture(b"Actual / Date / Preview")
            assert b"Proposed date" in probe.ANSI.sub(b"", restored_preview)
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

            # Merchant shares the same adaptive terminal loop and keeps authority.
            before_merchant = probe.digest(root)
            os.write(terminal.fd, b"m")
            _, raw_merchant = terminal.capture(b"Event Merchant / Edit")
            assert b"\x1b[2J" not in raw_merchant, "floating Merchant cleared its parent"
            text_caret(raw_merchant, 40, 144, "_")
            long_party = "a" * 75 + "-tail"
            text_caret(send_raw(terminal, long_party.encode(), b"-tail"), 40, 144, "-tail")
            resize_input(terminal, "-tail", root, before_merchant)
            text_caret(send_raw(terminal, b"\x7f" * len(long_party), b"Party id:"), 40, 144, "_")
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 14, 48, 0, 0))
            _, compact_merchant = terminal.capture(b"Event Merchant / Edit")
            assert b"Target:" in probe.ANSI.sub(b"", compact_merchant)
            assert probe.digest(root) == before_merchant, "Merchant resize wrote authority"
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            terminal.capture(b"Event Merchant / Edit")
            no_text_caret(send_raw(terminal, b"\t\r", b"Event Merchant / Preview"))
            assert probe.digest(root) == before_merchant, "Merchant preview published"
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 9, 32, 0, 0))
            terminal.capture(b"Event Merchant / Preview")
            refused_merchant = send_raw(terminal, b"\r", b"Enlarge terminal")
            no_text_caret(refused_merchant)
            assert b"Enlarge terminal" in probe.ANSI.sub(b"", refused_merchant)
            assert probe.digest(root) == before_merchant, "hidden Merchant preview wrote"
            no_text_caret(send_raw(terminal, b"e", b"Event Merchant / Edit"))
            text_caret(send_raw(terminal, b"\t", b"Party id:"), 9, 32, "_")
            no_text_caret(send_raw(terminal, b"\t\r", b"Event Merchant / Preview"))
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            _, readable_merchant = terminal.capture(b"Event Merchant / Preview")
            assert b"Proposed:" in probe.ANSI.sub(b"", readable_merchant)
            send(terminal, b"\r", b"Published Nonmerchant")
            send(terminal, b"m", b"Merchant already classified: Nonmerchant")
            # Floating reversal preserves the selected parent; resizes cannot write.
            before_reversal = probe.digest(root)
            os.write(terminal.fd, b"r")
            _, raw_reverse = terminal.capture(b"Actual / Reverse / Date")
            assert b"\x1b[2J" not in raw_reverse, "floating reversal cleared its parent"
            reverse_edit = probe.ANSI.sub(b"", raw_reverse)
            assert b"Reversal date:" in reverse_edit and b"Target date:" in reverse_edit
            text_caret(raw_reverse, 40, 144, datetime.date.today().isoformat())
            resize_input(terminal, datetime.date.today().isoformat(), root, before_reversal)
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 14, 48, 0, 0))
            _, compact_reverse = terminal.capture(b"Actual / Reverse / Date")
            assert b"Reversal date:" in probe.ANSI.sub(b"", compact_reverse)
            assert probe.digest(root) == before_reversal, "compact reversal resize wrote data"
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            _, roomy_reverse = terminal.capture(b"Actual / Reverse / Date")
            assert b"Reversal date:" in probe.ANSI.sub(b"", roomy_reverse)
            raw_reverse_preview = send_raw(terminal, b"\r", b"Actual / Reverse / Preview")
            no_text_caret(raw_reverse_preview)
            reverse_preview = probe.ANSI.sub(b"", raw_reverse_preview)
            # The renderer sends only changed rows on transition.
            assert b"Inverse postings" in reverse_preview and b"Publish reversal" in reverse_preview, (
                reverse_preview[-1600:])
            assert probe.digest(root) == before_reversal
            assert "REVERSAL-OF" not in sections(root)["Actual"]
            # A hidden inverse preview cannot publish and survives enlargement.
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 9, 32, 0, 0))
            terminal.capture(b"Actual / Reverse / Preview")
            refused_reverse = send_raw(terminal, b"\r", b"Enlarge terminal")
            no_text_caret(refused_reverse)
            assert b"Enlarge terminal" in probe.ANSI.sub(b"", refused_reverse)
            assert probe.digest(root) == before_reversal, "hidden reversal published"
            text_caret(send_raw(terminal, b"e", b"Reversal date:"), 9, 32, datetime.date.today().isoformat())
            no_text_caret(send_raw(terminal, b"\r", b"Actual / Reverse / Preview"))
            fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ,
                        struct.pack("HHHH", 40, 144, 0, 0))
            _, restored_reverse = terminal.capture(b"Actual / Reverse / Preview")
            assert b"Inverse postings" in probe.ANSI.sub(b"", restored_reverse)
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
