#!/usr/bin/env python3
"""Linux CI process-kill/restart witness for native annual HEAD sandbox.

Uses actual Lean writer, Actual+Scheduled household fixture and actual SIGKILL.
Not a sudden-power-loss/fdatasync/fsync durability test.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def lean_run(file: str, *args: str) -> list[str]:
    return ["lake", "env", "lean", "--run", file, *args]


def checked(command: list[str]) -> str:
    result = subprocess.run(command, text=True, capture_output=True, timeout=50)
    if result.returncode:
        raise RuntimeError(
            f"native probe failed (code {result.returncode}): {command}\n"
            f"{result.stdout}\n{result.stderr}"
        )
    return result.stdout + result.stderr


def run(before: Path, after: Path) -> None:
    if not before.is_file() or not after.is_file():
        raise RuntimeError("native qualified before and after snapshot paths required")
    original_before, original_after = before.read_bytes(), after.read_bytes()

    with tempfile.TemporaryDirectory(prefix="loam-annual-sigkill-") as td:
        base = Path(td)
        root = base / "disposable-annual-head"
        ready = base / "after-source-installed.ready"
        command = lean_run(
            "tools/NativeAnnualSigkillWriter.lean",
            str(root), str(before), str(after), str(ready),
        )
        # Killing only lake can strand its child interpreter holding a
        # writer lock. Target the complete newly spawned process group.
        proc = subprocess.Popen(
            command, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 45
            while not ready.exists():
                if proc.poll() is not None:
                    out, err = proc.communicate(timeout=2)
                    raise RuntimeError(
                        f"native writer terminated before SIGKILL cut: "
                        f"{proc.returncode}\n{out}\n{err}"
                    )
                if time.monotonic() >= deadline:
                    raise TimeoutError("native writer never installed source and signaled cut")
                time.sleep(0.05)

            if ready.read_text() != "SOURCE_INSTALLED_BEFORE_HEAD\n":
                raise RuntimeError("native writer ready marker is invalid")
            old_head = (root / "HEAD").read_bytes()
            source = root / "journal" / "2027" / "1.full.loam"
            installed = source.read_bytes()
            if b"scheduled-completion:first" not in installed:
                raise RuntimeError("native installed source lacks paired operation identity")
            if b"PUB\t2027\t1" in old_head:
                raise RuntimeError("writer promoted HEAD before SIGKILL cut")

            os.killpg(proc.pid, signal.SIGKILL)
            code = proc.wait(timeout=10)
            if code != -signal.SIGKILL:
                raise RuntimeError(f"expected genuine SIGKILL subprocess exit, got {code}")
            if (root / "HEAD").read_bytes() != old_head:
                raise RuntimeError("SIGKILL allowed HEAD to advance before restart")
            if source.read_bytes() != installed:
                raise RuntimeError("SIGKILL lost or mutated already-installed source")

            # SECOND Lean process verifies old selected native answer, refuses
            # wrong and malformed operations, resumes exact source, rejects
            # duplicates, and admits a new 2028 change.
            output = checked(
                lean_run(
                    "tools/NativeAnnualOrphanRetryProbe.lean", "retry",
                    str(root), str(before), str(after),
                )
            )
            if "NATIVE_ANNUAL_ORPHAN_RETRY_PASS" not in output:
                raise RuntimeError("native retry expected witness marker missing")
            if (root / "HEAD").read_bytes() == old_head:
                raise RuntimeError("restarted native source reader never selected new HEAD")
            if source.read_bytes() != installed:
                raise RuntimeError("retry rewrote the installed source")
            if b"PUB\t2027\t1" not in (root / "HEAD").read_bytes():
                raise RuntimeError("native restored selected HEAD lost first year")
            if b"PUB\t2028\t2" not in (root / "HEAD").read_bytes():
                raise RuntimeError("subsequent 2028 publication is not selected")
            if before.read_bytes() != original_before or after.read_bytes() != original_after:
                raise RuntimeError("process-kill witness modified input native fixture")
            print("NATIVE_ANNUAL_REAL_SIGKILL_PASS "
                  "kill=-9 after full installed native source; old HEAD unchanged; "
                  "exact orphan resumed in second process; 2028 continued; "
                  "no duplicate or unknown-family loss")
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=10)
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    a = parser.parse_args()
    run(a.before, a.after)
