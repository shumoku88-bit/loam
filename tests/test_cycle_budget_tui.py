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
# Production Capacity is now a HouseholdImage section, so use the Lean fixture
# helper rather than reimplementing the outer wire framing in Python.
repo_root = Path(__file__).resolve().parents[1]
subprocess.run(
    ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
     str(root), "set-capacity", str(start)],
    cwd=repo_root,
    check=True,
)
sched_date = today + datetime.timedelta(days=5)
subprocess.run(
    ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
     str(root), "set-scheduled", str(sched_date)],
    cwd=repo_root,
    check=True,
)
subprocess.run(
    ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
     str(root), "set-scheduled-routing", str(start)],
    cwd=repo_root,
    check=True,
)
# Keep a stale but valid legacy routing file beside HouseholdImage. Production
# reads/writes must ignore it throughout this PTY scenario.
(root / "scheduled-routing.loam").write_text(f"""LOAM-SCHEDULED-ROUTING\t1
ROUTE\tscheduled-1\twifi\tFROM\t{start}\tUNMANAGED
""")
(root / "actual-routing.loam").write_text("""LOAM-ACTUAL-ROUTING\t1
ROUTE\twifi\tINITIAL\tMANAGED\tlegacy-only
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


def controlling_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)


process = subprocess.Popen([str(executable), str(root)], stdin=slave, stdout=slave,
                           stderr=slave, env=env, preexec_fn=controlling_terminal)
os.close(slave)
ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def wait_for_fd(fd, expected, timeout=15):
    data = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if select.select([fd], [], [], 0.1)[0]:
            try:
                data += os.read(fd, 65536)
            except OSError:
                break
            clean = ansi.sub("", data.decode("utf-8", errors="replace"))
            if expected in clean:
                return clean
    raise AssertionError(f"Did not see {expected!r}: {ansi.sub('', data.decode(errors='replace'))}")


def wait_for(expected, timeout=15):
    return wait_for_fd(master, expected, timeout)


def drain_fd(fd):
    while select.select([fd], [], [], 0.1)[0]:
        try:
            if not os.read(fd, 1024):
                break
        except OSError:
            break


def open_envelope_commands():
    os.write(master, b" ")
    wait_for("Home / Commands")
    os.write(master, b"jjj\x1b[C")
    wait_for("Commands / Envelope budget")


def expect_local_unavailability(key, subject):
    os.write(master, key)
    wait_for(f"[Unavailable] {subject}:")
    assert process.poll() is None, f"TUI exited while reporting unavailable {subject}"


try:
    wait_for("LOAM Home")
    # Move beyond the next boundary in Calendar mode.
    # The current Budget must ignore this historical focus.
    for week in range(1, 7):
        os.write(master, b"j")
        wait_for(f"Focus: {today + datetime.timedelta(days=7 * week)}")
    open_envelope_commands()
    os.write(master, b"\r")
    screen = wait_for("r rebalance")
    assert "Budget / Pension Cycle" in screen
    assert f"{start} -> {end}" in screen
    assert f"Observed {today}" in screen
    assert "u route" in screen
    assert "g grant" in screen
    assert "r rebalance" in screen
    assert "Capacity/actions" not in screen
    assert "read only" not in screen
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
    rebalance = wait_for("-150")
    assert "Capacity / Rebalance" in rebalance
    assert f"Effective: {today}" in rebalance
    assert "Home > Capacity > Rebalance" not in rebalance
    assert "food" in rebalance and "stock" in rebalance

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
    # Stage E3: Budget e is retired. q returns directly to Home under the shared grammar.
    os.write(master, b"e")
    os.write(master, b"q")
    wait_for(f"Focus: {today + datetime.timedelta(days=42)}")
    # General Capacity is still accessible from Home's optional command palette.
    open_envelope_commands()
    os.write(master, b"j\r")
    wait_for("t transfer")
    os.write(master, b"q")
    wait_for("LOAM Home")

    # Home > Balances must use current support, not require zero-origin history.
    # This coordinate exists only in a current anchor and is deliberately absent
    # from ZeroOriginCoverage and Actual.
    balance_view_path = root / "config" / "balance-view.tsv"
    balance_view = balance_view_path.read_bytes()
    household_path = root / "household.loam"
    household_prev_path = root / "household.loam.prev"
    household_before_anchor = household_path.read_bytes()
    household_prev_before_anchor = (
        household_prev_path.read_bytes() if household_prev_path.exists() else None
    )
    balance_view_path.write_text("anchored-wallet\tjpy\n")
    subprocess.run(
        ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
         str(root), "set-current-anchor", "anchored-wallet", "jpy", "42"],
        cwd=repo_root,
        check=True,
    )
    os.write(master, b" jj\rj\r")
    anchored_balances = wait_for("Balances / Current")
    assert "anchored-wallet" in anchored_balances and "42 jpy" in anchored_balances, (
        "Home Balances did not compose CurrentQuantityAnchor support"
    )
    # Bounded print first requests consent outside alternate screen. Declining
    # must not emit the report; accepting prints data and resumes the TUI.
    os.write(master, b"p")
    preview = wait_for("Print to scrollback?")
    assert "Prepared" in preview and "terminal scrollback" in preview
    assert "anchored-wallet" not in preview, "preview leaked report before consent"
    os.write(master, b"n\n")
    refused = wait_for("Print cancelled.")
    assert "anchored-wallet" not in refused, "cancel printed household data"
    os.write(master, b"\n")
    wait_for("Balances / Current")
    os.write(master, b"p")
    wait_for("Print to scrollback?")
    os.write(master, b"y\n")
    printed = wait_for("End of LOAM report.")
    assert "anchored-wallet" in printed and "42 jpy" in printed
    os.write(master, b"\n")
    wait_for("Balances / Current")
    os.write(master, b"q")
    wait_for("LOAM Home")
    balance_view_path.write_bytes(balance_view)
    household_path.write_bytes(household_before_anchor)
    if household_prev_before_anchor is None:
        if household_prev_path.exists():
            household_prev_path.unlink()
    else:
        household_prev_path.write_bytes(household_prev_before_anchor)

    # Independent malformed workspace evidence stays fail-closed, but no longer
    # terminates the whole TUI. Restore every fixture after observing refusal so
    # this remains a navigation/read test with no canonical mutation.
    household_path = root / "household.loam"
    household = household_path.read_bytes()
    subprocess.run(
        ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
         str(root), "malform", "Attention"],
        cwd=repo_root,
        check=True,
    )
    expect_local_unavailability(b" j\rj\r", "Attention")
    household_path.write_bytes(household)

    balance_view_path.write_text("bad row\n")
    expect_local_unavailability(b" jj\rj\r", "Balances")
    balance_view_path.write_bytes(balance_view)

    household_path = root / "household.loam"
    household = household_path.read_bytes()
    subprocess.run(
        ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
         str(root), "malform", "ActualRouting"],
        cwd=repo_root,
        check=True,
    )
    open_envelope_commands()
    os.write(master, b"jj\r")
    wait_for("[Unavailable] Purpose routes:")
    assert process.poll() is None, "TUI exited while reporting unavailable Purpose routes"
    household_path.write_bytes(household)

    household_path = root / "household.loam"
    household = household_path.read_bytes()
    subprocess.run(
        ["lake", "env", "lean", "--run", "Loam/Tests/TuiHouseholdCutoverFixture.lean",
         str(root), "malform", "Capacity"],
        cwd=repo_root,
        check=True,
    )
    open_envelope_commands()
    os.write(master, b"j\r")
    wait_for("[Unavailable] Capacity:")
    assert process.poll() is None, "TUI exited while reporting unavailable Capacity"
    household_path.write_bytes(household)

    os.write(master, b"q")
    drain_fd(master)
    assert process.wait(timeout=10) == 0
    after_navigation = digest()
    changed_navigation = {
        path: (before.get(path), after_navigation.get(path))
        for path in sorted(set(before) | set(after_navigation))
        if before.get(path) != after_navigation.get(path)
    }
    assert after_navigation == before, (
        "Cancelled production navigation changed fixture evidence/config: "
        f"{changed_navigation}"
    )

    # P9 cutover freezes legacy scheduled.loam out of production selection.
    # Corrupt that valid legacy path before a fresh process starts and verify
    # Home, Scheduled, and Actual continue from HouseholdImage Scheduled evidence.
    scheduled_path = root / "scheduled.loam"
    scheduled_bytes = scheduled_path.read_bytes()
    scheduled_path.write_text("not-scheduled-evidence\n")
    master2, slave2 = pty.openpty()
    fcntl.ioctl(slave2, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

    def controlling_terminal2():
        os.setsid()
        fcntl.ioctl(slave2, termios.TIOCSCTTY, 0)

    process2 = subprocess.Popen([str(executable), str(root)], stdin=slave2, stdout=slave2,
                                stderr=slave2, env=env, preexec_fn=controlling_terminal2)
    os.close(slave2)
    try:
        startup = wait_for_fd(master2, "LOAM Home")
        assert "[g] summary" not in startup, "retired Summary shortcut returned at startup"
        assert process2.poll() is None, "TUI exited after ignoring malformed legacy Scheduled"

        os.write(master2, b"s")
        scheduled_screen = wait_for_fd(master2, "Scheduled Series Calendar")
        assert "Scheduled" in scheduled_screen
        assert process2.poll() is None, "malformed legacy Scheduled prevented Scheduled workspace use"
        os.write(master2, b"q")
        wait_for_fd(master2, "LOAM Home")

        os.write(master2, b"a")
        actual_screen = wait_for_fd(master2, "Household Actuals Workspace")
        assert "Actual" in actual_screen
        assert process2.poll() is None, "malformed legacy Scheduled prevented Actual workspace use"
        os.write(master2, b"q")
        wait_for_fd(master2, "LOAM Home")

        os.write(master2, b"q")
        drain_fd(master2)
        assert process2.wait(timeout=10) == 0
    finally:
        if process2.poll() is None:
            os.killpg(process2.pid, signal.SIGKILL)
            process2.wait(timeout=5)
        os.close(master2)
        scheduled_path.write_bytes(scheduled_bytes)

    assert digest() == before, "Scheduled legacy-isolation test changed fixture evidence/config"
    print("Production PTY: Calendar, hierarchical Budget/Capacity/Purpose commands, local refusals, Scheduled legacy isolation and no writes passed.")
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
