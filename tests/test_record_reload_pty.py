#!/usr/bin/env python3
"""Actual navigation and Record reload boundaries, isolated synthetic household only."""
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


def household_sections(path):
    """Exact Unicode-length framing from HouseholdImagePersistence; test evidence only."""
    text = path.read_text()
    prefix = "LOAM-HOUSEHOLD-IMAGE\t2\n"
    assert text.startswith(prefix), "unexpected Household image version"
    pos, sections = len(prefix), {}
    while pos < len(text):
        end = text.index("\n", pos)
        marker, name, count = text[pos:end].split("\t")
        assert marker == "SECTION" and name not in sections
        start, length = end + 1, int(count)
        body = text[start:start + length]
        assert len(body) == length, "truncated Household section"
        sections[name] = body
        pos = start + length
    return sections


class Terminal:
    def __init__(self, root):
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 48, 160, 0, 0))

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([str(EXE), str(root)], stdin=slave, stdout=slave,
                                        stderr=slave, preexec_fn=setup,
                                        env=dict(os.environ, TERM="xterm-256color"))
        os.close(slave)
        self.capture(b"LOAM Home")

    def capture(self, expected):
        output = b""
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], .05)[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
            elif expected in ANSI.sub(b"", output):
                return output
        assert expected in ANSI.sub(b"", output), (expected, output)
        return output

    def send(self, keys, expected):
        os.write(self.fd, keys)
        return self.capture(expected)

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.fd)


with tempfile.TemporaryDirectory(prefix="loam-record-reload-") as tmp:
    root = Path(tmp) / "household"
    subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/ScheduledBatchReplacement.lean",
                    "setup", str(root)], cwd=REPO, check=True)
    authority = root / "household.loam"
    before = authority.read_bytes()
    # This fixture includes a published synthetic paid Wi-Fi Actual. Unlike the
    # empty CycleBudget resize fixture, it can qualify real Details navigation.
    def digest():
        return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in root.rglob("*") if p.is_file()}

    frozen_navigation = digest()
    terminal = Terminal(root)
    try:
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 10, 48, 0, 0))
        terminal.capture(b"[a]")  # tiny Home displays its help rather than its heading
        terminal.send(b"af", b"All Current")
        terminal.send(b"i", b"Details [active]")
        end = terminal.send(b"\x1b[Fj", b"End of Details.")
        assert b"ID:" in ANSI.sub(b"", end), ("Details End missed the identity tail", end)
        terminal.send(b"k", b"paid Wi-Fi")  # one key must move content, not a phantom offset
        terminal.send(b"\x1b[H", b"Date:")
        terminal.send(b"\x1b[6~", b"4,800")
        terminal.send(b"\x1b[5~", b"Date:")
        terminal.send(b"q", b"Actuals [active]")
        terminal.send(b"q", b"[a]")
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "read-only Actual navigation changed fixture evidence"

    # Editing follows the active row, keeps IME tails visible, and adapts while idle.
    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(("日本語" * 35 + "末尾").encode(), "末尾".encode())
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        resized = ANSI.sub(b"", terminal.capture(b"Locus candidates"))
        assert b"Postings" in resized and "末尾".encode() in resized, "editing resize hid input tail"
        terminal.send(b"\x0e" * 4, b"Posting 6:")  # Ctrl-N follows the newly appended Locus
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
        compact = ANSI.sub(b"", terminal.capture(b"[Esc] cancel"))
        assert b"Posting 6:" in compact and b"Fields" in compact, "compact editor hid focused row"
        terminal.send(b"\x04" * 4, b"4/7 fields")  # Ctrl-D returns safely to the two-row form
        terminal.send(b"\x1b", b"Record cancelled.")
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "read-only Record editing changed evidence"

    # Original amount attaches only to the draft; edits/clear/return never publish.
    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        assert not (termios.tcgetattr(terminal.fd)[3] & termios.IEXTEN), "tty intercepted editor control keys"
        opened = ANSI.sub(b"", terminal.send(b"\x0f", b"Record / Original amount"))
        assert b"not another posting" in opened and b"No FX inference" in opened
        terminal.send(b"usd\r0\r", b"Original amount must be positive.")
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
        compact = ANSI.sub(b"", terminal.capture(b"[Enter] next/attach"))
        assert b"Original amount must be positive." in compact, "resize hid validation feedback"
        assert b"[C-d] clear" in compact and b"[Esc] cancel" in compact, "compact Original hid controls"
        terminal.send(b"\x7f30\r", b"Original amount: 30")
        terminal.send(b"\x0f", b"Record / Original amount")
        # Ctrl-O abandons local Measure edits while retaining the attached value.
        terminal.send(b"\x7f\x7f\x7feur\x0f", b"Original amount: 30")
        terminal.send(b"\x0f", b"Record / Original amount")
        terminal.send(b"\x04", b"Original amount cleared.")
        terminal.send(b"\x1b", b"Record cancelled.")
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "Original amount editing changed household evidence"

    # Confirmation owns a bounded review viewport, not recording authority.
    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"long-review " * 30 + b"\t\tbank\t-10\twifi\t10\r",
                      b"Record / Preview")
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
        resized = terminal.capture(b"[Enter] confirm")
        assert b"Record / Preview" in ANSI.sub(b"", resized), "idle Record resize lost heading"
        tail = terminal.send(b"\x1b[F", b"Balanced total")
        assert b"10 jpy" in ANSI.sub(b"", tail), "review End lost exact total"
        terminal.send(b"\x1b[H", b"Description:")
        terminal.send(b"\x1b", b"Record cancelled.")
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "read-only confirmation review changed evidence"

    # First-use confirmation clearly separates policy admission from a Movement write.
    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        opened = ANSI.sub(b"", terminal.send(b"\x15", b"Household vocabulary"))
        assert b"Admit ordinary Locus: suspense." in opened
        assert b"does not record the Movement" in opened
        assert digest() == frozen_navigation, "opening enable confirmation published policy"
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
        compact = ANSI.sub(b"", terminal.capture(b"[Esc] cancel Record"))
        assert b"Preview before Publish" in compact and b"[e/E] return" in compact
        for back in (b"e", b"E", b"\x7f"):
            terminal.send(back, b"Record / Edit")
            assert digest() == frozen_navigation, "returning from enable confirmation published policy"
            terminal.send(b"\x15", b"Household vocabulary")
        terminal.send(b"\x1b", b"Record cancelled.")
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "cancelled enable confirmation changed household evidence"

    # Correction owns fixed-date input and a scrollable before/replacement review.
    terminal = Terminal(root)
    try:
        terminal.send(b"af", b"paid Wi-Fi")
        terminal.send(b"\r", b"Selected")
        terminal.send(b"c", b"Correction / Edit")
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        editing = ANSI.sub(b"", terminal.capture(b"Date (kept)"))
        assert b"Postings" in editing and b"Locus candidates" in editing
        terminal.send(("長い修正内容" * 30).encode() + b"\t\t\t\t\t\r", b"Correction / Preview")
        assert digest() == frozen_navigation, "Correction Preview published without confirmation"
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
        review = ANSI.sub(b"", terminal.capture(b"[Enter] confirm"))
        assert b"Original stays retained; date stays kept." in review
        terminal.send(b"\x1b[F", b"Replacement positive total:")
        terminal.send(b"\x1b[H", b"Target retained:")
        returned = ANSI.sub(b"", terminal.send(b"\x1b", b"Household Day Workspace"))
        assert b"Correction cancelled." in returned and b"[q] back" in returned, (
            "48x14 Selected Day hid child return feedback or navigation", returned
        )
        parent = ANSI.sub(b"", terminal.send(b"q", b"Household Actuals Workspace"))
        assert b"[n] new" in parent, "Actual parent returned with stale wide geometry"
    finally:
        terminal.close()
    assert digest() == frozen_navigation, "read-only Correction changed household evidence"

    # Removing the read authority while the editor is open makes any unwanted
    # caller reload deterministic, without asserting a machine-specific latency.
    for route in ("home", "actual", "selected-day"):
        terminal = Terminal(root)
        hidden = root / "held-image"
        try:
            if route == "actual":
                terminal.send(b"a", b"Actual")
                terminal.send(b"n", b"Description")
            elif route == "selected-day":
                terminal.send(b"\r", b"Selected")
                fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 14, 48, 0, 0))
                terminal.capture(b"Household Day Workspace")
                terminal.send(b"n", b"Description")
            else:
                terminal.send(b"r", b"Record movement")
            authority.rename(hidden)
            cancelled = ANSI.sub(b"", terminal.send(b"\x1b", b"Record cancelled."))
            if route == "selected-day":
                assert b"[q] back" in cancelled and b"[g] loci" in cancelled, "compact return lost fixed operations"
            assert terminal.process.poll() is None, route
            assert not authority.exists(), "cancel published a replacement image"
        finally:
            if hidden.exists():
                hidden.rename(authority)
            terminal.close()
        assert authority.read_bytes() == before, route

    terminal = Terminal(root)
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"reload-specimen\t\tbank\t-10\twifi\t10\r", b"Record / Preview")
        terminal.send(b"\r", b"Recorded ")
        assert authority.read_bytes() != before, "confirmed Record did not publish"
        # The new row in the Actual workspace requires a refreshed snapshot.
        terminal.send(b"a", b"reload-specimen")
    finally:
        terminal.close()

    # Publish an ordinary (not paid Scheduled) replacement and verify fresh review.
    terminal = Terminal(root)
    try:
        terminal.send(b"a", b"reload-specimen")
        terminal.send(b"\r", b"Selected")
        terminal.send(b"c", b"Correction / Edit")
        original_sections = household_sections(authority)
        original_wire = original_sections["Actual"]
        reviewed = ANSI.sub(b"", terminal.send(
            b"-corrected\t\t\t\x7f\x7f20\t\t\x7f\x7f20\r", b"Correction / Preview"))
        assert b"Before / selected snapshot" in reviewed and b"Replacement" in reviewed
        assert b"-10 jpy" in reviewed and b"-20 jpy" in reviewed
        assert household_sections(authority) == original_sections, "replacement Preview published"
        terminal.send(b"\r", b"Corrected ")
        revised_sections = household_sections(authority)
        revised_wire = revised_sections["Actual"]
        assert revised_wire != original_wire, "confirmed Correction did not publish"
        assert revised_wire.count("reload-specimen") > original_wire.count("reload-specimen"), "replacement lost original description evidence"
        assert {k: v for k, v in revised_sections.items() if k != "Actual"} == {
            k: v for k, v in original_sections.items() if k != "Actual"
        }, "ordinary Correction changed another Household section"
        # Resize forces a full redraw of the freshly reloaded selected day.
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        terminal.capture(b"reload-specimen-corrected")
    finally:
        terminal.close()

    terminal = Terminal(root)
    hidden = root / "held-image"
    try:
        terminal.send(b"r", b"Record movement")
        actual_before_activation = household_sections(authority)["Actual"]
        terminal.send(b"\x15", b"Enable")  # Ctrl-U, first-use suspense admission
        terminal.send(b"\r", b"Unresolved recording enabled")
        assert b"suspense" in authority.read_bytes(), "activation did not publish policy"
        assert household_sections(authority)["Actual"] == actual_before_activation, "activation recorded a Movement"
        authority.rename(hidden)
        terminal.send(b"\x1b", b"Reload failed")
        assert terminal.process.wait(timeout=5) != 0, "activation followed by cancel skipped reload"
    finally:
        if hidden.exists():
            hidden.rename(authority)
        terminal.close()

    # Even a failed activation may have published before the authoritative reload
    # failed. Its later cancellation must not take the read-only fast path.
    authority.write_bytes(before)
    terminal = Terminal(root)
    hidden = root / "held-image"
    try:
        terminal.send(b"r", b"Record movement")
        terminal.send(b"\x15", b"Enable")
        authority.rename(hidden)
        terminal.send(b"\r", b"Unresolved recording was not enabled")
        terminal.send(b"\x1b", b"Reload failed")
        assert terminal.process.wait(timeout=5) != 0, "failed activation/cancel skipped reload"
    finally:
        if hidden.exists():
            hidden.rename(authority)
        terminal.close()

print("Actual navigation and Record PTY: editing focus/IME/resize, Original amount, Correction before/replacement/resize/publication, unresolved enable/return, reload and cancellation passed.")
