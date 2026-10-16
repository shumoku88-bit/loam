#!/usr/bin/env python3
"""Research: repeatable multi-year single-head native source receipts.

Reuses FOUR real Lean-accepted HouseholdImage generations:
  2026 synthetic baseline, 2027 Actual add + correction, 2028 date revision.
Retained admission timestamps and source paths are independent of effective dates.
Prior source objects are immutable, all referenced history is closed on read.

This is a disposable injected-clock witness, not a production journal format,
real clock authority, selective reader, power-loss proof or rollback anchor.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEYS = {
    "version", "previous", "ordinal", "operation", "time_zone",
    "accepted_at_utc", "accepted_day", "source", "before_sha256", "after_sha256",
}
SRC_KEYS = {"year", "seq", "kind", "hash"}
LIMIT = 16


def existing():
    spec = importlib.util.spec_from_file_location(
        "loam_admission_day", ROOT / "tools" / "research-annual-admission-day.py"
    )
    assert spec and spec.loader
    clock = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(clock)
    single, cross, bridge, fs = clock.existing()
    spec2 = importlib.util.spec_from_file_location(
        "loam_year_source_actual",
        ROOT / "tools" / "research-tackler-git-source-year.py"
    )
    assert spec2 and spec2.loader
    actual = importlib.util.module_from_spec(spec2)
    spec2.loader.exec_module(actual)
    delta = actual.imported("loam_actual_delta_for_multiyear",
                            "research-native-actual-publication-delta.py")
    return clock, single, cross, bridge, fs, actual, delta


def need(ok: bool, reason: str, cross) -> None:
    if not ok:
        raise cross.Refused(reason)


def reassemble(root: Path, identity: str, env, seen=frozenset()):
    """Read exactly the pinned predecessor chain, never unselected files."""
    clock, single, cross, bridge, fs, actual, delta = env
    need(isinstance(identity, str) and bool(fs.HASH.fullmatch(identity)),
         "invalid head identity", cross)
    need(identity not in seen and len(seen) < LIMIT,
         "cycle or unsupported history depth", cross)
    man = clock.source_manifest(root, identity, fs, cross)
    if man.get("version") == 1:
        initial, wire = single.replay_head(root, identity, cross, bridge, fs)
        need(initial == man and initial["ordinal"] == 0 and
             initial["previous"] is None and
             initial["operation"] == "initial-synthetic-2026" and
             len(initial["entries"]) == 1 and
             initial["entries"][0]["year"] == 2026,
             "unqualified pre-cutover baseline", cross)
        return man, wire, ("initial-synthetic-2026",), None

    need(set(man) == KEYS and man["version"] == 3 and
         type(man["ordinal"]) is int and man["ordinal"] >= 1 and
         isinstance(man["operation"], str) and bool(man["operation"]) and
         man["time_zone"] == clock.TZ and
         isinstance(man["previous"], str),
         "unsupported receipt or missing predecessor", cross)
    prev, before, operations, last_instant = reassemble(
        root, man["previous"], env, seen | {identity}
    )
    need(man["ordinal"] == prev["ordinal"] + 1 and
         man["operation"] not in operations,
         "skipped ordinal or duplicate operation identity", cross)

    instant = clock.parse_stamp(man["accepted_at_utc"], cross)
    day = clock.local_day(instant, man["time_zone"], cross)
    need(day == man["accepted_day"], "receipt date not derived from UTC+zone", cross)
    need(last_instant is None or instant >= last_instant,
         "accepted clock reversed relative to committed predecessor", cross)
    source = man["source"]
    need(isinstance(source, dict) and set(source) == SRC_KEYS and
         type(source["year"]) is int and
         source["year"] == int(day[:4]) and
         type(source["seq"]) is int and source["seq"] == man["ordinal"] + 1 and
         source["kind"] == "actual-patch" and
         isinstance(source["hash"], str) and
         bool(fs.HASH.fullmatch(source["hash"])),
         "incorrect source year or ordinal path", cross)

    need(fs.digest(before) == man["before_sha256"],
         "native source prefix does not match predecessor", cross)
    patch = (root / "journal" / str(source["year"]) / source["hash"]).read_bytes()
    need(fs.digest(patch) == source["hash"], "missing/corrupt source blob", cross)
    after, declared_day = actual.apply_patch(before, patch, delta, bridge)
    need(declared_day == day and fs.digest(after) == man["after_sha256"],
         "native replay does not match accepted receipt", cross)
    need(bridge.encode(bridge.parse_wire(after)) == after,
         "replayed HouseholdImage not byte-exact", cross)
    return man, after, operations + (man["operation"],), instant


def read(root: Path, env):
    _, _, cross, _, fs, _, _ = env
    try:
        selected = (root / "HEAD").read_text("ascii")
        need(selected.endswith("\n") and bool(fs.HASH.fullmatch(selected[:-1])),
             "bad selected head", cross)
        h = selected[:-1]
        return (h, *reassemble(root, h, env))
    except (OSError, ValueError, TypeError, KeyError, UnicodeError, RecursionError) as exc:
        raise cross.Refused("incomplete/invalid committed history") from exc


def stage(root: Path, expected: str, ordinal: int, operation: str,
          before: bytes, after: bytes, instant, env) -> str:
    clock, _, cross, bridge, fs, actual, delta = env
    day = clock.local_day(instant, clock.TZ, cross)
    payload = actual.patch_for(before, after, day, delta, bridge)
    year = int(day[:4])
    folder = root / "journal" / str(year)
    folder.mkdir(exist_ok=True)
    fs.sync_dir(root / "journal")
    object_hash = fs.store_immutable(folder, payload)
    receipt = {
        "version": 3, "previous": expected, "ordinal": ordinal,
        "operation": operation, "time_zone": clock.TZ,
        "accepted_at_utc": clock.stamp(instant, cross), "accepted_day": day,
        "source": {"year": year, "seq": ordinal + 1,
                   "kind": "actual-patch", "hash": object_hash},
        "before_sha256": fs.digest(before),
        "after_sha256": fs.digest(after),
    }
    head = fs.store_immutable(root / "manifests", fs.canonical(receipt))
    # Prove all immutable predecessors and this staged candidate reconstruct
    # the full real native image BEFORE selecting any new authoritative HEAD.
    qualified, rebuilt, _, _ = reassemble(root, head, env)
    need(qualified == receipt and rebuilt == after,
         "staged candidate invalid", cross)
    return head


def publish(root: Path, expected: str, operation: str,
            expected_before: bytes, expected_after: bytes, injected_clock, env):
    clock, single, cross, _, fs, _, _ = env
    need((root / ".test-only-single-head").read_text("ascii") == single.MARKER,
         "not a disposable research root", cross)
    with fs.writer_lock(root):
        old, man, before, ops, latest_instant = read(root, env)
        if operation in ops:
            need(man.get("operation") == operation and
                 man.get("previous") == expected and before == expected_after,
                 "conflicting or historical already-published operation", cross)
            return old  # lost success acknowledgement: no clock read/new source
        need(old == expected and before == expected_before,
             "stale observed head or non-native proposal", cross)
        candidate_time = clock.aware_utc(injected_clock(), cross)
        result = None
        for _ in range(4):
            need(latest_instant is None or candidate_time >= latest_instant,
                 "admission timestamp predates last accepted source", cross)
            prepared = stage(root, old, man["ordinal"] + 1, operation,
                             before, expected_after, candidate_time, env)
            verified_time = clock.aware_utc(injected_clock(), cross)
            need(verified_time >= candidate_time,
                 "intra-publication clock reversal", cross)
            if clock.local_day(verified_time, clock.TZ, cross) == clock.local_day(
                    candidate_time, clock.TZ, cross):
                result = prepared
                break
            candidate_time = verified_time
        need(result is not None, "unstable day across repeated staging", cross)
        fs.head_write(root, result)
        selected, _, reconstructed, _, _ = read(root, env)
        need(selected == result and reconstructed == expected_after,
             "selected native image changed", cross)
        return selected


def reject(fn, reason: str, cross):
    try:
        fn()
    except cross.Refused:
        return
    raise AssertionError("unsafe acceptance: " + reason)


def utc(s: str):
    from datetime import datetime
    return datetime.fromisoformat(s)


def check():
    env = existing()
    clock, single, cross, bridge, fs, actual, delta = env
    with tempfile.TemporaryDirectory(prefix="loam-source-multiyear-") as tmp:
        work = Path(tmp)
        native, snapshots = work / "native", work / "snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", native)
        bridge.checked_run(bridge.NATIVE, "produce", native, snapshots)
        images = [(snapshots / f"snapshot-{i}.wire").read_bytes() for i in range(4)]
        for raw in images:
            assert bridge.encode(bridge.parse_wire(raw)) == raw
        seed = work / "seed"
        genesis = single.bootstrap(seed, images[0], cross, bridge, fs)
        assert not (seed / "journal" / "2027").exists()
        head = genesis
        current = seed
        accepted = []
        tests = [
            ("movement-2027", (utc("2026-12-31T14:59:59+00:00"),
                               utc("2026-12-31T15:00:00+00:00"),
                               utc("2026-12-31T15:00:01+00:00")), "2027-01-01"),
            ("correction-2027", (utc("2027-07-01T01:00:00+00:00"),
                                 utc("2027-07-01T01:00:02+00:00")), "2027-07-01"),
            ("validity-2028", (utc("2027-12-31T14:59:59+00:00"),
                               utc("2027-12-31T15:00:00+00:00"),
                               utc("2027-12-31T15:00:01+00:00")), "2028-01-01"),
        ]

        for ordinal, (op, times, expected_day) in enumerate(tests, 1):
            root = work / f"generation-{ordinal}"
            shutil.copytree(current, root)
            if ordinal == 3:
                assert not (root / "journal" / "2028").exists()
            observed = clock.Clock(*times)
            new = publish(root, head, op, images[ordinal - 1],
                          images[ordinal], observed, env)
            selected, man, restored, ops, _ = read(root, env)
            assert selected == new and restored == images[ordinal]
            assert man["accepted_day"] == expected_day
            assert man["source"]["year"] == int(expected_day[:4])
            assert man["ordinal"] == ordinal and len(ops) == ordinal + 1
            assert observed.reads == len(times)
            # Full valid predecessor remains independently retrievable.
            assert reassemble(root, head, env)[1] == images[ordinal - 1]
            assert (root / "journal" / "2026" /
                    read(seed, env)[1]["entries"][0]["hash"]).read_bytes() == images[0]
            again = clock.Clock()
            assert publish(root, head, op, images[ordinal - 1],
                           images[ordinal], again, env) == new and again.reads == 0
            accepted.append((new, man, expected_day))
            current, head = root, new

        assert [x[1]["source"]["year"] for x in accepted] == [2027, 2027, 2028]
        assert [x[1]["ordinal"] for x in accepted] == [1, 2, 3]
        assert not (current / "journal" / "2029").exists()
        assert read(current, env)[2] == images[3]
        assert not (current / "journal" / "2029").exists()

        # Full current image re-admitted by native Lean reader, including the
        # unchanged Scheduled frontier and final Actual validity winner.
        recovered = work / "native-recovered"
        recovered.mkdir()
        (recovered / "household.loam").write_bytes(read(current, env)[2])
        bridge.checked_run(bridge.NATIVE, "verify", recovered)

        # A 2028 head must never answer from a partial 2027 predecessor chain.
        corrupted = work / "missing-2027"
        shutil.copytree(current, corrupted)
        previous_manifest = accepted[1][1]
        missing = (corrupted / "journal" / "2027" /
                   previous_manifest["source"]["hash"])
        missing.unlink()
        reject(lambda: read(corrupted, env), "missing 2027 predecessor", cross)

        # Forging a well-hashed head is insufficient to rewrite calendar-year
        # admission, ordinal or predecessor-chain continuity.
        for label, alter in (
            ("wrong-source-year", lambda m: m["source"].update(year=2027)),
            ("regressed-day", lambda m: m.update(accepted_day="2027-12-31")),
            ("skipped-ordinal", lambda m: m.update(ordinal=9)),
            ("reparented", lambda m: m.update(previous=genesis)),
        ):
            target = work / label
            shutil.copytree(current, target)
            modified = json.loads(json.dumps(accepted[-1][1]))
            alter(modified)
            fake = fs.store_immutable(target / "manifests", fs.canonical(modified))
            fs.head_write(target, fake)
            reject(lambda: read(target, env), label, cross)

        # A separate write with an earlier UTC instant than the accepted 2027
        # correction cannot become the next valid publication.
        older = work / "reversed-clock"
        shutil.copytree(work / "generation-2", older)
        earlier_clock = clock.Clock(utc("2027-01-02T00:00:00+00:00"))
        reject(lambda: publish(
            older, accepted[1][0], "validity-2028",
            images[2], images[3], earlier_clock, env
        ), "cross-generation clock regression", cross)
        assert read(older, env)[0] == accepted[1][0]

        stale = work / "stale-writer"
        shutil.copytree(current, stale)
        reject(lambda: publish(stale, genesis, "another-change",
                               images[0], images[3], clock.Clock(), env),
               "stale observed head", cross)

        # Untrusted all-history rollback remains possible with internal
        # content hashes alone; never claim its detection as a passed gate.
        rolled_back = work / "old-valid-head"
        shutil.copytree(current, rolled_back)
        fs.head_write(rolled_back, accepted[0][0])
        assert read(rolled_back, env)[2] == images[1]

        return {
            "status": "PASS: native receipts across repeatable 2026/2027/2028 head chain",
            "native_generations": 4,
            "committed_ordinals": [x[1]["ordinal"] for x in accepted],
            "source_years": [x[1]["source"]["year"] for x in accepted],
            "admitted_days": [x[2] for x in accepted],
            "full_native_replay_verified": True,
            "missing_intermediate_predecessor_refused": True,
            "forged_valid_hash_receipts_refused": True,
            "clock_regression_and_stale_writes_refused": True,
            "no_idle_year_journal": True,
            "valid_old_head_rollback_detected": False,
            "limitations": (
                "Injected clock + Actual-only native deltas, not production. "
                "Paired Actual+Scheduled is tested separately by #2033. "
                "No physical switch instant, power-loss guarantee, trusted "
                "anti-rollback clock or lazy historical query."
            ),
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        print(json.dumps(check(), indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
