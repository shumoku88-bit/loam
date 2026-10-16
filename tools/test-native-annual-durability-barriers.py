#!/usr/bin/env python3
"""Qualify ordered Linux fsync callbacks with real native Lean SIGKILL/restart.

No power failure simulated. Uses only temporary synthetic household roots.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def native(*parts: str) -> list[str]:
    return ["lake", "env", "lean", "--run", "tools/NativeAnnualDurabilityProbe.lean", *parts]


def run_checked(args: list[str], env: dict[str, str]) -> str:
    r = subprocess.run(args, text=True, capture_output=True, timeout=60, env=env)
    if r.returncode:
        raise RuntimeError(f"exit={r.returncode} {args} stdout={r.stdout} stderr={r.stderr}")
    return r.stdout + r.stderr


def run(before: Path, after: Path) -> None:
    old_input = before.read_bytes()
    new_input = after.read_bytes()
    with tempfile.TemporaryDirectory(prefix="loam-native-fsync-") as tmp:
        p = Path(tmp)
        root = p / "durable-annual"
        ready = p / "source-before-head.ready"
        trace = p / "fsync-calls.txt"
        env = {**os.environ, "LOAM_ANNUAL_SANDBOX_SYNC_TRACE": str(trace)}
        cmd = native("seed", str(root), str(before), str(after), str(ready))
        proc = subprocess.Popen(cmd, start_new_session=True, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True)
        try:
            deadline = time.monotonic() + 55
            while not ready.exists():
                if proc.poll() is not None:
                    out, err = proc.communicate(timeout=5)
                    raise RuntimeError(f"native durability writer died before cut {proc.returncode}: {out} {err}")
                if time.monotonic() > deadline:
                    raise TimeoutError("native source was never installed before HEAD")
                time.sleep(0.05)
            if ready.read_text() != "SOURCE_FSYNCED_BEFORE_HEAD\n":
                raise RuntimeError("unexpected native durable writer cut")
            head_path = root / "HEAD"
            old_head = head_path.read_bytes()
            orphan_path = root / "journal" / "2027" / "1.full.loam"
            orphan = orphan_path.read_bytes()
            if b"PUB\t2027\t1" in old_head or b"scheduled-completion:first" not in orphan:
                raise RuntimeError("writer published premature HEAD or wrong complete source")
            events = trace.read_text().splitlines()
            required = (
                "file:journal/2026/baseline.loam-stage",
                "parents:journal/2026/000000.household.loam",
                "file:HEAD.loam-stage",
                "parents:HEAD",
                "file:journal/2027/1.full.loam.loam-stage",
                "file:journal/2027/1.full.loam",
                "parents:journal/2027/1.full.loam",
            )
            for event in required:
                if event not in events:
                    raise RuntimeError(f"missing actual completed fsync barrier {event}: {events}")
            if events.index("parents:journal/2027/1.full.loam") <= events.index(
                "file:journal/2027/1.full.loam.loam-stage"
            ):
                raise RuntimeError("annual source fsync order reversed")
            os.killpg(proc.pid, signal.SIGKILL)
            if proc.wait(timeout=10) != -signal.SIGKILL:
                raise RuntimeError("native Lean writer was not actually SIGKILLed")
            if head_path.read_bytes() != old_head or orphan_path.read_bytes() != orphan:
                raise RuntimeError("SIGKILL changed selected HEAD or complete source")

            output = run_checked(native("retry", str(root), str(before), str(after)), env)
            if "NATIVE_ANNUAL_DURABLE_RETRY_PASS" not in output:
                raise RuntimeError("native durable recovery signal missing")
            if orphan_path.read_bytes() != orphan:
                raise RuntimeError("exact orphan retry changed installed bytes")
            result_head = head_path.read_bytes()
            if b"PUB\t2027\t1" not in result_head or b"PUB\t2028\t2" not in result_head:
                raise RuntimeError("restarted durable HEAD lost 2027 or 2028 chain")
            events = trace.read_text().splitlines()
            if events[-1] != "parents:HEAD":
                raise RuntimeError("successful native durable writer returned before directory barrier")
            if events.count("file:HEAD.loam-stage") < 3 or events.count("parents:HEAD") < 3:
                raise RuntimeError("native 2026/2027/2028 HEAD stages omitted fsync")

            # A second disposable root proves failed file fsync is a hard
            # refusal and leaves the previous selected HEAD unchanged.
            faultroot = p / "injected-fsync-failure"
            failed_env = {**env, "LOAM_ANNUAL_SANDBOX_SYNC_FAIL":
                          "file:1.full.loam.loam-stage"}
            fault = run_checked(
                native("fail-stage", str(faultroot), str(before), str(after)),
                failed_env,
            )
            if "NATIVE_ANNUAL_DURABLE_FSYNC_REFUSAL_PASS" not in fault:
                raise RuntimeError("injected fsync failure not observed")
            # Missing marker is a separate hard-stop even for a file that exists.
            refused = subprocess.run(
                ["python3", "tools/annual-sandbox-sync.py", "file",
                 str(p), str(before)],
                capture_output=True, text=True, timeout=5, env=env)
            if refused.returncode == 0:
                raise RuntimeError("unmarked root unexpectedly authorized fsync")
            if before.read_bytes() != old_input or after.read_bytes() != new_input:
                raise RuntimeError("experiment mutated the native input fixtures")
            print("NATIVE_ANNUAL_DURABILITY_BARRIERS_PASS "
                  "file and parent directory fsync before returned commit; "
                  "real SIGKILL before HEAD; exact native resume; 2028 chain; "
                  "sync-failure hard refusal; unmarked-root refusal")
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=10)
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True, type=Path)
    ap.add_argument("--after", required=True, type=Path)
    a = ap.parse_args()
    run(a.before.resolve(), a.after.resolve())
