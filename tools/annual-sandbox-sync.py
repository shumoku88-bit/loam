#!/usr/bin/env python3
"""EXPERIMENTAL Linux / Darwin barriers for disposable Lean annual source roots.

Not product code, an alternative canonical owner, or a power-loss proof.
Linux uses os.fsync; Darwin requires a precompiled C F_FULLFSYNC witness and
refuses a non-APFS volume. No quiet fallback on missing/unsupported syscalls.
One-shot helper invoked synchronously by Lean after writing a stage file and
after installing a source/HEAD name. Failure is mandatory, never a warning.
The explicit marker restricts accidental use on a normal household root.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import stat
import subprocess
import sys

MARKER = ".loam-annual-durability-sandbox-only"


def darwin_fullfsync(path: Path, kind: str) -> None:
    """Fail-closed bridge to the prebuilt Darwin C syscall witness.

    The binary is intentionally supplied by disposable CI, never built or
    guessed at runtime. No downgrade to fsync when fullfsync is unsupported.
    """
    specified = os.environ.get("LOAM_ANNUAL_DARWIN_SYNC_BINARY")
    if not specified:
        raise RuntimeError("Darwin fullfsync binary not configured; refusal")
    binary = Path(specified)
    if not binary.is_absolute() or binary.is_symlink() or not binary.is_file():
        raise RuntimeError("Darwin fullfsync binary must be a real absolute file")
    completed = subprocess.run(
        [str(binary), "fullfsync", kind, str(path)],
        capture_output=True, text=True, timeout=60, check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"Darwin F_FULLFSYNC refused for {kind} {path}: "
            f"exit={completed.returncode}: {completed.stderr.strip()}"
        )
    if "fstype=apfs" not in completed.stdout:
        raise RuntimeError("Darwin annual fullfsync requires observed APFS: "
                           + completed.stdout.strip())


def checked_dir(path: Path) -> int:
    if not stat.S_ISDIR(os.lstat(path).st_mode):
        raise RuntimeError(f"non-directory or symlink in durability path: {path}")
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def sync_dir(path: Path) -> None:
    if sys.platform == "darwin":
        # Check the kind/path before asking native F_FULLFSYNC to open it.
        fd = checked_dir(path)
        os.close(fd)
        darwin_fullfsync(path, "directory")
    else:
        fd = checked_dir(path)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def validate_root(root: Path, target: Path, action: str) -> tuple[Path, Path]:
    if sys.platform not in ("linux", "darwin"):
        raise RuntimeError("experimental annual sync helper supports only Linux or Darwin")
    if not root.is_absolute() or not target.is_absolute():
        raise RuntimeError("durable sandbox requires absolute root and path")
    root = Path(os.path.normpath(str(root)))
    target = Path(os.path.normpath(str(target)))
    if target != root and root not in target.parents:
        raise RuntimeError("durability path escapes marked disposable root")
    if not stat.S_ISDIR(os.lstat(root).st_mode):
        raise RuntimeError("root must be a real directory, not a symlink")
    marker = root / MARKER
    if not stat.S_ISREG(os.lstat(marker).st_mode):
        raise RuntimeError("durable sandbox marker missing or not a regular file")
    if marker.read_bytes() != b"LOAM ANNUAL SANDBOX ONLY\n":
        raise RuntimeError("invalid disposable durability marker")
    # The parents action accepts either an installed FILE or a new directory.
    # Only the containing directory chain may be traversed as directories.
    directory = target if action == "parents" and target.is_dir() else target.parent
    current = root
    for segment in directory.relative_to(root).parts:
        current = current / segment
        checked = os.lstat(current)
        if not stat.S_ISDIR(checked.st_mode):
            raise RuntimeError(f"symlink/non-directory in durability chain: {current}")
    return root, target


def sync_file(root: Path, target: Path) -> None:
    mode = os.lstat(target).st_mode
    if not stat.S_ISREG(mode):
        raise RuntimeError(f"durable file is not a regular file: {target}")
    if sys.platform == "darwin":
        darwin_fullfsync(target, "file")
    else:
        fd = os.open(target, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def sync_parents(root: Path, target: Path) -> None:
    # Parent entry of root must also be synced for first-time bootstrap.
    directory = target if target.is_dir() else target.parent
    while True:
        sync_dir(directory)
        if directory == root:
            sync_dir(root.parent)
            break
        if root not in directory.parents:
            raise RuntimeError("durable ancestor path escaped root")
        directory = directory.parent


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=["file", "parents"])
    p.add_argument("root", type=Path)
    p.add_argument("target", type=Path)
    args = p.parse_args()
    root, target = validate_root(args.root, args.target, args.action)
    # Fault injection deliberately runs BEFORE a syscall. Used only by
    # disposable CI tests to ensure failed synchronization aborts admission.
    inject = os.environ.get("LOAM_ANNUAL_SANDBOX_SYNC_FAIL")
    if inject == f"{args.action}:{target.name}":
        raise RuntimeError("test-injected fsync refusal at " + inject)
    if args.action == "file":
        sync_file(root, target)
    else:
        sync_parents(root, target)
    # The trace is a diagnostic outside the authoritative root, NOT a commit
    # receipt or durable accounting fact.
    if trace := os.environ.get("LOAM_ANNUAL_SANDBOX_SYNC_TRACE"):
        with open(trace, "a", encoding="ascii") as handle:
            handle.write(f"{args.action}:{target.relative_to(root)}\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as ex:
        print(f"ANNUAL_SANDBOX_SYNC_REFUSED: {ex}", file=sys.stderr)
        raise SystemExit(3) from ex
