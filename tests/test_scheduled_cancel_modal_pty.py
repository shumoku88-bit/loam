#!/usr/bin/env python3
"""Adaptive Scheduled-cancellation modal: real PTY, isolated synthetic household."""
from __future__ import annotations

import fcntl
import hashlib
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import tempfile
import termios
import time

REPO = Path(__file__).resolve().parents[1]
EXE = REPO / ".lake/build/bin/loamTui"
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def digest(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


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


class Terminal:
    def __init__(self, root):
        self.master, slave = pty.openpty()
        self.rows, self.columns = 40, 112
        fcntl.ioctl(slave, termios.TIOCSWINSZ,
                    struct.pack("HHHH", self.rows, self.columns, 0, 0))

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([str(EXE), str(root)],
                                        stdin=slave, stdout=slave, stderr=slave,
                                        cwd=REPO,
                                        env=dict(os.environ, TERM="xterm-256color",
                                                 LOAM_DATA_DIR=str(root)),
                                        preexec_fn=setup)
        os.close(slave)
        self.capture(b"LOAM Home")

    def capture(self, expected=None):
        output = b""
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], .15)[0]:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
            elif output and (expected is None or expected in ANSI.sub(b"", output)):
                return output
        assert expected is None or expected in ANSI.sub(b"", output), (expected, output)
        assert output, "terminal produced no output"
        return output

    def send(self, keys, expected=None):
        os.write(self.master, keys)
        return self.capture(expected)

    def resize(self, rows, cols, expected=None):
        self.rows, self.columns = rows, cols
        fcntl.ioctl(self.master, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, cols, 0, 0))
        output = self.capture(expected)
        self.bounded(output)
        return output

    def bounded(self, output):
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
        if not positions and self.rows == 1:
            assert b"\x1b[2J" in output, output
            return
        assert positions, output
        assert all(1 <= int(r) <= self.rows and 1 <= int(c) <= self.columns
                   for r, c in positions), positions
        assert b"\n" not in output and b"\r" not in output

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.master)


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
