#!/usr/bin/env python3
"""Real-terminal Scheduled supersede input contract on an isolated household.

Cover the admitted Locus picker, edit/preview resize, short-viewport
publication refusal, and draft retention with byte-identical no-write.
Accepted publication is a separate qualification item under #1902.
"""
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


def digest(root: Path) -> dict[str, str]:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


class Terminal:
    def __init__(self, root: Path):
        self.master, slave = pty.openpty()
        self.rows, self.cols = 40, 120
        fcntl.ioctl(slave, termios.TIOCSWINSZ,
                    struct.pack("HHHH", self.rows, self.cols, 0, 0))

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        self.proc = subprocess.Popen(
            [str(EXE), str(root)], cwd=REPO,
            stdin=slave, stdout=slave, stderr=slave,
            env=dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root)),
            preexec_fn=setup,
        )
        os.close(slave)
        self.capture(b"LOAM Home")

    def capture(self, expected: bytes | None = None) -> bytes:
        output = b""
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], .15)[0]:
                try:
                    part = os.read(self.master, 65536)
                except OSError:
                    break
                if not part:
                    break
                output += part
            elif output and (expected is None or expected in ANSI.sub(b"", output)):
                break
        if expected is not None:
            assert expected in ANSI.sub(b"", output), (expected, output)
        assert output, "no terminal output"
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
        assert all(1 <= int(r) <= self.rows and 1 <= int(c) <= self.cols
                   for r, c in positions), positions
        return output

    def send(self, data: bytes, expected: bytes | None = None) -> bytes:
        os.write(self.master, data)
        return self.capture(expected)

    def resize(self, rows: int, cols: int, expected: bytes) -> bytes:
        self.rows, self.cols = rows, cols
        fcntl.ioctl(self.master, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, cols, 0, 0))
        output = self.capture(expected)
        assert b"\x1b[2J" in output, "resize did not rebuild the replacement frame"
        return output

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        os.close(self.master)


def main():
    with tempfile.TemporaryDirectory(prefix="loam-replacement-pty-") as temporary:
        root = Path(temporary) / "household"
        subprocess.run(
            ["lake", "env", "lean", "--run",
             "Loam/Tests/ScheduledBatchReplacement.lean", "setup", str(root)],
            cwd=REPO, check=True,
        )
        original = digest(root)
        terminal = Terminal(root)
        try:
            terminal.send(b"s", b"Scheduled Series Calendar")
            terminal.send(b"v", b"Scheduled / Months")
            terminal.send(b"v", b"Scheduled / List")
            editor = terminal.send(b"r", b"Scheduled / Supersede / Edit replacement")
            assert b"Source: first" in ANSI.sub(b"", editor)
            assert b"Posting 1: bank" in ANSI.sub(b"", editor)
            assert b"Replacement due" in ANSI.sub(b"", editor)
            assert digest(root) == original, "opening replacement mutated authority"

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
            small = terminal.resize(9, 32, b"Scheduled / Supersede / Preview")
            assert b"[Publish]" in ANSI.sub(b"", small), small
            refused = terminal.send(b"\r", b"Enlarge terminal")
            assert b"Enlarge terminal" in ANSI.sub(b"", refused), refused
            assert digest(root) == original, "short preview published a replacement"

            big = terminal.resize(24, 80, b"Scheduled / Supersede / Preview")
            assert b"Source: first" in ANSI.sub(b"", big), big
            terminal.send(b"\t", b"[Edit]")
            editing = terminal.send(b"\r", b"Scheduled / Supersede / Edit replacement")
            assert b"Posting 1: wifi" in ANSI.sub(b"", editing), editing
            assert digest(root) == original, "preview/edit return published"

            terminal.send(b"\x1b", b"Scheduled / List")
            assert digest(root) == original, "Esc from replacement published or modified bytes"
            terminal.send(b"q", b"LOAM Home")
        finally:
            terminal.close()
    print("Scheduled replacement PTY: Locus/Right/Tab, resized preview refusal, draft recovery, Esc and no-write passed.")


if __name__ == "__main__":
    main()
