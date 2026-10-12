#!/usr/bin/env python3
"""Real-terminal Scheduled supersede input contract on an isolated household.

Cover shared floating/compact modal placement, both launchers, Locus picker,
edit/preview resize, short-viewport publication refusal, and draft retention
with byte-identical no-write, then accept and verify an exact canonical successor.
"""
from __future__ import annotations

from pathlib import Path
import os
import select
import subprocess
import tempfile
import time

from scheduled_pty_support import ANSI, REPO, Terminal, digest


def household_sections(root: Path) -> dict[str, str]:
    """Compare retained image sections; an accepted replacement may update routing."""
    header, rest = (root / "household.loam").read_text().split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2", header
    sections = {}
    while rest:
        frame, rest = rest.split("\n", 1)
        tag, name, count = frame.split("\t")
        assert tag == "SECTION", frame
        sections[name], rest = rest[:int(count)], rest[int(count):]
    return sections


def resize_with_rebuild(terminal: Terminal, rows: int, cols: int,
                        expected: bytes) -> bytes:
    """Replacement requires a full parent rebuild after every live resize."""
    output = terminal.resize(rows, cols, expected)
    assert b"\x1b[2J" in output, "resize did not rebuild the replacement frame"
    return output


def child_cpu_seconds(pid: int) -> float | None:
    """Measure the native child on Linux CI; leave macOS functional checks intact."""
    stat = Path(f"/proc/{pid}/stat")
    if not stat.exists():
        return None
    fields = stat.read_text().rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")


def main():
    with tempfile.TemporaryDirectory(prefix="loam-replacement-pty-") as temporary:
        root = Path(temporary) / "household"
        subprocess.run(
            ["lake", "env", "lean", "--run",
             "Loam/Tests/ScheduledBatchReplacement.lean", "setup", str(root)],
            cwd=REPO, check=True,
        )
        original = digest(root)
        terminal = Terminal(root, columns=120)
        try:
            terminal.send(b"s", b"Scheduled Series Calendar")
            terminal.send(b"v", b"Scheduled / Months")
            terminal.send(b"v", b"Scheduled / List")
            editor = terminal.send(b"r", b"Scheduled / Supersede / Edit replacement")
            assert b"Scheduled / Supersede" in ANSI.sub(b"", editor)
            assert b"\x1b[2J" not in editor, "floating editor unexpectedly cleared its parent"
            assert b"Source: first" in ANSI.sub(b"", editor)
            assert b"Posting 1: bank" in ANSI.sub(b"", editor)
            assert b"Replacement due" in ANSI.sub(b"", editor)
            assert digest(root) == original, "opening replacement mutated authority"

            # Observe idle child CPU on the CI runner, excluding Python/PTY
            # overhead. Quiet state must not paint, mutate authority or exit.
            cpu_start = child_cpu_seconds(terminal.process.pid)
            idle_start = time.monotonic()
            time.sleep(1.5)
            idle_elapsed = time.monotonic() - idle_start
            cpu_end = child_cpu_seconds(terminal.process.pid)
            assert not select.select([terminal.master], [], [], 0)[0], (
                "idle replacement emitted unexpected terminal output")
            assert digest(root) == original, "idle replacement modified authority"
            if cpu_start is not None and cpu_end is not None:
                print(f"CI-TUI-IDLE surface=scheduled-replacement "
                      f"wall_seconds={idle_elapsed:.3f} "
                      f"child_cpu_seconds={cpu_end - cpu_start:.3f}", flush=True)

            # Tab selects the first Locus. A partial token displays a candidate.
            terminal.send(b"\t", b"Posting 1")
            terminal.send(b"\x7f" * 4 + b"wi", b"Candidate: wifi")
            changed = terminal.send(b"\x1b[C", b"Posting 1: wifi")
            assert b"Posting 1: wifi" in ANSI.sub(b"", changed), (
                "Right accepted the candidate internally but not in the visible field",
                changed,
            )
            assert digest(root) == original, "admitting a Locus published household data"

            # Right commits without changing focus. Tab advances focus to the
            # amount field, and Backspace must edit the amount, not the Locus.
            terminal.send(b"\t", b"jpy")
            amended = terminal.send(b"\x7f", b"-480")
            assert b"-480" in ANSI.sub(b"", amended), amended
            assert digest(root) == original, "local amount edit published"

            # Restore the balanced seed, then preview without publication.
            terminal.send(b"0", b"-4800")
            terminal.send(b"\t" * 5, b"[Preview]")
            preview = terminal.send(b"\r", b"Scheduled / Supersede / Preview")
            assert b"Source: first" in ANSI.sub(b"", preview)
            assert b"4800 jpy" in ANSI.sub(b"", preview)

            # Preview reflows at current terminal bounds. Short evidence
            # prevents Publish until the same editor is enlarged.
            small = resize_with_rebuild(terminal, 9, 32, b"Scheduled / Supersede / Preview")
            assert b"[Publish]" in ANSI.sub(b"", small), small
            refused = terminal.send(b"\r", b"Enlarge terminal")
            assert b"Enlarge terminal" in ANSI.sub(b"", refused), refused
            assert digest(root) == original, "short preview published a replacement"

            big = resize_with_rebuild(terminal, 24, 80, b"Scheduled / Supersede / Preview")
            assert b"Source: first" in ANSI.sub(b"", big), big
            restored = resize_with_rebuild(terminal, 40, 120, b"Scheduled / Supersede / Preview")
            assert b"Source: first" in ANSI.sub(b"", restored), restored
            terminal.send(b"\t", b"[Edit]")
            editing = terminal.send(b"\r", b"Scheduled / Supersede / Edit replacement")
            assert b"Posting 1: wifi" in ANSI.sub(b"", editing), editing
            assert digest(root) == original, "preview/edit return published"

            terminal.send(b"\x1b", b"Scheduled / List")
            assert digest(root) == original, "Esc from replacement published or modified bytes"
            terminal.send(b"q", b"LOAM Home")

            # The second launcher retains the Selected Day parent and target.
            terminal.send(b"/", b"Jump to date")
            terminal.send(b"2026-12-08\r", b"Focus: 2026-12-08")
            terminal.send(b"\r", b"Household Day Workspace")
            terminal.send(b"l", b"Scheduled")
            selected = terminal.send(b"r", b"Scheduled / Supersede / Edit replacement")
            assert b"Source: second" in ANSI.sub(b"", selected), selected
            assert b"\x1b[2J" not in selected, "Selected Day modal cleared its parent"
            terminal.send(b"\x1b", b"Household Day Workspace")
            assert digest(root) == original, "Selected Day replacement cancellation wrote"
            terminal.send(b"q", b"LOAM Home")

            # The two cancel/refusal paths above were byte-identical. Now accept
            # a visibly reviewed replacement from the Scheduled List launcher.
            before_sections = household_sections(root)
            terminal.send(b"s", b"Scheduled Series Calendar")
            terminal.send(b"v", b"Scheduled / Months")
            terminal.send(b"v", b"Scheduled / List")
            reopened = terminal.send(b"r", b"Scheduled / Supersede / Edit replacement")
            assert b"Source: first" in ANSI.sub(b"", reopened), reopened

            # Due 2026-11-08 -> 2026-11-09. Two exact signed postings:
            # -4800 -> -4900 bank and +4800 -> +4900 wifi.
            terminal.send(b"\x7f9")
            terminal.send(b"\t")       # Due -> bank Locus
            terminal.send(b"\r")       # Enter accepts exact bank and advances to amount
            terminal.send(b"\x7f" * 3 + b"900")
            terminal.send(b"\t" * 2)  # bank amount -> wifi Locus -> wifi amount
            terminal.send(b"\x7f" * 3 + b"900")
            entered = resize_with_rebuild(
                terminal, 40, 112, b"Scheduled / Supersede / Edit replacement")
            visible = ANSI.sub(b"", entered)
            assert b"Replacement due: 2026-11-09" in visible, entered
            assert b"jpy: -4900" in visible and b"jpy: 4900" in visible, entered
            assert digest(root) == original, "local replacement draft published before Preview"

            terminal.send(b"\t" * 3, b"[Preview]")
            preview = terminal.send(b"\r", b"Scheduled / Supersede / Preview")
            clean = ANSI.sub(b"", preview)
            assert b"Source: first" in clean and b"Replacement due: 2026-11-09" in clean
            assert b"bank  -4900 jpy" in clean and b"wifi  4900 jpy" in clean, preview
            assert b"[Publish]" in clean, preview
            assert digest(root) == original, "review alone published a replacement"

            published = terminal.send(b"\r", b"Superseded first.")
            assert b"Superseded first." in ANSI.sub(b"", published), published
            terminal.send(b"q", b"LOAM Home")
            after_sections = household_sections(root)
            assert after_sections.keys() == before_sections.keys()
            assert after_sections["Scheduled"] != before_sections["Scheduled"], (
                "accepted replacement did not change Scheduled authority")
            for name, body in before_sections.items():
                if name not in ("Scheduled", "ScheduledRouting"):
                    assert after_sections[name] == body, (
                        "accepted replacement changed unrelated section", name)
        finally:
            terminal.close()
        # Read the disk independently of the TUI process. Typed review checks
        # source retention, exact successor/date/postings and inherited routing.
        subprocess.run(
            ["lake", "env", "lean", "--run",
             "Loam/Tests/ScheduledBatchReplacement.lean", "verify-pty", str(root)],
            cwd=REPO, check=True,
        )
    print("Scheduled replacement PTY: two launchers, floating/compact, refusal, no-write and exact accepted publication passed.")


if __name__ == "__main__":
    main()
