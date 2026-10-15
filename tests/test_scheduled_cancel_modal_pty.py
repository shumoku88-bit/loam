#!/usr/bin/env python3
"""Adaptive Scheduled-cancellation modal: real PTY, isolated synthetic household."""
from __future__ import annotations

import os
import subprocess
import tempfile
import time
from pathlib import Path

from scheduled_pty_support import ANSI, REPO, Terminal, digest, text_caret, no_text_caret


def sections(root):
    header, remaining = (root / "household.loam").read_text().split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2", header
    result = {}
    while remaining:
        framing, remaining = remaining.split("\n", 1)
        tag, name, count = framing.split("\t")
        assert tag == "SECTION"
        result[name], remaining = remaining[:int(count)], remaining[int(count):]
    return result


def main():
    with tempfile.TemporaryDirectory(prefix="loam-scheduled-cancel-modal-") as temporary:
        root = Path(temporary) / "household"
        subprocess.run(["lake", "env", "lean", "--run",
                        "Loam/Tests/ScheduledBatchReplacement.lean",
                        "setup", str(root)], cwd=REPO, check=True)
        t = Terminal(root)
        try:
            original = digest(root)
            before = sections(root)
            # The Scheduled List and the Selected Day launch the same modal.
            t.send(b"s", b"Scheduled Series Calendar")
            t.send(b"v", b"Scheduled / Months")
            t.send(b"v", b"Scheduled / List")
            opened = t.send(b"x", b"Scheduled / Cancel")
            visible = ANSI.sub(b"", opened)
            assert b"Expected effects" in visible and b"Keep" in visible
            assert b"Target: first" in visible
            assert b"\x1b[2J" not in opened, "floating open unexpectedly cleared its parent"

            # Recompose the parent on resize rather than retaining a stranded rectangle.
            compact = t.resize(14, 48, b"Scheduled / Cancel")
            assert b"Expected effects" in ANSI.sub(b"", compact)
            small = t.resize(9, 32, b"Scheduled / Cancel")
            assert b"Keep" in ANSI.sub(b"", small)
            t.resize(1, 10)
            # At 10x1 there are no paintable rows; do not wait for a diff
            # between the two silent keyboard transitions.
            os.write(t.master, b"\t\r")
            time.sleep(.5)  # both keys must be interpreted while bounds are 10x1
            assert digest(root) == original, "10x1 Enter changed authority"
            restored = t.resize(40, 112, b"Scheduled / Cancel")
            assert b"Enlarge terminal" in ANSI.sub(b"", restored), "tiny Enter refusal was lost on resize"
            # A short terminal can never commit; the following Esc preserves all bytes.
            t.send(b"\x1b", b"Scheduled / List")
            assert digest(root) == original, "cancel/refusal touched the household"

            # The user explicitly chooses the destructive action after seeing the target.
            t.send(b"x", b"Scheduled / Cancel")
            t.send(b"\t")
            t.send(b"\r", b"Cancelled first.")
            after_workspace = sections(root)
            assert after_workspace["Scheduled"] != before["Scheduled"]
            for name in before:
                if name != "Scheduled":
                    assert before[name] == after_workspace[name], ("unrelated section", name)
            t.send(b"q", b"LOAM Home")

            # A different caller supplies a different parent renderer.
            t.send(b"/", b"Jump to date")
            t.send(b"2026-12-08\r", b"Focus: 2026-12-08")
            t.send(b"\r", b"Household Day Workspace")
            t.send(b"l", b"Scheduled")
            day_before = digest(root)
            day_modal = t.send(b"x", b"Scheduled / Cancel")
            assert b"Target: second" in ANSI.sub(b"", day_modal), day_modal
            t.send(b"\x1b", b"Household Day Workspace")
            assert digest(root) == day_before, "Selected Day Esc wrote household data"

            # Scheduled creation on the same Selected Day parent also floats
            # through the shared modal. Esc leaves the selected plan untouched.
            creation_modal = t.send(b"n", b"Scheduled / New / Edit")
            assert b"Scheduled / New" in ANSI.sub(b"", creation_modal)
            assert b"\x1b[2J" not in creation_modal, "Selected Day creation cleared parent"
            text_caret(creation_modal, t.rows, t.columns, "2026-12-08")
            locus = t.send(b"\t")
            text_caret(locus, t.rows, t.columns, "_")
            pasted = t.send(b"\x1b[200~" + ("語" * 35 + "末尾").encode() + b"\x1b[201~",
                            "末尾".encode())
            text_caret(pasted, t.rows, t.columns, "末尾")
            edited = t.send(b"\x7f" + "端".encode(), "末端".encode())
            text_caret(edited, t.rows, t.columns, "末端")
            for rows, columns in ((9, 32), (14, 48), (24, 80), (40, 120)):
                resized = t.resize(rows, columns, "末端".encode())
                text_caret(resized, rows, columns, "末端")
            action = t.send(b"\t" * 4, b"[Add")
            no_text_caret(action)
            t.send(b"\x1b", b"Household Day Workspace")
            assert digest(root) == day_before, "Selected Day Scheduled creation Esc wrote data"

            t.send(b"x", b"Scheduled / Cancel")
            t.send(b"\t")
            t.send(b"\r", b"Cancelled second.")
            after_day = sections(root)
            for name in before:
                if name != "Scheduled":
                    assert before[name] == after_day[name], ("unrelated section", name)
            assert after_day["Scheduled"] != after_workspace["Scheduled"]
            t.send(b"q", b"LOAM Home")
        finally:
            t.close()
    print("Scheduled cancellation PTY: floating/compact, resize, Keep/Esc/refusal, two launchers and exact publication passed.")


if __name__ == "__main__":
    main()
