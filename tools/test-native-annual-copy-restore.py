#!/usr/bin/env python3
"""Disposable native annual source copy-first restore rehearsal.

This is NOT an operational backup command: requires synthetic native inputs,
uses only its own TemporaryDirectory, and never changes a live household.
The external test pins are trusted by this test only; ordinary annual HEAD
replay does not detect a valid-but-old rollback.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def lean(*args: str, success: bool = True) -> str:
    cmd = ["lake", "env", "lean", "--run",
           "tools/NativeAnnualCopyRestoreProbe.lean", *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    if success and proc.returncode:
        raise AssertionError(f"native Lean failed: {cmd}: {proc.stdout} {proc.stderr}")
    if not success and proc.returncode == 0:
        raise AssertionError(f"native Lean accepted an invalid copy: {cmd}")
    return proc.stdout + proc.stderr


def closure(head_bytes: bytes) -> list[Path]:
    """Paths selected by ONE explicitly pinned HEAD, never directory discovery."""
    try:
        head = head_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise AssertionError("non-UTF8 pinned HEAD") from exc
    lines = head.splitlines(keepends=True)
    if not lines or any(not line.endswith("\n") for line in lines):
        raise AssertionError("not a canonical newline-terminated HEAD")
    if len(lines) < 2 or lines[0] != "LOAM-ANNUAL-NATIVE-HEAD\t1\n":
        raise AssertionError("unexpected annual head version")
    match = re.fullmatch(r"BASE\t([0-9]{4})\n", lines[1])
    if not match:
        raise AssertionError("unqualified baseline path")
    base = match.group(1)
    if base == "0000":
        raise AssertionError("zero baseline year")
    paths = [Path("HEAD"), Path("journal") / base / "000000.household.loam"]
    last = base
    for index, row in enumerate(lines[2:], start=1):
        match = re.fullmatch(r"PUB\t([0-9]{4})\t([1-9][0-9]*)\n", row)
        if not match or int(match.group(2)) != index:
            raise AssertionError("noncontiguous or malformed selected annual source")
        year = match.group(1)
        if year < last:
            raise AssertionError("source year regressed")
        last = year
        paths.append(Path("journal") / year / f"{index}.full.loam")
    return paths


def copy_selected(source: Path, staging: Path, head_pin: bytes) -> list[Path]:
    if staging.exists():
        raise AssertionError("refuse to overwrite existing restore destination")
    if (source / "HEAD").read_bytes() != head_pin:
        raise AssertionError("source HEAD differs from test's independently pinned HEAD")
    paths = closure(head_pin)
    staging.mkdir()
    for item in [*paths, Path(".loam-annual-durability-sandbox-only")]:
        src = source / item
        if not src.is_file() or src.is_symlink():
            raise AssertionError(f"missing, non-file or symlink selected evidence: {item}")
        dst = staging / item
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        if src.read_bytes() != dst.read_bytes():
            raise AssertionError(f"copy bytes changed: {item}")
    return paths


def probe(root: Path, head_pin: Path, image_pin: Path, should_pass: bool) -> None:
    lean("verify", str(root), str(head_pin), str(image_pin),
         success=should_pass)


def restore(source: Path, destination: Path, pin_head: Path, pin_image: Path) -> None:
    """Copy into an isolated stage; only a qualified stage can get a public name.

    Rename is process-atomic within this disposable directory. This harness
    makes NO cross-device, crash, directory-fsync, or product durability claim.
    """
    if destination.exists():
        raise AssertionError("refuse replacing an existing restored selected source")
    stage = destination.with_name(destination.name + ".untrusted-stage")
    head = pin_head.read_bytes()
    try:
        copy_selected(source, stage, head)
        probe(stage, pin_head, pin_image, True)
        if destination.exists():
            raise AssertionError("destination unexpectedly appeared before promotion")
        stage.rename(destination)
        probe(destination, pin_head, pin_image, True)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def run(before: Path, after: Path) -> None:
    original_before, original_after = before.read_bytes(), after.read_bytes()
    with tempfile.TemporaryDirectory(prefix="loam-native-annual-copy-restore-") as tmp:
        work = Path(tmp)
        source = work / "isolated-source"
        head_pin = work / "expected-head.outside-root"
        image_pin = work / "expected-image.outside-root"
        lean("seed", str(source), str(before), str(after),
             str(head_pin), str(image_pin))
        witness = head_pin.read_bytes()
        expected_paths = closure(witness)
        if expected_paths != [
            Path("HEAD"), Path("journal/2026/000000.household.loam"),
            Path("journal/2027/1.full.loam"),
            Path("journal/2028/2.full.loam"),
        ]:
            raise AssertionError("copy selected an unexpected source closure")

        restore(source, work / "restored", head_pin, image_pin)
        recovered = work / "restored"
        for item in expected_paths:
            if (recovered / item).read_bytes() != (source / item).read_bytes():
                raise AssertionError(f"restore lost pinned bytes: {item}")

        # Reject a replayable but older complete HEAD when we have an
        # independent expected witness. Native unpinned replay accepts it.
        cases = ("missing-2027", "missing-2028", "corrupt-2027",
                 "corrupt-head", "valid-old-head")
        for case in cases:
            candidate = work / f"broken-{case}"
            copy_selected(source, candidate, witness)
            if case == "missing-2027":
                (candidate / "journal/2027/1.full.loam").unlink()
            elif case == "missing-2028":
                (candidate / "journal/2028/2.full.loam").unlink()
            elif case == "corrupt-2027":
                (candidate / "journal/2027/1.full.loam").write_bytes(b"corrupted object\n")
            elif case == "corrupt-head":
                (candidate / "HEAD").write_bytes(b"invalid native HEAD\n")
            elif case == "valid-old-head":
                rows = witness.splitlines(keepends=True)
                (candidate / "HEAD").write_bytes(b"".join(rows[:-1]))
                lean("unpinned", str(candidate), str(head_pin), str(image_pin))
            probe(candidate, head_pin, image_pin, False)

        # Orphan files never join the pinned read closure.
        orphan = recovered / "journal/2030/9.full.loam"
        orphan.parent.mkdir(parents=True)
        orphan.write_bytes(b"UNSELECTED-ORPHAN-NOT-AN-AUTHORITY\n")
        probe(recovered, head_pin, image_pin, True)

        # A valid existing restore cannot be silently overwritten, even when
        # the proposed source is itself complete and correctly pinned.
        try:
            restore(source, recovered, head_pin, image_pin)
        except AssertionError as exc:
            if "refuse replacing" not in str(exc):
                raise
        else:
            raise AssertionError("existing canonical-looking restore overwritten")

        # Repaired copy is the only one allowed to resume a 2029 native write.
        lean("continue", str(recovered), str(head_pin), str(image_pin))
        if not (recovered / "journal/2029/3.full.loam").is_file():
            raise AssertionError("post-restore 2029 native source not present")
        if source.joinpath("HEAD").read_bytes() != witness:
            raise AssertionError("source mutated during restore rehearsal")
        if before.read_bytes() != original_before or after.read_bytes() != original_after:
            raise AssertionError("input synthetic canonical image was modified")

        print("NATIVE_ANNUAL_COPY_RESTORE_PASS isolated pinned 2026-2028 "
              "source closure, missing/corrupt/old-head refusal, stage-only "
              "promotion, and native 2029 continuation")
        print("NATIVE_ANNUAL_COPY_RESTORE_LIMITATION "
              "external pin is test-only; no product backup, power-cut "
              "durability or trusted freshness authority")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    args = parser.parse_args()
    run(args.before.resolve(), args.after.resolve())
