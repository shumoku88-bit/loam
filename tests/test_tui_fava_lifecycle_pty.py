#!/usr/bin/env python3
"""PTY-based end-to-end integration test verifying that loamTui cleans up its owned Fava process group upon exit."""

import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import struct
import subprocess
import termios
import time
import urllib.request

if not shutil.which("uvx"):
    print("uvx not found in PATH; skipping live PTY Fava lifecycle test.")
    exit(0)

repo_root = Path(__file__).resolve().parent.parent
executable = (repo_root / ".lake/build/bin/loamTui").resolve()
data_root = (repo_root.parent / "loam-data").resolve()

if not executable.exists():
    print(f"loamTui executable not found at {executable}; build first.")
    exit(1)

if not data_root.exists():
    print(f"loam-data root not found at {data_root}; skipping.")
    exit(0)

# Ensure no lingering fava prior to test
subprocess.run(["pkill", "-f", "fava --port 5001"], capture_output=True)
time.sleep(0.3)

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
env = dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(data_root))

def controlling_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

process = subprocess.Popen(
    [str(executable), str(data_root)],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    env=env,
    preexec_fn=controlling_terminal,
)
os.close(slave)

ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

def wait_for(expected, timeout=15):
    data = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            try:
                chunk = os.read(master, 65536)
                if not chunk:
                    break
                data += chunk
            except OSError:
                break
            clean = ansi.sub("", data.decode("utf-8", errors="replace"))
            if expected in clean:
                return clean
    raise AssertionError(f"Did not see {expected!r}")

def drain_fd(fd):
    while select.select([fd], [], [], 0.1)[0]:
        try:
            if not os.read(fd, 1024):
                break
        except OSError:
            break

try:
    # 1. Wait for Home screen
    wait_for("LOAM Home")

    # 2. Enter Reports workspace
    os.write(master, b"v")
    wait_for("Reports")

    # 3. Trigger Fava projection
    os.write(master, b"f")
    # The menu already contains "Fava Projection"; require the launch result,
    # not a label printed before the shortcut was handled.
    wait_for("-> Fava started & opened", timeout=15)

    # 4. Verify Fava HTTP endpoint responds
    fava_ok = False
    for _ in range(30):
        try:
            req = urllib.request.urlopen("http://127.0.0.1:5001/", timeout=1)
            if req.status == 200:
                fava_ok = True
                break
        except Exception:
            time.sleep(0.2)

    assert fava_ok, "Fava HTTP endpoint did not respond on port 5001"

    # Verify PID file exists
    assert os.path.exists("/tmp/loam-fava.pid"), "PID file /tmp/loam-fava.pid must exist"

    # Verify process exists in process table
    check_ps = subprocess.run(["ps", "aux"], capture_output=True, text=True)
    assert "fava --port 5001" in check_ps.stdout, "Fava not found in ps output"

    # 5. Exit back to Home then exit loamTui
    os.write(master, b"q")
    wait_for("LOAM Home")
    os.write(master, b"q")
    drain_fd(master)

    exit_code = process.wait(timeout=5)
    assert exit_code == 0, f"loamTui exited with code {exit_code}"

    time.sleep(0.3)

    # 6. Verify Fava process group was cleanly terminated
    check_ps_after = subprocess.run(["ps", "aux"], capture_output=True, text=True)
    lingering = [
        l for l in check_ps_after.stdout.splitlines()
        if "fava --port 5001" in l and "grep" not in l
    ]
    assert not lingering, f"Lingering Fava processes found: {lingering}"

    # 7. Verify PID file was removed
    assert not os.path.exists("/tmp/loam-fava.pid"), "PID file /tmp/loam-fava.pid was not cleaned up!"

    print("PTY E2E: TUI owned Fava lifecycle and shutdown verified successfully.")

finally:
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except Exception:
            process.kill()
    os.close(master)
    subprocess.run(["pkill", "-f", "fava --port 5001"], capture_output=True)
