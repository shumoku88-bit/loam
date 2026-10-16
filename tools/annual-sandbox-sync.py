#!/usr/bin/env python3
"""EXPERIMENTAL Linux fsync barrier for disposable Lean annual source roots.

Not product code, an alternative canonical owner, or a power-loss proof.
One-shot helper invoked synchronously by Lean after writing a stage file and
after installing a source/HEAD name. Failure is mandatory, never a warning.
The explicit marker restricts accidental use on a normal household root.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import stat
import sys

MARKER = ".loam-annual-durability-sandbox-only"


def checked_dir(path: Path) -> int:
    if not stat.S_ISDIR(os.lstat(path).st_mode):
        raise RuntimeError(f"non-directory or symlink in durability path: {path}")
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def sync_dir(path: Path) -> None:
    fd = checked_dir(path)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def validate_root(root: Path, target: Path, action: str) -> tuple[Path, Path]:
    if sys.platform != "linux":
        raise RuntimeError("experimental directory-fsync helper qualified only on Linux")
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
    current = root
    relatives = target.relative_to(root).parts
    for segment in relatives[:-1] if action == "file" else relatives:
        current = current / segment
        checked = os.lstat(current)
        if not stat.S_ISDIR(checked.st_mode):
            raise RuntimeError(f"symlink/non-directory in durability chain: {current}")
    return root, target


def sync_file(root: Path, target: Path) -> None:
    mode = os.lstat(target).st_mode
    if not stat.S_ISREG(mode):
        raise RuntimeError(f"durable file is not a regular file: {target}")
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
    if args.action == "file":
        sync_file(root, target)
    else:
        sync_parents(root, target)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as ex:
        print(f"ANNUAL_SANDBOX_SYNC_REFUSED: {ex}", file=sys.stderr)
        raise SystemExit(3) from ex
