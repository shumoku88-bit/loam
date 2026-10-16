#!/usr/bin/env python3
"""Research-only single-head SIGKILL replay of native Actual+Scheduled source.

Uses real Lean-published, synthetic before/after HouseholdImages and the
existing cross-family year-source patch. No production files or writer hooks.
This demonstrates process-kill visibility, NOT sudden-power-loss durability,
an authoritative clock, long-term rollback detection, or a production codec.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POINTS = (
    "before-object",
    "after-object-temp",
    "after-object-durable",
    "after-manifest-durable",
    "before-head",
    "after-head",
    "after-head-durable",
)
MARKER = "LOAM-RESEARCH-ONLY-NATIVE-ANNUAL-HEAD-1\n"
OP = "scheduled-completion:first"


def imports():
    name = "loam_existing_cross_family_source"
    spec = importlib.util.spec_from_file_location(
        name, ROOT / "tools" / "research-source-year-cross-family.py"
    )
    assert spec and spec.loader
    cross = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cross)
    bridge = cross.bridge_module()
    fs = bridge.storage()
    return cross, bridge, fs


def refuse(condition: bool, message: str, cross) -> None:
    if not condition:
        raise cross.Refused(message)


def manifest_object(root: Path, identity: str, fs, cross) -> dict:
    refuse(bool(fs.HASH.fullmatch(identity)), "invalid head/manifest identity", cross)
    raw = (root / "manifests" / identity).read_bytes()
    refuse(fs.digest(raw) == identity, "wrong manifest digest", cross)
    data = json.loads(raw)
    refuse(isinstance(data, dict) and
           set(data) == {"version", "ordinal", "previous", "operation", "entries"} and
           data["version"] == 1 and type(data["ordinal"]) is int and
           isinstance(data["entries"], list),
           "unsupported source head manifest", cross)
    return data


def replay_head(root: Path, identity: str, cross, bridge, fs):
    """Pin ONE selected manifest and every referenced immutable source object.

    The two-generation grammar is deliberately narrow. A third year must be
    designed and proved rather than silently treating arbitrary files as facts.
    """
    man = manifest_object(root, identity, fs, cross)
    entries = man["entries"]
    refuse(len(entries) in (1, 2), "unsupported source generation count", cross)
    expected = (
        [(2026, 1, "household")]
        if len(entries) == 1 else
        [(2026, 1, "household"), (2027, 2, "sections")]
    )
    files = {}
    for entry, (year, seq, kind) in zip(entries, expected):
        refuse(isinstance(entry, dict) and
               set(entry) == {"year", "seq", "kind", "hash"} and
               type(entry.get("year")) is int and
               type(entry.get("seq")) is int and
               (entry["year"], entry["seq"], entry["kind"]) == (year, seq, kind) and
               isinstance(entry["hash"], str) and
               bool(fs.HASH.fullmatch(entry["hash"])),
               "bad source object identity or publication-year ordering", cross)
        raw = (root / "journal" / str(year) / entry["hash"]).read_bytes()
        refuse(fs.digest(raw) == entry["hash"], "corrupt source object", cross)
        files[f"journal/{year}/{seq:06d}.{kind}.loam"] = raw

    if len(entries) == 1:
        refuse(man["ordinal"] == 0 and man["previous"] is None and
               man["operation"] == "initial-synthetic-2026",
               "bad genesis publication", cross)
        wire = files["journal/2026/000001.household.loam"]
        refuse(bridge.encode(bridge.parse_wire(wire)) == wire,
               "initial HouseholdImage not byte-exact", cross)
    else:
        refuse(man["ordinal"] == 1 and man["operation"] == OP and
               isinstance(man["previous"], str) and
               man["previous"] != identity, "bad successor publication", cross)
        parent = manifest_object(root, man["previous"], fs, cross)
        refuse(parent["ordinal"] == 0 and parent["entries"] == entries[:1] and
               parent["operation"] == "initial-synthetic-2026" and
               parent["previous"] is None, "broken source head predecessor", cross)
        wire = cross.replay(files, bridge)  # native Actual + Scheduled together
    return man, wire


def read_head(root: Path, cross, bridge, fs):
    """No cache, working tree, previous HEAD or Git fallback is ever consulted."""
    try:
        selected = (root / "HEAD").read_text("ascii")
        refuse(selected.endswith("\n") and
               bool(fs.HASH.fullmatch(selected[:-1])),
               "missing/invalid selected head", cross)
        identity = selected[:-1]
        manifest, wire = replay_head(root, identity, cross, bridge, fs)
        return identity, manifest, wire
    except (OSError, ValueError, KeyError, TypeError, UnicodeError) as error:
        raise cross.Refused("committed source unavailable") from error


def bootstrap(root: Path, before: bytes, cross, bridge, fs) -> str:
    root.mkdir()
    (root / "journal").mkdir()
    (root / "journal" / "2026").mkdir()
    (root / "manifests").mkdir()
    (root / ".writer.lock").touch()
    (root / ".test-only-single-head").write_text(MARKER, encoding="ascii")
    bridge.parse_wire(before)
    first = fs.store_immutable(root / "journal" / "2026", before)
    man = {
        "version": 1, "ordinal": 0, "previous": None,
        "operation": "initial-synthetic-2026",
        "entries": [{"year": 2026, "seq": 1, "kind": "household", "hash": first}],
    }
    h = fs.store_immutable(root / "manifests", fs.canonical(man))
    fs.head_write(root, h)
    refuse(read_head(root, cross, bridge, fs)[2] == before,
           "bootstrap mismatch", cross)
    return h


def kill_if(point: str, selected: str) -> None:
    if point == selected:
        import os
        os.kill(os.getpid(), signal.SIGKILL)


def publish(root: Path, expected: str, patch: bytes, point: str,
            cross, bridge, fs) -> str:
    # An explicit guard limits this potentially mutating test interface to
    # directories bootstrapped by the experiment (never an actual household).
    refuse((root / ".test-only-single-head").read_text("ascii") == MARKER,
           "not a research-only directory", cross)
    with fs.writer_lock(root):
        selected, man, before = read_head(root, cross, bridge, fs)
        patch_hash = fs.digest(patch)
        if man["operation"] == OP:
            refuse(man["previous"] == expected and
                   man["entries"][-1]["hash"] == patch_hash,
                   "ambiguous or conflicting already-applied retry", cross)
            return selected  # ambiguous successful first reply: exactly once
        refuse(selected == expected and man["ordinal"] == 0,
               "stale writer or unsupported current head", cross)
        after, accepted_day = cross.apply_patch(before, patch, bridge)
        refuse(accepted_day == "2027-01-01" and after != before,
               "invalid injected admission day or no-op", cross)

        kill_if("before-object", point)
        year_dir = root / "journal" / "2027"
        year_dir.mkdir(exist_ok=True)
        fs.sync_dir(root / "journal")
        object_hash = fs.store_immutable(
            year_dir, patch, at_temp=lambda: kill_if("after-object-temp", point))
        kill_if("after-object-durable", point)
        candidate = {
            "version": 1, "ordinal": 1, "previous": selected,
            "operation": OP,
            "entries": man["entries"] + [
                {"year": 2027, "seq": 2, "kind": "sections", "hash": object_hash}
            ],
        }
        next_head = fs.store_immutable(root / "manifests", fs.canonical(candidate))
        # Reconstruct the *unselected* candidate before permitting head switch.
        proposed, rebuilt = replay_head(root, next_head, cross, bridge, fs)
        refuse(proposed == candidate and rebuilt == after,
               "unqualified next-generation source", cross)
        kill_if("after-manifest-durable", point)
        kill_if("before-head", point)
        fs.head_write(root, next_head,
                      after_swap=lambda: kill_if("after-head", point))
        kill_if("after-head-durable", point)
        refuse(read_head(root, cross, bridge, fs)[2] == after,
               "committed head replay differs from native publisher", cross)
        return next_head


def expect_refusal(action, why: str, cross) -> None:
    try:
        action()
    except (cross.Refused, OSError, ValueError, KeyError, TypeError):
        return
    raise AssertionError("unsafe source accepted: " + why)


def child(root: Path, expected: str, patch_file: Path, point: str) -> None:
    cross, bridge, fs = imports()
    refuse(point in POINTS or point == "", "bad kill point", cross)
    publish(root, expected, patch_file.read_bytes(), point, cross, bridge, fs)


def check() -> dict:
    cross, bridge, fs = imports()
    results = []
    with tempfile.TemporaryDirectory(prefix="loam-native-head-") as temp:
        work = Path(temp)
        native, snapshots = work / "native", work / "snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", native)
        bridge.checked_run(ROOT / "tools" / "NativeCrossFamilyYearSource.lean",
                           native, snapshots)
        before = (snapshots / "before.household.loam").read_bytes()
        after = (snapshots / "after.household.loam").read_bytes()
        patch = cross.encode_patch(before, after, "2027-01-01", bridge)
        candidate = work / "test-only-2027.patch"
        candidate.write_bytes(patch)

        seed = work / "seed"
        initial = bootstrap(seed, before, cross, bridge, fs)
        assert not (seed / "journal" / "2027").exists()
        pre_list = sorted(str(p.relative_to(seed)) for p in seed.rglob("*"))
        assert read_head(seed, cross, bridge, fs)[2] == before
        assert sorted(str(p.relative_to(seed)) for p in seed.rglob("*")) == pre_list

        for index, point in enumerate(POINTS):
            case = work / f"kill-{index}"
            shutil.copytree(seed, case)
            p = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()),
                 "--child", str(case), initial, str(candidate), point],
                capture_output=True, text=True, cwd=ROOT)
            assert p.returncode == -signal.SIGKILL, (point, p.returncode, p.stderr)
            observed, _, wire = read_head(case, cross, bridge, fs)
            committed = POINTS.index(point) >= POINTS.index("after-head")
            assert (wire == after if committed else wire == before), point
            assert (observed != initial) == committed, point

            # Lost success response: independently inspect selected source,
            # then retry same source operation without publishing twice.
            q = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()),
                 "--child", str(case), initial, str(candidate), ""],
                capture_output=True, text=True, cwd=ROOT)
            assert q.returncode == 0, (point, q.stderr)
            final, man, replayed = read_head(case, cross, bridge, fs)
            assert man["ordinal"] == 1 and replayed == after
            assert (case / "journal" / "2026" /
                    man["entries"][0]["hash"]).read_bytes() == before
            publish(case, initial, patch, "", cross, bridge, fs)
            assert read_head(case, cross, bridge, fs)[0] == final
            results.append({"point": point,
                            "selected": "H1" if committed else "H0",
                            "retry": "once"})

        good = work / "good"
        shutil.copytree(seed, good)
        selected = publish(good, initial, patch, "", cross, bridge, fs)
        assert read_head(good, cross, bridge, fs)[2] == after

        # A stale materialized whole image must never override the head.
        (good / "household.loam").write_bytes(before)
        assert read_head(good, cross, bridge, fs)[2] == after
        reconstructed = work / "lean-replay"
        reconstructed.mkdir()
        (reconstructed / "household.loam").write_bytes(
            read_head(good, cross, bridge, fs)[2])
        bridge.checked_run(ROOT / "tools" / "NativeCrossFamilyYearSource.lean",
                           "verify", reconstructed)

        for label, tamper in (
            ("missing-2027", lambda d, m: (d / "journal" / "2027" /
                                          m["entries"][1]["hash"]).unlink()),
            ("corrupt-2026", lambda d, m: (d / "journal" / "2026" /
                                          m["entries"][0]["hash"]).write_bytes(b"bad")),
            ("invalid-manifest", lambda d, m: (d / "manifests" /
                                              selected).write_bytes(b"{}")),
            ("missing-head", lambda d, m: (d / "HEAD").unlink()),
        ):
            root = work / label
            shutil.copytree(good, root)
            tamper(root, read_head(good, cross, bridge, fs)[1])
            expect_refusal(lambda: read_head(root, cross, bridge, fs),
                           label, cross)

        # Stale observed generation is rejected under the same writer lock.
        expect_refusal(lambda: publish(good, "0" * 64, patch, "",
                                      cross, bridge, fs),
                       "wrong old head claimed for existing operation", cross)
        conflicting = patch.replace(b"2027-01-01", b"2027-01-02", 1)
        expect_refusal(lambda: publish(good, initial, conflicting, "",
                                      cross, bridge, fs),
                       "reused operation with differing source", cross)

        # A wholly valid old head can still be selected by a malicious restore.
        # Internal hash integrity does NOT supply anti-rollback freshness.
        rolled = work / "old-but-valid"
        shutil.copytree(good, rolled)
        fs.head_write(rolled, initial)
        assert read_head(rolled, cross, bridge, fs)[2] == before

        assert selected != initial
        return {
            "status": "PASS: research-only native single-head replay at SIGKILL cuts",
            "kill_points": results,
            "source_before_and_after_from_native_Lean": True,
            "byte_exact_actual_and_scheduled_replay": True,
            "missing_corrupt_head_referenced_source_refused": True,
            "stale_materialized_household_ignored": True,
            "no_empty_2027_source_on_idle_read": True,
            "past_2026_source_immutable": True,
            "limitation": (
                "No sudden-power-loss durability, no trusted actual admission-day "
                "clock, no valid-old-head anti-rollback, no 2028 production engine."
            ),
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--child", nargs=4,
                        metavar=("ROOT", "EXPECTED", "PATCH_FILE", "KILL_POINT"))
    args = parser.parse_args()
    if args.child is not None:
        child(Path(args.child[0]), args.child[1], Path(args.child[2]),
              args.child[3])
    elif args.check:
        print(json.dumps(check(), indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
