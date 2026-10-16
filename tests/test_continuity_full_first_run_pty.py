#!/usr/bin/env python3
"""Real PTY first-run household daily-life acceptance. NO production household.

This exercises true loamTui keystrokes and canonical persistence. It complements
the synthetic publisher-level FreshHouseholdDailyLife regression; no APIs are
called to set up accounts, observe balances, create plans, or record purchases.
"""
import datetime as dt
import fcntl
import hashlib
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time

REPO = Path(__file__).resolve().parent.parent
EXE = Path(sys.argv[1] if len(sys.argv) > 1 else REPO / ".lake/build/bin/loamTui").resolve()
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")
ROWS, COLS = 45, 150


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Terminal:
    def __init__(self, root):
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        def controlling():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        self.process = subprocess.Popen(
            [str(EXE), str(root)], stdin=slave, stdout=slave, stderr=slave,
            preexec_fn=controlling, env=dict(os.environ, TERM="xterm-256color"),
        )
        os.close(slave)

    def capture(self, expected, timeout=25):
        seen = b""
        until = time.monotonic() + timeout
        target = expected.encode() if isinstance(expected, str) else expected
        while time.monotonic() < until:
            if select.select([self.master], [], [], 0.08)[0]:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                seen += chunk
                if target in ANSI.sub(b"", seen):
                    return ANSI.sub(b"", seen)
            elif target in ANSI.sub(b"", seen):
                return ANSI.sub(b"", seen)
        raise AssertionError((f"did not show {target!r}", ANSI.sub(b"", seen)[-3600:]))

    def send(self, keys, expected):
        if isinstance(keys, str):
            keys = keys.encode()
        os.write(self.master, keys)
        return self.capture(expected)

    def setup(self, index, expected):
        self.send(b" ", b"Home / Commands")
        self.send(b"jjjj\r", b"Commands / Household setup")
        self.send(b"j" * index + b"\r", expected)

    def home(self, keys, expected=b"[q] quit"):
        return self.send(keys, expected)

    def quit(self):
        os.write(self.master, b"q")
        assert self.process.wait(timeout=12) == 0, "TUI did not quit ordinarily"

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=8)
        os.close(self.master)


with tempfile.TemporaryDirectory(prefix="loam-real-first-run-pty-") as temp:
    root = Path(temp) / "independent"
    ledger = root / "household.loam"
    now = dt.date.today()
    due = (now + dt.timedelta(days=30)).isoformat()
    beginning = (now - dt.timedelta(days=1)).isoformat()
    ending = (now + dt.timedelta(days=60)).isoformat()
    terminal = Terminal(root)
    try:
        terminal.capture(b"Start a household")
        assert not root.exists(), "first-run editor created directory before consent"
        terminal.send(b"\r", b"Create an INDEPENDENT household?")
        assert not root.exists(), "first Enter wrote a household before review"
        terminal.send(b"\r", b"[q] quit")
        assert ledger.is_file(), "second Enter did not create qualified household"
        initial = sha(ledger)
        terminal.send(b"g", b"LOAM Home")

        # Home -> Space -> Household setup -> Manage Loci. No backend setup APIs.
        for token in ("bank", "food"):
            terminal.setup(0, b"Locus Administration / Admit New Identity")
            terminal.send(token + "\r", b"Locus Administration / Preview")
            assert sha(ledger) == initial if token == "bank" else True, (
                "Locus preview wrote to canonical household")
            terminal.send(b"\r", "Admitted Locus " + token)
        admitted = sha(ledger)
        assert admitted != initial, "real TUI Locus admission left canonical root unchanged"

        # Optional display label through the fresh household's ordinary picker.
        terminal.setup(1, b"Household setup / Friendly names")
        terminal.send(b"\r", b"Household setup / Edit display name")
        terminal.send("ゆうちょ", "ゆうちょ")
        terminal.send(b"\r", b"Review / Friendly display name")
        before_label = sha(ledger)
        terminal.send(b"\r", b"Display name saved for bank.")
        assert sha(ledger) == before_label, "friendly label rewrote canonical bytes"
        assert "ゆうちょ" in (root / "config/locus-catalog.tsv").read_text()

        # Observe one exact present balance. 'unknown' is never interpreted as zero.
        terminal.setup(2, b"Current Quantity / Observe")
        terminal.send(b"bank\t\t10000\r", b"1. bank")
        terminal.send(b"\t\t\t\t\r", b"Current Quantity / Preview")
        observed_preview = sha(ledger)
        terminal.send(b"\r", b"Published current quantity anchor")
        assert sha(ledger) != observed_preview, "observation confirmation did not publish"

        # Display-only visibility is different from spendable Daily Pace funding.
        terminal.setup(5, b"Balances / Visible accounts")
        terminal.send(b" \r", b"Review: these balances appear")
        before_view = sha(ledger)
        terminal.send(b"\r", b"Visible Balance accounts saved")
        assert sha(ledger) == before_view
        assert (root / "config/balance-view.tsv").is_file()
        terminal.setup(3, b"Daily Pace / Spendable pool")
        terminal.send(b" \r", b"Review: these balances fund")
        terminal.send(b"\r", b"Daily Pace pool saved")
        assert (root / "config/daily-pace.tsv").read_text() == "bank\tjpy\n"

        # Supply only explicit real dates, not a guessed recurrence.
        terminal.setup(4, b"Daily Pace / Cycle boundaries")
        terminal.send(b"\t" + f"{beginning}, {ending}".encode() + b"\r",
                      b"Daily Pace / Review explicit cycle boundaries")
        before_dates = sha(ledger)
        terminal.send(b"\r", b"Explicit Daily Pace cycle boundaries saved")
        assert sha(ledger) == before_dates
        assert beginning in (root / "config/boundary-presets.tsv").read_text()

        # Actual purchase: signed postings, explicit human confirmation.
        terminal.send(b"r", b"Record / Edit")
        terminal.send(b"PTY daily purchase\t\tbank\t-500\tfood\t500\r",
                      b"Record / Preview")
        purchase_preview = sha(ledger)
        terminal.send(b"\r", b"Recorded")
        assert sha(ledger) != purchase_preview, "actual purchase not recorded"

        # A future unpaid Scheduled occurrence is a separate explicit TUI write.
        terminal.send(b"s", b"Scheduled")
        terminal.send(b"n", b"Scheduled / New")
        terminal.send(b"\x7f" * 10 + due.encode() + b"\tbank\t-1500\tfood\t1500\r",
                      b"Scheduled / Preview")
        scheduled_preview = sha(ledger)
        terminal.send(b"\r", b"Expected pace")
        assert sha(ledger) != scheduled_preview, "future Scheduled not published"
        terminal.send(b"\x1b", b"Scheduled")
        terminal.send(b"q", b"[q] quit")
        finished = sha(ledger)
        terminal.quit()
    finally:
        terminal.close()

    # A second independent OS process must admit the exact same root; all
    # read-only balance and pace views must leave canonical bytes unchanged.
    reopened = Terminal(root)
    try:
        reopened.capture(b"[q] quit")
        reopened.send(b"g", b"LOAM Home")
        reopened.send(b"b", b"Balances")
        reopened.send(b"q", b"[q] quit")
        reopened.send(b"d", b"Daily Pace")
        reopened.send(b"q", b"[q] quit")
        reopened.send(b"s", b"Scheduled")
        reopened.send(b"q", b"[q] quit")
        reopened.quit()
    finally:
        reopened.close()
    assert sha(ledger) == finished, "next-process read-only use changed canonical bytes"
    assert (root / "config/locus-catalog.tsv").is_file()
    assert (root / "config/daily-pace.tsv").is_file()
    assert (root / "config/boundary-presets.tsv").is_file()

print("Full independent first-run PTY: create/review, Loci, friendly labels, exact observation, view/pool/dates, Actual, future Scheduled and reopen without read-only writes passed.")
