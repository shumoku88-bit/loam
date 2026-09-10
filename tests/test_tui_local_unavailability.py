"""Production PTY keeps Home alive when independent workspace reads refuse."""
import fcntl
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

# Keep Actual/Scheduled startup evidence valid while independently breaking
# on-demand workspace inputs. None of these refusals may be reinterpreted as
# empty/zero evidence, and none may terminate the production TUI.
(root / "attention.loam").write_text("not-attention-evidence\n")
(root / "config" / "balance-view.tsv").write_text("bad row\n")
(root / "actual-routing.loam").write_text("not-routing-evidence\n")
(root / "capacity.loam").write_text("not-capacity-evidence\n")

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
env = dict(os.environ, TERM="xterm-256color", LOAM_DATA_DIR=str(root))
env.pop("LOAM_MOVEMENT_MANIFEST_ROOT", None)


def controlling_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)


process = subprocess.Popen(
    [str(executable), str(root)],
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
                data += os.read(master, 65536)
            except OSError:
                break
            clean = ansi.sub("", data.decode("utf-8", errors="replace"))
            if expected in clean:
                return clean
    raise AssertionError(
        f"Did not see {expected!r}: {ansi.sub('', data.decode(errors='replace'))}"
    )


def press_and_expect(key, text):
    os.write(master, key)
    screen = wait_for(text)
    assert process.poll() is None, f"TUI exited while reporting {text!r}"
    return screen


try:
    wait_for("LOAM Home")
    press_and_expect(b"i", "[Unavailable] Attention:")
    press_and_expect(b"b", "[Unavailable] Balances:")
    press_and_expect(b"u", "[Unavailable] Purpose routes:")
    press_and_expect(b"e", "[Unavailable] Capacity:")

    # A refused workspace did not poison unrelated Home navigation or process life.
    os.write(master, b"q")
    while select.select([master], [], [], 0.1)[0]:
        try:
            if not os.read(master, 1024):
                break
        except OSError:
            break
    assert process.wait(timeout=10) == 0
    print(
        "Production PTY: independent workspace refusals stayed local and Home remained available."
    )
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
