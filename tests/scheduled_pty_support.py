"""Shared physical PTY mechanics for Scheduled modal regression tests.

Only process/terminal mechanics live here. Cancellation, supersede, and
completion retain their own action sequences and publication assertions.
Do not import a behavioral regression test as an ad-hoc test library.
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
import termios
import time

REPO = Path(__file__).resolve().parents[1]
EXE = REPO / ".lake/build/bin/loamTui"
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def digest(root: Path) -> dict[str, str]:
    """Byte-identical household authority and sidecar check on synthetic data."""
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


class Terminal:
    """Controlling PTY, bounded capture, live resize, and reliable cleanup."""

    def __init__(self, root: Path, *, columns: int = 112) -> None:
        self.master, slave = pty.openpty()
        self.rows, self.columns = 40, columns
        fcntl.ioctl(slave, termios.TIOCSWINSZ,
                    struct.pack("HHHH", self.rows, self.columns, 0, 0))

        def setup() -> None:
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        try:
            self.process = subprocess.Popen(
                [str(EXE), str(root)], cwd=REPO,
                stdin=slave, stdout=slave, stderr=slave,
                env=dict(os.environ, TERM="xterm-256color",
                         LOAM_DATA_DIR=str(root)),
                preexec_fn=setup,
            )
        finally:
            os.close(slave)
        self.capture(b"LOAM Home")

    def capture(self, expected: bytes | None = None) -> bytes:
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
                break

        assert expected is None or expected in ANSI.sub(b"", output), (expected, output)
        assert output, "terminal produced no output"
        # Replacement previously checked every capture; cancellation checked
        # resizes. Keep the stronger invariant for both consumers.
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
        assert all(1 <= int(r) <= self.rows and 1 <= int(c) <= self.columns
                   for r, c in positions), positions
        return output

    def send(self, keys: bytes, expected: bytes | None = None) -> bytes:
        os.write(self.master, keys)
        return self.capture(expected)

    def resize(self, rows: int, cols: int, expected: bytes | None = None) -> bytes:
        self.rows, self.columns = rows, cols
        fcntl.ioctl(self.master, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, cols, 0, 0))
        output = self.capture(expected)
        self.bounded(output)
        return output

    def bounded(self, output: bytes) -> None:
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
        if not positions and self.rows == 1:
            assert b"\x1b[2J" in output, output
            return
        assert positions, output
        assert all(1 <= int(r) <= self.rows and 1 <= int(c) <= self.columns
                   for r, c in positions), positions
        assert b"\n" not in output and b"\r" not in output

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.master)
