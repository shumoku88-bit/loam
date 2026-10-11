#!/usr/bin/env python3
"""Synthetic real-PTY qualification for floating Scheduled completion.

Only Esc/refusal is exercised here: completion success creates Actual evidence
and an independent next-plan prompt, so write success is tested separately by
the existing Lean Scheduled terminal publication tests.
"""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile

from test_scheduled_cancel_modal_pty import Terminal, ANSI, digest

REPO = Path(__file__).resolve().parents[1]


def clean(raw: bytes) -> bytes:
    return ANSI.sub(b"", raw)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-scheduled-complete-float-") as tmp:
        root = Path(tmp) / "household"
        subprocess.run(
            ["lake", "env", "lean", "--run",
             "Loam/Tests/ScheduledBatchReplacement.lean", "setup", str(root)],
            cwd=REPO, check=True,
        )
        original = digest(root)
        t = Terminal(root)
        try:
            t.send(b"s", b"Scheduled Series Calendar")
            t.send(b"v", b"Scheduled / Months")
            t.send(b"v", b"Scheduled / List")
            opened = t.send(b"c", b"Scheduled / Complete / Actual")
            assert b"Plan ID: first" in clean(opened), opened
            assert b"\x1b[2J" not in opened, "completion unexpectedly erased its parent"
            assert digest(root) == original, "opening completion modified authority"

            # Shrink while editing and recover the exact selected Scheduled.
            compact = t.resize(14, 48, b"Scheduled / Complete / Actual")
            assert b"Actual draft" in clean(compact), compact
            expanded = t.resize(40, 120, b"Scheduled / Complete / Actual")
            assert b"Plan ID: first" in clean(expanded), expanded
            t.send(b"\t" * 7)
            review = t.send(b"\r", b"[Publish]")
            assert b"Actual effects" in clean(review), review
            assert b"Plan reference" in clean(review), review

            # A short review may not emit a durable completion, even when the
            # keyboard selection is Publish.
            shrunk = t.resize(9, 32, b"Scheduled / Complete / Actual")
            assert b"Publish" in clean(shrunk), shrunk
            refused = t.send(b"\r", b"Enlarge terminal")
            assert b"Enlarge terminal" in clean(refused), refused
            assert digest(root) == original, "short review published completion"
            again = t.resize(40, 120, b"Scheduled / Complete / Actual")
            assert b"Plan reference" in clean(again), again
            t.send(b"\x1b", b"Scheduled / List")
            assert digest(root) == original, "Esc after refused completion wrote authority"
            t.send(b"q", b"LOAM Home")

            # Same editor, different parent: selected-day Scheduled record.
            t.send(b"/", b"Jump to date")
            t.send(b"2026-12-08\r", b"Focus: 2026-12-08")
            t.send(b"\r", b"Household Day Workspace")
            t.send(b"l", b"Scheduled")
            day = t.send(b"c", b"Scheduled / Complete / Actual")
            assert b"Plan ID: second" in clean(day), day
            assert b"\x1b[2J" not in day, "Selected Day completion erased its parent"
            t.send(b"\x1b", b"Household Day Workspace")
            assert digest(root) == original, "Selected Day completion Esc published"
            t.send(b"q", b"LOAM Home")
        finally:
            t.close()
    print("Scheduled completion floating PTY: both parents, resize, hidden Publish guard, Esc no-write passed.")


if __name__ == "__main__":
    main()
