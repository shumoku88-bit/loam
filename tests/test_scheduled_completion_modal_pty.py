#!/usr/bin/env python3
"""Scheduled completion's two live parents, committed UTF-8 and caret geometry.

Only cancellation/refusal is exercised: canonical completion success and its
independent continuation process remain covered by Lean publication tests.
A PTY cannot qualify real OS Japanese IME preedit.
"""
from __future__ import annotations

from pathlib import Path
import select
import subprocess
import tempfile

from scheduled_pty_support import ANSI, REPO, Terminal, digest, text_caret, no_text_caret


def clean(raw: bytes) -> bytes:
    return ANSI.sub(b"", raw)


def exercise_description(t: Terminal, root: Path, original: dict[str, str]) -> None:
    description = t.send(b"\t")
    text_caret(description, t.rows, t.columns, "_")
    committed = t.send("食事".encode(), "食事".encode())
    text_caret(committed, t.rows, t.columns, "食事")
    # Existing bracketed-paste semantics keep the first line and do not publish.
    pasted = t.send(b"\x1b[200~" + ("日本語" * 35 + "末尾\nignored").encode() + b"\x1b[201~",
                    "末尾".encode())
    text_caret(pasted, t.rows, t.columns, "末尾")
    assert b"ignored" not in clean(pasted), pasted
    edited = t.send(b"\x7f" + "端".encode(), "末端".encode())
    text_caret(edited, t.rows, t.columns, "末端")
    for rows, columns in ((9, 32), (14, 48), (24, 80), (40, 120)):
        resized = t.resize(rows, columns, "末端".encode())
        text_caret(resized, rows, columns, "末端")
        assert not select.select([t.master], [], [], .35)[0], "idle completion emitted output"
        assert digest(root) == original, "description editing/resize published authority"
    measure = t.send(b"\t")
    text_caret(measure, t.rows, t.columns, "jpy")
    # Measure -> both posting pairs -> Preview action; actions are not text.
    action = t.send(b"\t" * 5, b"[Preview]")
    no_text_caret(action)
    review = t.send(b"\r", b"[Publish]")
    no_text_caret(review)
    assert b"Actual effects" in clean(review) and b"Plan reference" in clean(review), review
    t.send(b"\t", b"[Edit]")
    returned = t.send(b"\r", b"Actual draft")
    no_text_caret(returned)  # Edit retains the action focus, not an inferred input.
    description = t.send(b"\x1b[Z" * 6, "末端".encode())
    text_caret(description, t.rows, t.columns, "末端")
    t.send(b"\t" * 6, b"[Preview]")
    no_text_caret(t.send(b"\r", b"[Publish]"))
    shrunk = t.resize(9, 32, b"Scheduled / Complete / Actual")
    no_text_caret(shrunk)
    refused = t.send(b"\r", b"Enlarge terminal")
    no_text_caret(refused)
    assert digest(root) == original, "short review published completion"
    restored = t.resize(40, 120, b"Scheduled / Complete / Actual")
    no_text_caret(restored)
    assert b"Plan reference" in clean(restored), restored


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-scheduled-complete-float-") as tmp:
        root = Path(tmp) / "household"
        subprocess.run(
            ["lake", "env", "lean", "--run",
             "Loam/Tests/ScheduledBatchReplacement.lean", "setup", str(root)],
            cwd=REPO, check=True,
        )
        original = digest(root)
        t = Terminal(root, columns=120)
        try:
            t.send(b"s", b"Scheduled Series Calendar")
            t.send(b"v", b"Scheduled / Months")
            t.send(b"v", b"Scheduled / List")
            opened = t.send(b"c", b"Scheduled / Complete / Actual")
            assert b"Plan ID: first" in clean(opened), opened
            assert b"\x1b[2J" not in opened, "completion unexpectedly erased its parent"
            text_caret(opened, t.rows, t.columns)
            exercise_description(t, root, original)
            no_text_caret(t.send(b"\x1b", b"Scheduled / List"))
            assert digest(root) == original, "List completion cancellation wrote authority"
            t.send(b"q", b"LOAM Home")

            t.send(b"/", b"Jump to date")
            t.send(b"2026-12-08\r", b"Focus: 2026-12-08")
            t.send(b"\r", b"Household Day Workspace")
            t.send(b"l", b"Scheduled")
            day = t.send(b"c", b"Scheduled / Complete / Actual")
            assert b"Plan ID: second" in clean(day), day
            assert b"\x1b[2J" not in day, "Selected Day completion erased its parent"
            text_caret(day, t.rows, t.columns)
            exercise_description(t, root, original)
            no_text_caret(t.send(b"\x1b", b"Household Day Workspace"))
            assert digest(root) == original, "Selected Day completion cancellation wrote authority"
            t.send(b"q", b"LOAM Home")
        finally:
            t.close()
    print("Scheduled completion PTY: both parents, exact field caret/CJK/paste/Backspace, four sizes, idle, review-return/refusal and no-write cancellation passed.")


if __name__ == "__main__":
    main()
