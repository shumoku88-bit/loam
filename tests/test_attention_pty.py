#!/usr/bin/env python3
"""Attention UI, cancellation/publication and resize: isolated synthetic data only."""
from __future__ import annotations

import datetime
import fcntl
import importlib.util
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import termios

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def fixture(root, *args):
    subprocess.run(["lake", "env", "lean", "--run", "tests/AttentionPtyFixture.lean", str(root), *args],
                   cwd=ROOT, check=True)


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    return probe.ANSI.sub(b"", output)


def paste(terminal, value, expected):
    return send(terminal, b"\x1b[200~" + value.encode() + b"\x1b[201~", expected)


def bounded(output, rows, cols):
    positions = re.findall(rb"\x1b\[(\d+);(\d+)H", output)
    assert positions and all(1 <= int(r) <= rows and 1 <= int(c) <= cols for r, c in positions), positions
    assert b"\n" not in output and b"\r" not in output, "frame moved terminal screen"


def resize(terminal, rows, cols, expected):
    fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    _, output = terminal.capture(expected)
    bounded(output, rows, cols)
    return probe.ANSI.sub(b"", output)


def sections(root, filename="household.loam"):
    # HouseholdImage lengths count Unicode characters, not UTF-8 bytes.
    header, remaining = (root / filename).read_text().split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2"
    result = {}
    while remaining:
        framing, remaining = remaining.split("\n", 1)
        tag, name, length = framing.split("\t")
        assert tag == "SECTION"
        size = int(length)
        result[name] = remaining[:size].encode()
        remaining = remaining[size:]
    return result


def main():
    with tempfile.TemporaryDirectory(prefix="loam-attention-pty-") as tmp:
        root = Path(tmp)
        probe.fixture(root, events=0)
        fixture(root, "seed")
        (root / "attention.loam").write_text("frozen legacy sentinel; never production authority\n")
        before = probe.digest(root)
        original = sections(root)
        terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        try:
            focus = send(terminal, b"h", b"Focus:")
            selected_date = re.search(rb"Focus: (\d{4}-\d{2}-\d{2})", focus).group(1)
            opened = send(terminal, b"i", b"Attention / Manage")
            assert "╭ Open [active]".encode() in opened and b"no due date" in opened and b"due unknown" in opened
            send(terminal, b"i", b"Selected matter")
            compact = resize(terminal, 14, 48, b"Selected matter")
            assert "╭ Open".encode() not in compact
            send(terminal, b"\x1b[F", b"context-tail")
            send(terminal, b"q", b"Open [active]")
            os.write(terminal.fd, b"q")
            _, home = terminal.capture(b"LOAM Home")
            bounded(home, 14, 48)
            assert b"Focus: " + selected_date in probe.ANSI.sub(b"", home)
            assert probe.digest(root) == before, "read-only Attention visit changed fixture"
            send(terminal, b"i", b"Attention / Manage")
            # Long input tail + paste normalization, followed by cancellation.
            send(terminal, b"n", b"Attention / New")
            resize(terminal, 18, 70, b"Attention / New")
            paste(terminal, "入力" * 60 + "-new-tail\nnot retained", b"-new-tail")
            send(terminal, b"\r", b"Due meaning")
            send(terminal, b"\x1b", b"Attention / Manage")
            assert probe.digest(root) == before, "Add cancellation wrote Attention"
            send(terminal, b"n", b"Attention / New")
            paste(terminal, "date refusal", b"date refusal")
            send(terminal, b"\r", b"Due meaning")
            send(terminal, b"d", b"Due date")
            paste(terminal, "2026-02-31", b"2026-02-31")
            refused = send(terminal, b"\r", b"real calendar date")
            assert b"YYYY-MM-DD" in refused
            send(terminal, b"\x1b", b"Attention / Manage")
            assert probe.digest(root) == before, "invalid due date wrote Attention"
            resize(terminal, 35, 150, b"Attention / Manage")
            send(terminal, b"\x1b[F", b"MATTER-30")
            send(terminal, b"r", b"Attention / resolve")
            send(terminal, b"\x1b", b"Attention / Manage")
            send(terminal, b"x", b"Attention / drop")
            send(terminal, b"\x1b", b"Attention / Manage")
            assert probe.digest(root) == before, "close cancellation wrote a lifecycle fact"
            send(terminal, b"r", b"Attention / resolve")
            resize(terminal, 14, 48, b"Attention / resolve")
            send(terminal, b"\r", b"Resolved attention-30.")
            send(terminal, b"\x1b[F", b"MATTER-29")
            send(terminal, b"x", b"Attention / drop")
            send(terminal, b"\r", b"Dropped attention-29.")
            for context, choice, notice in [("no due sample", b"n", b"Added attention-31."),
                                             ("unknown sample", b"u", b"Added attention-32.")]:
                send(terminal, b"n", b"Attention / New")
                paste(terminal, context, context.encode())
                send(terminal, b"\r", b"Due meaning")
                send(terminal, choice, notice)
            send(terminal, b"n", b"Attention / New")
            paste(terminal, "dated sample", b"dated sample")
            send(terminal, b"\r", b"Due meaning")
            send(terminal, b"d", b"Due date")
            paste(terminal, "2026-11-20", b"2026-11-20")
            send(terminal, b"\r", b"Added attention-33.")
            body = sections(root)["Attention"]
            today = str(datetime.date.today()).encode()
            assert b"CLOSE\tattention-30\t" + today + b"\tRESOLVED" in body
            assert b"CLOSE\tattention-29\t" + today + b"\tDROPPED" in body
            assert b"ITEM\tattention-31\tNO_DUE_DATE\t-\tno due sample" in body
            assert b"ITEM\tattention-32\tDUE_UNDETERMINED\t-\tunknown sample" in body
            assert b"ITEM\tattention-33\tDUE_ON\t2026-11-20\tdated sample" in body
            # Re-admission belongs to the shared writer, not stale TUI evidence.
            send(terminal, b"r", b"Attention / resolve")  # refreshed cursor points at attention-1
            fixture(root, "close", "attention-1")
            after_external = probe.digest(root)
            send(terminal, b"\r", b"already closed")
            assert probe.digest(root) == after_external, "stale close refusal published a second closure"
            send(terminal, b"q", b"LOAM Home")
            terminal.quit()
            current = sections(root)
            assert {key: value for key, value in current.items() if key != "Attention"} == {
                key: value for key, value in original.items() if key != "Attention"}, "Attention changed another canonical family"
            after = probe.digest(root)
            previous = sections(root, "household.loam.prev")
            assert {key: value for key, value in previous.items() if key != "Attention"} == {
                key: value for key, value in original.items() if key != "Attention"}, "Attention changed another recovery-image family"
            # Shared publication intentionally advances the previous-image backup.
            # Configuration, frozen legacy and all other bytes must remain unchanged.
            publication_files = {"household.loam", "household.loam.prev"}
            extras_before = {key: value for key, value in before.items() if key not in publication_files}
            extras_after = {key: value for key, value in after.items() if key not in publication_files}
            assert extras_after == extras_before, ("Attention changed configuration/legacy bytes", {
                key: (extras_before.get(key), extras_after.get(key))
                for key in extras_before.keys() | extras_after.keys()
                if extras_before.get(key) != extras_after.get(key)})
        finally:
            terminal.close()
    print("Attention PTY: list/Detail/input/confirmation resize, cancels, due meanings, resolve/drop, stale refusal and family preservation passed.")


if __name__ == "__main__":
    main()
