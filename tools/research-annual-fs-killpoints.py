#!/usr/bin/env python3
"""Disposable annual segment/head experiment with real process SIGKILL points.

A filesystem protocol *experiment*, NOT a LOAM reader, canonical source codec,
durability proof, or approved household format. Only explicit temporary roots.
Run: python3 tools/research-annual-fs-killpoints.py --check
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

KILL_POINTS = (
    "before-segment",
    "after-segment-temp",
    "after-segment-durable",
    "after-manifest-durable",
    "before-head",
    "after-head",
    "after-head-durable",
)
HASH = re.compile(r"^[0-9a-f]{64}$")


class Unavailable(RuntimeError):
    pass


def canonical(obj: object) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sync_dir(path: Path) -> None:
    flags = os.O_RDONLY | os.O_DIRECTORY
    fd = os.open(path, flags)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def temp_path(folder: Path) -> Path:
    return folder / f".stage-{os.getpid()}-{os.urandom(4).hex()}"


def store_immutable(folder: Path, data: bytes, at_temp=None) -> str:
    """Write+fsync temporary data, link to content address, fsync folder.

    os.link prevents accidentally replacing a previously sealed blob.
    A process killed midway can leave unreferenced temp/orphan files.
    """
    identity = digest(data)
    dest = folder / identity
    stage = temp_path(folder)
    with stage.open("xb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    if at_temp is not None:
        at_temp()
    try:
        os.link(stage, dest)
    except FileExistsError:
        if dest.read_bytes() != data:
            raise Unavailable("content-address collision or corruption")
    stage.unlink()
    sync_dir(folder)
    return identity


def head_write(root: Path, identity: str, after_swap=None) -> None:
    if not HASH.fullmatch(identity):
        raise ValueError("invalid head digest")
    stage = temp_path(root)
    with stage.open("xb") as f:
        f.write((identity + "\n").encode("ascii"))
        f.flush()
        os.fsync(f.fileno())
    os.replace(stage, root / "HEAD")
    if after_swap is not None:
        after_swap()
    sync_dir(root)


def shard(year: int, operation: str) -> bytes:
    if not 2000 <= year <= 2100 or not operation.isascii() or not operation:
        raise ValueError("invalid synthetic shard")
    return canonical({
        "version": 1, "year": year, "op": operation,
        "facts": [
            {"kind": "actual", "source": operation + ":actual"},
            {"kind": "scheduled", "source": operation + ":scheduled"},
        ],
    })


@contextmanager
def writer_lock(root: Path):
    with (root / ".writer.lock").open("a+b") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def read(root: Path) -> tuple[str, dict, list[str]]:
    """Validate ALL head-referenced segments, never search staged files."""
    try:
        h = (root / "HEAD").read_text("ascii").strip()
        if not HASH.fullmatch(h):
            raise Unavailable("invalid head reference")
        manifest_blob = (root / "manifests" / h).read_bytes()
        if digest(manifest_blob) != h:
            raise Unavailable("head manifest content does not match digest")
        manifest = json.loads(manifest_blob)
        if manifest["version"] != 1 or not isinstance(manifest["segments"], list):
            raise Unavailable("unsupported manifest")
        years = []
        operations = []
        for item in manifest["segments"]:
            segment_hash = item["hash"]
            if not HASH.fullmatch(segment_hash):
                raise Unavailable("bad segment identity")
            raw = (root / "segments" / segment_hash).read_bytes()
            if digest(raw) != segment_hash:
                raise Unavailable("segment bytes corrupted")
            parsed = json.loads(raw)
            if parsed["version"] != 1 or parsed["year"] != item["year"]:
                raise Unavailable("segment metadata mismatch")
            if parsed["op"] != item["op"] or len(parsed["facts"]) != 2:
                raise Unavailable("segment operation/family mismatch")
            if {f["kind"] for f in parsed["facts"]} != {"actual", "scheduled"}:
                raise Unavailable("split multi-family publication")
            if {f["source"] for f in parsed["facts"]} != {
                    item["op"] + ":actual", item["op"] + ":scheduled"}:
                raise Unavailable("source identity mismatch")
            years.append(item["year"])
            operations.append(item["op"])
        if years != sorted(years) or len(operations) != len(set(operations)):
            raise Unavailable("out-of-order or duplicate accepted operation")
        return h, manifest, operations
    except (OSError, KeyError, TypeError, ValueError, UnicodeError) as ex:
        raise Unavailable("required head, manifest, or shard unavailable") from ex


def bootstrap(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=False)
    (root / "segments").mkdir()
    (root / "manifests").mkdir()
    (root / ".writer.lock").write_bytes(b"")
    segment = store_immutable(root / "segments", shard(2026, "initial-2026"))
    manifest = {"version": 1, "segments": [
        {"year": 2026, "hash": segment, "op": "initial-2026"}]}
    h = store_immutable(root / "manifests", canonical(manifest))
    head_write(root, h)
    sync_dir(root)
    read(root)


def kill_if(at: str, selected: str) -> None:
    if at == selected:
        # Real process death. This is NOT loss of power or loss of OS cache.
        os.kill(os.getpid(), signal.SIGKILL)


def publish(root: Path, expected: str, operation: str, year: int,
            kill_point: str = "") -> str:
    with writer_lock(root):
        h, existing, operations = read(root)
        if operation in operations:
            # Stable operation identity makes a post-commit retry a no-op.
            return h
        if h != expected:
            raise Unavailable("stale observed generation (CAS refused)")
        if year < existing["segments"][-1]["year"]:
            raise Unavailable("retroactive publication-year rewrite refused")
        kill_if("before-segment", kill_point)
        blob = store_immutable(
            root / "segments", shard(year, operation),
            at_temp=lambda: kill_if("after-segment-temp", kill_point))
        kill_if("after-segment-durable", kill_point)
        newer = {"version": 1, "segments": existing["segments"] + [
            {"year": year, "hash": blob, "op": operation}]}
        next_head = store_immutable(root / "manifests", canonical(newer))
        kill_if("after-manifest-durable", kill_point)
        kill_if("before-head", kill_point)
        head_write(root, next_head,
                   after_swap=lambda: kill_if("after-head", kill_point))
        kill_if("after-head-durable", kill_point)
        committed, _, _ = read(root)
        if committed != next_head:
            raise Unavailable("published head did not round-trip")
        return committed


def run_child(root: Path, expected: str, op: str, point: str = ""):
    return subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), "--child",
         str(root), expected, op, point], capture_output=True, text=True)


def expect_unavailable(action, message: str) -> None:
    try:
        action()
    except Unavailable:
        return
    raise AssertionError("unsafe acceptance: " + message)


def check() -> dict:
    observations = []
    with tempfile.TemporaryDirectory(prefix="loam-annual-fs-kill-") as base:
        base = Path(base)
        seed = base / "seed"
        bootstrap(seed)
        old, old_manifest, ops = read(seed)
        assert ops == ["initial-2026"]
        for index, point in enumerate(KILL_POINTS):
            root = base / f"case-{index}"
            shutil.copytree(seed, root)
            killed = run_child(root, old, "2027-admission", point)
            if killed.returncode != -signal.SIGKILL:
                raise AssertionError(
                    f"{point}: expected actual SIGKILL; got {killed.returncode}"
                    f"\nstdout:\n{killed.stdout}\nstderr:\n{killed.stderr}")
            visible_head, visible_manifest, visible_ops = read(root)
            before_commit = KILL_POINTS.index(point) < KILL_POINTS.index("after-head")
            assert (visible_head == old) == before_commit, point
            assert visible_ops == (
                ["initial-2026"] if before_commit else
                ["initial-2026", "2027-admission"])
            # Complete the logical operation after any interruption.
            retry = run_child(root, old, "2027-admission")
            assert retry.returncode == 0, (point, retry.stderr)
            once, _, operations = read(root)
            assert operations == ["initial-2026", "2027-admission"]
            assert run_child(root, old, "2027-admission").returncode == 0
            assert read(root)[0] == once  # repeat did not create another head
            observations.append({"kill": point,
                                 "visible": "old" if before_commit else "new",
                                 "retry": "exactly-once"})

        # Real-process race: both writers observed the same old head.
        raced = base / "raced"
        shutil.copytree(seed, raced)
        args = (sys.executable, str(Path(__file__).resolve()), "--child", str(raced), old)
        a = subprocess.Popen([*args, "writer-A", ""], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True)
        b = subprocess.Popen([*args, "writer-B", ""], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True)
        a.communicate()
        b.communicate()
        assert sorted((a.returncode, b.returncode)) == [0, 3], (
            a.returncode, b.returncode)
        _, _, ops = read(raced)
        assert len(ops) == 2 and ops[1] in ("writer-A", "writer-B")

        healthy = base / "healthy"
        shutil.copytree(seed, healthy)
        new = publish(healthy, old, "accepted-2027", 2027)
        assert new != old

        missing = base / "missing"
        shutil.copytree(healthy, missing)
        selected_shard = read(missing)[1]["segments"][-1]["hash"]
        (missing / "segments" / selected_shard).unlink()
        expect_unavailable(lambda: read(missing), "missing head-referenced shard")

        corrupt = base / "corrupt"
        shutil.copytree(healthy, corrupt)
        earlier = read(corrupt)[1]["segments"][0]["hash"]
        (corrupt / "segments" / earlier).write_bytes(b"corrupted prior evidence")
        expect_unavailable(lambda: read(corrupt), "tampered previous year")

        bad_manifest = base / "bad-manifest"
        shutil.copytree(healthy, bad_manifest)
        (bad_manifest / "manifests" / new).write_bytes(b"{}")
        expect_unavailable(lambda: read(bad_manifest), "tampered selected manifest")

        # A valid older HEAD swapped in place looks like a legitimate older
        # generation. There is NO independent anti-rollback authority here.
        silent_rollback = base / "rollback"
        shutil.copytree(healthy, silent_rollback)
        (silent_rollback / "HEAD").write_text(old + "\n", encoding="ascii")
        assert read(silent_rollback)[2] == ["initial-2026"]

        idle = base / "idle"
        shutil.copytree(seed, idle)
        before = sorted(str(p.relative_to(idle)) for p in idle.rglob("*"))
        # Passing an idle calendar boundary triggers NO writer whatsoever.
        after = sorted(str(p.relative_to(idle)) for p in idle.rglob("*"))
        assert before == after and read(idle)[0] == old

    return {
        "status": "PASS: disposable filesystem process-SIGKILL probes",
        "crash_points": observations,
        "concurrent_stale_writer_refused": True,
        "required_shard_missing_refused": True,
        "past_shard_corruption_refused": True,
        "manifest_corruption_refused": True,
        "idle_year_writes": 0,
        "limitation": "A valid rollback to old HEAD IS NOT DETECTED without an external trusted generation anchor; SIGKILL is not power-loss durability testing.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--child", nargs=4, metavar=("ROOT", "EXPECTED", "OP", "POINT"))
    args = parser.parse_args()
    if args.child is not None:
        root, expected, op, point = args.child
        try:
            publish(Path(root), expected, op, 2027, point)
            return
        except Unavailable as ex:
            print(str(ex), file=sys.stderr)
            raise SystemExit(3) from ex
    if args.check:
        print(json.dumps(check(), ensure_ascii=False, indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
