"""Real PTY navigation of the production executable, using isolated synthetic evidence."""
import datetime
import fcntl
import hashlib
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time

root = Path(sys.argv[1]).resolve()
executable = Path(sys.argv[2]).resolve()
today = datetime.date.today()
start = today - datetime.timedelta(days=3)
end = today + datetime.timedelta(days=37)
(root / "config/boundary-presets.tsv").write_text(f"Pension\t{start}\t{end}\n")


def digest():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


before = digest()
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
env = dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root))
env.pop("LOAM_MOVEMENT_MANIFEST_ROOT", None)
def controlling_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)


process = subprocess.Popen([str(executable), str(root)], stdin=slave, stdout=slave,
                           stderr=slave, env=env, preexec_fn=controlling_terminal)
os.close(slave)
ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def wait_for(expected, timeout=15):
    data = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            try:
                data += os.read(master, 65536)
            except OSError:
                break
            clean = ansi.sub("", data.decode("utf-8", errors="replace"))
            if expected in clean:
                return clean
    raise AssertionError(f"Did not see {expected!r}: {ansi.sub('', data.decode(errors='replace'))}")


try:
    wait_for("LOAM Home")
    # Move beyond the next boundary. The current Budget must ignore this focus.
    for week in range(1, 7):
        os.write(master, b"j")
        wait_for(f"Focus: {today + datetime.timedelta(days=7 * week)}")
    os.write(master, b"c")
    screen = wait_for("read only")
    assert "Budget / Pension Cycle" in screen
    assert f"{start} -> {end}" in screen
    assert f"Observed {today}" in screen
    assert "37 days to next boundary" in screen
    assert "u route" in screen
    os.write(master, b"u")
    wait_for("No unresolved Scheduled routing subjects.")
    os.write(master, b"e")
    wait_for("t transfer")
    os.write(master, b"b")
    wait_for("Budget / Pension Cycle")
    os.write(master, b"b")
    home = wait_for(f"Focus: {today + datetime.timedelta(days=42)}")
    # Home's old e entrance still works; no Capacity view is copied.
    os.write(master, b"e")
    wait_for("t transfer")
    os.write(master, b"b")
    wait_for("LOAM Home")
    os.write(master, b"q")
    while select.select([master], [], [], 0.1)[0]:
        try:
            if not os.read(master, 1024):
                break
        except OSError:
            break
    assert process.wait(timeout=10) == 0
    assert digest() == before, "Read-only navigation changed fixture evidence/config"
    print("Production PTY: Home c, focus-independent boundary, raw Capacity, back and no writes passed.")
except BaseException:
    import traceback
    traceback.print_exc()
    raise
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGKILL)
        os.close(master)
        process.wait(timeout=5)
    else:
        os.close(master)
