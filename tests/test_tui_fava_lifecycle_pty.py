#!/usr/bin/env python3
"""Real Fava launch/refresh/shutdown through the direct palette; synthetic data only."""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import shutil
import signal
import socket
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loam_resource_probe", ROOT / "tools/benchmark-tui-resources.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
FAVA = b" jj\r" + b"j" * 10 + b"\r"


def send(terminal, keys, expected):
    os.write(terminal.fd, keys)
    _, output = terminal.capture(expected)
    return probe.ANSI.sub(b"", output)


def main():
    if not shutil.which("uvx"):
        print("uvx not found; skipping live Fava qualification (deterministic refusal PTY remains required).")
        return
    # Never kill an unrelated service or reuse somebody else's household ledger.
    with socket.socket() as check:
        assert check.connect_ex(("127.0.0.1", 5001)) != 0, "port 5001 already occupied; no process was killed"
    pid_file = Path("/tmp/loam-fava.pid")
    assert not pid_file.exists(), "existing Fava PID file; no process was killed"
    with tempfile.TemporaryDirectory(prefix="loam-fava-lifecycle-pty-") as tmp:
        root = Path(tmp) / "household"
        probe.fixture(root, events=4)
        frozen = probe.digest(root)
        commands = Path(tmp) / "commands"
        commands.mkdir()
        browser_log = Path(tmp) / "browser.log"
        for name in ["open", "xdg-open"]:
            command = commands / name
            command.write_text(f'#!/bin/sh\nprintf "%s\\n" "$1" >> "{browser_log}"\n')
            command.chmod(0o755)
        old_path = os.environ["PATH"]
        os.environ["PATH"] = str(commands) + os.pathsep + old_path
        terminal = probe.Terminal(ROOT / ".lake/build/bin/loamTui", root)
        owned_pid = None
        try:
            opened = send(terminal, FAVA, b"-> Fava started & opened")
            assert b"LOAM Home" in opened and b"Reports menu" not in opened
            owned_pid = int(pid_file.read_text().strip())
            with urllib.request.urlopen("http://127.0.0.1:5001/", timeout=5) as response:
                body = response.read().lower()
                assert response.status == 200 and (b"fava" in body or b"beancount" in body), body[:500]
            assert browser_log.read_text().splitlines() == ["http://127.0.0.1:5001"]
            refreshed = send(terminal, FAVA, b"refreshed projection (browser updated)")
            assert b"LOAM Home" in refreshed and int(pid_file.read_text().strip()) == owned_pid
            assert len(browser_log.read_text().splitlines()) == 1, "refresh opened another browser"
            terminal.quit()  # Already Home: no intermediate Reports back step.
            time.sleep(.3)
            assert not pid_file.exists(), "owned Fava PID file not removed"
            with socket.socket() as check:
                assert check.connect_ex(("127.0.0.1", 5001)) != 0, "owned Fava still listening after TUI exit"
            assert probe.digest(root) == frozen, "external projection changed household/config bytes"
            owned_pid = None  # Successful shutdown: never signal a potentially reused PID.
        finally:
            terminal.close()
            os.environ["PATH"] = old_path
            # On a failed assertion only, clean up this test's observed owned group.
            if owned_pid is not None:
                try:
                    os.killpg(owned_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                if pid_file.exists() and int(pid_file.read_text().strip()) == owned_pid:
                    pid_file.unlink()
    print("Fava PTY: real external launch/HTTP/browser dispatch, same-owned-server refresh, Home return, shutdown and unchanged synthetic fixture passed.")


if __name__ == "__main__":
    main()
