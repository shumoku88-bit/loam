#!/usr/bin/env python3
"""Bounded TUI resource/latency probe. Uses only a temporary synthetic household.

Build loamTui first. Example:
  python3 tools/benchmark-tui-resources.py --events 1000 --cycles 100 --idle-seconds 5
  python3 tools/benchmark-tui-resources.py --check --cycles 10

RSS is allocator residency, not proof of a leak. Samples after warm-up distinguish
initial allocation from continued growth. This is not a hours-long soak test.
"""
from __future__ import annotations

import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import pty
import re
import select
import shutil
import statistics
import struct
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def fixture(root: Path, events: int, days: int = 180) -> None:
    subprocess.run(["lake", "env", "lean", "--run", "Loam/Tests/ScheduledBatchReplacement.lean",
                    "setup", str(root)], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    # Append only synthetic Actuals to the temporary image, preserving the seeded
    # completion Event and all other sections. Production decoding/admission still
    # runs on startup; this is fixture construction, never a household migration.
    wire = (root / "household.loam").read_text()
    header, remaining = wire.split("\n", 1)
    assert header == "LOAM-HOUSEHOLD-IMAGE\t2"
    sections = []
    while remaining:
        framing, remaining = remaining.split("\n", 1)
        tag, name, length = framing.split("\t")
        assert tag == "SECTION"
        body, remaining = remaining[:int(length)], remaining[int(length):]
        if name == "Actual":
            today = datetime.date.today()
            body += "".join(
                f"TX\tresource-{i}\t{today - datetime.timedelta(days=i % days)}\tDESC\tsynthetic resource {i}\n"
                "EFFECT\tbank\tjpy\t-1\nEFFECT\twifi\tjpy\t1\nENDTX\n"
                for i in range(events)
            )
        sections.append((name, body))
    sections.extend([
        ("AccountingRole", "LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\tbank\tASSET\nROLE\twifi\tEXPENSE\n"),
        ("ZeroOrigin", "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\tbank\tjpy\nCOORDINATE\twifi\tjpy\n"),
    ])
    (root / "household.loam").write_text(header + "\n" + "".join(
        f"SECTION\t{name}\t{len(body)}\n{body}" for name, body in sections))
    (root / "config").mkdir(exist_ok=True)
    (root / "config/balance-view.tsv").write_text("bank\tjpy\n")
    (root / "config/daily-pace.tsv").write_text("bank\tjpy\n")
    today = datetime.date.today()
    (root / "config/boundary-presets.tsv").write_text(
        f"Synthetic\t{today - datetime.timedelta(days=30)}\t{today + datetime.timedelta(days=30)}\n")


def digest(root: Path) -> dict[str, str]:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


def resource_sample(pid: int) -> dict:
    result = subprocess.run(["ps", "-p", str(pid), "-o", "rss=", "-o", "time="],
                            check=True, text=True, capture_output=True)
    rss, cpu = result.stdout.split()
    cpu_seconds = 0.0
    for part in cpu.split(":"):
        cpu_seconds = cpu_seconds * 60 + float(part)
    proc_fds = Path(f"/proc/{pid}/fd")
    if proc_fds.is_dir():
        fds = len(list(proc_fds.iterdir()))
    elif shutil.which("lsof"):
        result = subprocess.run(["lsof", "-a", "-p", str(pid), "-d", "0-99999", "-F", "f"],
                                check=True, text=True, capture_output=True)
        fds = sum(bool(re.fullmatch(r"f\d+", line)) for line in result.stdout.splitlines())
    else:
        fds = None  # unavailable, never zero by assumption
    result = subprocess.run(["ps", "-axo", "pid=,ppid="], check=True, text=True, capture_output=True)
    relations = [tuple(map(int, line.split())) for line in result.stdout.splitlines()]
    descendants = {pid}
    while True:
        next_set = descendants | {child for child, parent in relations if parent in descendants}
        if next_set == descendants:
            break
        descendants = next_set
    return {"rss_kib": int(rss), "cpu_seconds": cpu_seconds,
            "fds": fds, "descendants": len(descendants) - 1}


class Terminal:
    def __init__(self, binary: Path, root: Path):
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 48, 160, 0, 0))
        self.initial_attrs = termios.tcgetattr(slave)

        def setup():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        start = time.monotonic()
        self.process = subprocess.Popen([str(binary), str(root)], stdin=slave, stdout=slave,
                                        stderr=slave, cwd=ROOT, preexec_fn=setup,
                                        env=dict(os.environ, TERM="xterm-256color"))
        os.close(slave)
        try:
            _, output = self.capture(b"LOAM Home")
            self.startup_ms = (time.monotonic() - start) * 1000
            assert b"\x1b[?1049h" in output
        except BaseException:
            self.close()
            raise

    def capture(self, expected: bytes, timeout: float = 30) -> tuple[float, bytes]:
        start = time.monotonic()
        last = start
        output = b""
        while time.monotonic() - start < timeout:
            if select.select([self.fd], [], [], .01)[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
                last = time.monotonic()
            elif expected in ANSI.sub(b"", output) and time.monotonic() - last >= .02:
                return (last - start) * 1000, output
        raise AssertionError((expected, output[-4000:], self.process.poll()))

    def send(self, keys: bytes, expected: bytes) -> float:
        os.write(self.fd, keys)
        elapsed, _ = self.capture(expected)
        return elapsed

    def idle(self, seconds: float) -> int:
        deadline = time.monotonic() + seconds
        count = 0
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], min(.05, max(0, deadline - time.monotonic())))[0]:
                chunk = os.read(self.fd, 65536)
                assert chunk, "TUI exited during idle sample"
                count += len(chunk)
        assert self.process.poll() is None
        return count

    def quit(self) -> bytes:
        os.write(self.fd, b"q")
        output = b""
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], .05)[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
            elif self.process.poll() is not None:
                break
        assert self.process.wait(timeout=5) == 0
        assert b"\x1b[?1049l" in output and b"\x1b[?25h" in output, "terminal mode cleanup missing"
        restored = termios.tcgetattr(self.fd)
        mask = termios.ICANON | termios.ECHO
        assert restored[3] & mask == self.initial_attrs[3] & mask, "canonical/echo modes not restored"
        return output

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        os.close(self.fd)


# Home shortcuts are intentionally minimal. Benchmarks must use real palette paths.
PALETTE_PACE = b" jj\r\r"
PALETTE_BALANCES = b" jj\rj\r"
PALETTE_REPORTS = b" jj\rjj\r"


def run(binary: Path, root: Path, cycles: int, idle_seconds: float, check: bool) -> dict:
    before = digest(root)
    terminal = Terminal(binary, root)
    samples, latencies, idle = [], {}, {}
    try:
        def cycle():
            for name, key, marker in (
                ("actual", b"a", b"Actual"),
                ("actual_back", b"q", b"LOAM Home"),
                ("record", b"r", b"Record movement"),
                ("cancel", b"\x1b", b"Record cancelled."),
                ("pace", PALETTE_PACE, b"Daily Pace / Trend"),
                ("pace_back", b"q", b"LOAM Home"),
                ("balances", PALETTE_BALANCES, b"Balances / Current"),
                ("balances_back", b"q", b"LOAM Home"),
                ("reports", PALETTE_REPORTS, b"Stock"),
                ("reports_back", b"q", b"LOAM Home"),
            ):
                latencies.setdefault(name, []).append(terminal.send(key, marker))

        for _ in range(5):
            cycle()
        samples.append({"cycles": 0, **resource_sample(terminal.process.pid)})
        for i in range(cycles):
            cycle()
            if (i + 1) % max(1, cycles // 4) == 0 or i + 1 == cycles:
                samples.append({"cycles": i + 1, **resource_sample(terminal.process.pid)})
        for name, key, marker, back in (
            ("calendar", None, None, None),
            ("record", b"r", b"Record movement", b"\x1b"),
            ("pace", PALETTE_PACE, b"Daily Pace / Trend", b"q"),
            ("balances", PALETTE_BALANCES, b"Balances / Current", b"q"),
            ("reports", PALETTE_REPORTS, b"Stock", b"q"),
        ):
            if key:
                terminal.send(key, marker)
            # Exclude settling/sampling subprocesses from the measured idle window.
            terminal.idle(.2)
            prior = resource_sample(terminal.process.pid)
            start = time.monotonic()
            output_bytes = terminal.idle(idle_seconds)
            wall_seconds = time.monotonic() - start
            after = resource_sample(terminal.process.pid)
            idle[name] = {"output_bytes": output_bytes, "wall_seconds": wall_seconds,
                          "cpu_seconds_delta": after["cpu_seconds"] - prior["cpu_seconds"],
                          "rss_kib_before": prior["rss_kib"], "rss_kib_after": after["rss_kib"]}
            if check:
                assert output_bytes == 0, f"idle {name} emitted {output_bytes} bytes"
            if back:
                terminal.send(back, b"LOAM Home")
        # The Daily Pace idle fast path must still notice real geometry changes.
        terminal.send(PALETTE_PACE, b"Daily Pace / Trend")
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 18, 80, 0, 0))
        _, resized = terminal.capture(b"Daily Pace")
        positions = re.findall(rb"\x1b\[(\d+);(\d+)H", resized)
        assert positions and all(1 <= int(row) <= 18 and 1 <= int(col) <= 80
                                 for row, col in positions), "idle Pace resize escaped viewport"
        terminal.send(b"q", b"LOAM Home")
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 48, 160, 0, 0))
        terminal.capture(b"LOAM Home")
        terminal.quit()
    finally:
        terminal.close()
    assert digest(root) == before, "read-only workloads changed synthetic evidence"
    if check:
        assert all(s["descendants"] == 0 for s in samples), samples
        if samples[0]["fds"] is not None:
            assert all(s["fds"] == samples[0]["fds"] for s in samples), samples
    return {"startup_ms": terminal.startup_ms, "samples": samples, "idle": idle,
            "latency_ms": {name: {"median": statistics.median(values),
                                   "max": max(values)} for name, values in latencies.items()},
            "fixture_unchanged": True}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=ROOT / ".lake/build/bin/loamTui")
    parser.add_argument("--events", type=int, default=100)
    parser.add_argument("--days", type=int, default=180,
                        help="date buckets; 50000 Events over 2500 days models about 20 entries/day over 6.8 years")
    parser.add_argument("--cycles", type=int, default=100)
    parser.add_argument("--idle-seconds", type=float, default=3)
    parser.add_argument("--check", action="store_true", help="assert quiet idle, stable FDs and no retained child processes")
    args = parser.parse_args()
    if args.events < 0 or args.days < 1 or args.cycles < 1 or args.idle_seconds <= 0:
        parser.error("events must be nonnegative; days, cycles and idle-seconds must be positive")
    binary = args.binary.resolve()
    if not binary.is_file():
        parser.error("build loamTui first")
    with tempfile.TemporaryDirectory(prefix="loam-tui-resources-") as tmp:
        root = Path(tmp) / "synthetic"
        fixture(root, args.events, args.days)
        report = run(binary, root, args.cycles, args.idle_seconds, args.check)
        print(json.dumps({"events_added": args.events, "date_buckets": args.days, "cycles": args.cycles,
                          "warmup_cycles": 5, "platform": platform.platform(),
                          "binary": str(binary), **report}, indent=2))


if __name__ == "__main__":
    main()
