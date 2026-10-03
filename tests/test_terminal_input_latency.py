#!/usr/bin/env python3
"""Real tty regression for short reads (buffer-injection tests miss stdio delays).

Run after lake build terminalProbe. No household data is read or written.
"""
import os
from pathlib import Path
import pty
import select
import statistics
import subprocess
import termios
import time

ROOT = Path(__file__).resolve().parent.parent
master, slave = pty.openpty()
attrs = termios.tcgetattr(slave)
attrs[3] &= ~(termios.ICANON | termios.ECHO)
attrs[6][termios.VMIN] = 0
attrs[6][termios.VTIME] = 1  # Same short-read timeout as production Terminal.enter.
termios.tcsetattr(slave, termios.TCSANOW, attrs)
process = subprocess.Popen(
    [str(ROOT / ".lake/build/bin/terminalProbe"), "keys"],
    cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
)
os.close(slave)
pending = b""


def read_line(timeout=20):
    global pending
    deadline = time.monotonic() + timeout
    while b"\n" not in pending:
        remaining = deadline - time.monotonic()
        assert remaining > 0 and select.select([master], [], [], remaining)[0], pending
        pending += os.read(master, 4096)
    line, pending = pending.split(b"\n", 1)
    return line.strip()


try:
    assert read_line() == b"ready"
    cases = [
        (b"l", b"Key.input 'l'"),
        (b"\x1b[B", b"Key.down"),
        ("日".encode(), "Key.input '日'".encode()),
        (b"\x1b[<65;10;10M", b"Key.down"),
        (b"\x1b[200~hello\x1b[201~", b'Key.paste "hello"'),
    ]
    samples = []
    for payload, expected in cases:
        start = time.monotonic()
        os.write(master, payload)
        line = read_line()
        elapsed = time.monotonic() - start
        assert expected in line, (expected, line)
        samples.append(elapsed)
        print(f"{payload!r}: {elapsed * 1000:.1f}ms")
    # A systematic VTIME fill stall affects all short reads. Use the median to
    # avoid treating an isolated CI scheduling delay as an input regression.
    assert statistics.median(samples) < 0.080, f"short-read median: {samples!r}"
    assert process.wait(timeout=5) == 0
finally:
    if process.poll() is None:
        process.kill()
        process.wait()
    os.close(master)
