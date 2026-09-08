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
# Two remembered purposes let the PTY construct a balanced proposal without publishing it.
(root / "capacity.loam").write_text("""LOAM-CAPACITY-MEMORY\t1
MOVEMENT\tcapacity-1\tjpy
CHANGE\tUNALLOCATED\t-100
CHANGE\tPURPOSE\tfood\t100
MOVEMENT\tcapacity-2\tjpy
CHANGE\tUNALLOCATED\t-50
CHANGE\tPURPOSE\tstock\t50
""")
(root / "capacity.loam.effective").write_text(
    f"LOAM-CAPACITY-EFFECTIVE\t1\nEFFECTIVE\tcapacity-1\t{start}\nEFFECTIVE\tcapacity-2\t{start}\n")
sched_date = today + datetime.timedelta(days=5)
(root / "scheduled.loam").write_text(f"""LOAM-SCHEDULED-LIFECYCLE\t1
BEGIN\tScheduled
LOAM-SCHEDULED-MEMORY\t1
SCHEDULED\tscheduled-1\t{sched_date}\tjpy
CHANGE\tcash\t-250
CHANGE\twifi\t250
END\tScheduled
BEGIN\tCompletion
LOAM-SCHEDULED-COMPLETION-MEMORY\t1
END\tCompletion
BEGIN\tRetirement
LOAM-SCHEDULED-RETIREMENT-MEMORY\t1
END\tRetirement
BEGIN\tReplacement
LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1
END\tReplacement
""")
(root / "scheduled-routing.loam").write_text(f"""LOAM-SCHEDULED-ROUTING\t1
ROUTE\tscheduled-1\twifi\tFROM\t{start}\tMANAGED\tfood
""")
(root / "accounting-role.loam").write_text("""LOAM-ACCOUNTING-ROLE-MAP\t1
ROLE\tcash\tASSET
ROLE\twifi\tEXPENSE
""")


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
    assert "u route" in screen
    assert "g grant" in screen
    assert "r rebalance" in screen
    # Cycle Grant remains an existing direct action.
    os.write(master, b"g")
    preview = wait_for("[Publish]")
    assert "Capacity / Cycle Grant / Preview" in preview
    assert "Purpose:       food" in preview
    assert "Current Now:   100 jpy" in preview
    assert "Known future:  250 jpy" in preview
    assert "After-known:   -150 jpy" in preview
    assert "Amount:        150 jpy" in preview
    assert "From:          unallocated" in preview
    assert "[Publish]" in preview
    assert "[Edit]" in preview
    assert "[Cancel]" in preview
    os.write(master, b"\x1b")
    budget = wait_for("Cycle grant cancelled.")
    assert "Budget / Pension Cycle" in budget

    # Stage E1: Budget -> r reuses Capacity Rebalance. Home focus is still +42 days,
    # so the editor's effective date proves that Budget observedAt is the authority.
    before_rebalance = digest()
    os.write(master, b"r")
    rebalance = wait_for("Capacity / Rebalance")
    assert f"Effective: {today}" in rebalance
    assert "food" in rebalance and "stock" in rebalance
    assert "-150" in rebalance, "Budget CurrentCoverage was not carried into Rebalance"

    # Build a balanced preview: food -10, stock +10. Do not publish.
    os.write(master, b"e")
    wait_for("Editing Δ")
    for key in [b"-", b"1", b"0", b"\r"]:
        os.write(master, key)
    wait_for("-10")
    os.write(master, b"j")
    os.write(master, b"e")
    wait_for("Editing Δ")
    for key in [b"1", b"0", b"\r"]:
        os.write(master, key)
    wait_for("0  ")
    os.write(master, b"\r")
    rebalance_preview = wait_for("Capacity / Rebalance / Preview")
    assert f"Effective date: {today}" in rebalance_preview
    assert "food" in rebalance_preview and "-10 jpy" in rebalance_preview
    assert "stock" in rebalance_preview and "+10 jpy" in rebalance_preview
    # Default is Publish; Left wraps to Cancel, then Enter exits without a writer call.
    os.write(master, b"h")
    os.write(master, b"\r")
    budget_after_rebalance = wait_for("Capacity rebalance cancelled.")
    assert "Budget / Pension Cycle" in budget_after_rebalance
    assert f"Observed {today}" in budget_after_rebalance
    assert digest() == before_rebalance, "Cancelled Budget Rebalance changed evidence/config"

    os.write(master, b"u")
    wait_for("No unresolved Scheduled routing subjects.")
    os.write(master, b"e")
    wait_for("t transfer")
    os.write(master, b"b")
    wait_for("Budget / Pension Cycle")
    os.write(master, b"b")
    wait_for(f"Focus: {today + datetime.timedelta(days=42)}")
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
    assert digest() == before, "Cancelled production navigation changed fixture evidence/config"
    print("Production PTY: Budget grant/rebalance cancel, observedAt reuse, fresh return, raw Capacity and no writes passed.")
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
