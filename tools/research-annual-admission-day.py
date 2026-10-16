#!/usr/bin/env python3
"""Controlled admission-day receipt experiment over REAL native LOAM source.

Research-only: uses existing disposable native Scheduled+Actual H0/H1 fixture,
a single selected source HEAD and injected aware instants. No wall-clock
authority, production publisher, source migration or as-known financial view.

The accepted UTC instant is the final pre-HEAD *logical admission cut*.
This cannot prove the wall-clock date of a later physical rename or power loss.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ROOT = Path(__file__).resolve().parents[1]
TZ = "Asia/Tokyo"
OP = "scheduled-completion:first"
RECEIPT_KEYS = {
    "version", "previous", "ordinal", "operation", "time_zone",
    "accepted_at_utc", "accepted_day", "source",
    "before_sha256", "after_sha256",
}
SOURCE_KEYS = {"year", "seq", "kind", "hash"}


def existing():
    spec = importlib.util.spec_from_file_location(
        "loam_single_head_native", ROOT / "tools" /
        "research-annual-single-head-native.py"
    )
    assert spec and spec.loader
    single = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(single)
    cross, bridge, fs = single.imports()
    return single, cross, bridge, fs


def need(ok: bool, reason: str, cross) -> None:
    if not ok:
        raise cross.Refused(reason)


def aware_utc(instant: datetime, cross) -> datetime:
    need(isinstance(instant, datetime) and instant.tzinfo is not None and
         instant.utcoffset() is not None, "admission clock must be offset-aware", cross)
    return instant.astimezone(timezone.utc)


def local_day(instant: datetime, zone: str, cross) -> str:
    try:
        zone_info = ZoneInfo(zone)
    except (ZoneInfoNotFoundError, TypeError, ValueError) as exc:
        raise cross.Refused("unqualified IANA household timezone") from exc
    return aware_utc(instant, cross).astimezone(zone_info).date().isoformat()


def stamp(instant: datetime, cross) -> str:
    return aware_utc(instant, cross).isoformat(timespec="microseconds").replace("+00:00", "Z")


def parse_stamp(source: str, cross) -> datetime:
    need(isinstance(source, str) and source.endswith("Z"),
         "noncanonical accepted UTC instant", cross)
    try:
        parsed = datetime.fromisoformat(source[:-1] + "+00:00")
    except ValueError as exc:
        raise cross.Refused("invalid accepted UTC instant") from exc
    need(stamp(parsed, cross) == source, "noncanonical accepted UTC instant", cross)
    return parsed


def source_manifest(root: Path, ident: str, fs, cross) -> dict:
    need(isinstance(ident, str) and bool(fs.HASH.fullmatch(ident)),
         "invalid selected head", cross)
    raw = (root / "manifests" / ident).read_bytes()
    need(fs.digest(raw) == ident, "manifest digest does not match selected head", cross)
    man = json.loads(raw)
    need(isinstance(man, dict), "manifest is not an object", cross)
    return man


def read(root: Path, single, cross, bridge, fs):
    """Never trust effective date, filename alone, other years, or cache."""
    try:
        txt = (root / "HEAD").read_text(encoding="ascii")
        need(txt.endswith("\n") and bool(fs.HASH.fullmatch(txt[:-1])),
             "missing/corrupt HEAD", cross)
        selected = txt[:-1]
        man = source_manifest(root, selected, fs, cross)
        if man.get("version") == 1:
            h, initial, wire = single.read_head(root, cross, bridge, fs)
            need(h == selected and initial["ordinal"] == 0,
                 "invalid initial selected source", cross)
            return selected, initial, wire
        need(set(man) == RECEIPT_KEYS and man["version"] == 2 and
             type(man["ordinal"]) is int and man["ordinal"] == 1 and
             man["operation"] == OP and man["time_zone"] == TZ and
             type(man["accepted_day"]) is str,
             "invalid receipt structure / timezone / ordering", cross)
        previous = man["previous"]
        need(isinstance(previous, str) and selected != previous,
             "invalid previous source head", cross)
        earlier, before = single.replay_head(root, previous, cross, bridge, fs)
        need(earlier["ordinal"] == 0 and earlier["previous"] is None,
             "broken previous source chain", cross)
        accepted = parse_stamp(man["accepted_at_utc"], cross)
        day = local_day(accepted, man["time_zone"], cross)
        need(day == man["accepted_day"], "admission day not determined by UTC+zone", cross)
        src = man["source"]
        need(isinstance(src, dict) and set(src) == SOURCE_KEYS and
             type(src["year"]) is int and src["year"] == accepted.astimezone(
                 ZoneInfo(man["time_zone"])).year and
             type(src["seq"]) is int and src["seq"] == 2 and
             src["kind"] == "sections" and
             isinstance(src["hash"], str) and bool(fs.HASH.fullmatch(src["hash"])),
             "publication-year source identity is invalid", cross)
        need(fs.digest(before) == man["before_sha256"],
             "wrong predecessor HouseholdImage hash", cross)
        patch = (root / "journal" / str(src["year"]) / src["hash"]).read_bytes()
        need(fs.digest(patch) == src["hash"], "corrupt source bytes", cross)
        after, patch_day = cross.apply_patch(before, patch, bridge)
        need(patch_day == day and fs.digest(after) == man["after_sha256"],
             "source day or full native image hash disagrees with receipt", cross)
        return selected, man, after
    except (OSError, KeyError, ValueError, TypeError, UnicodeError) as exc:
        raise cross.Refused("unavailable or invalid selected source receipt") from exc


def prepared(root: Path, original: str, before: bytes, after: bytes,
             when: datetime, zone: str, single, cross, bridge, fs) -> str:
    day = local_day(when, zone, cross)
    patch = cross.encode_patch(before, after, day, bridge)
    source_year = int(day[:4])
    year_dir = root / "journal" / str(source_year)
    year_dir.mkdir(exist_ok=True)
    fs.sync_dir(root / "journal")
    blob = fs.store_immutable(year_dir, patch)
    receipt = {
        "version": 2, "previous": original, "ordinal": 1, "operation": OP,
        "time_zone": zone, "accepted_at_utc": stamp(when, cross),
        "accepted_day": day,
        "source": {"year": source_year, "seq": 2, "kind": "sections", "hash": blob},
        "before_sha256": fs.digest(before), "after_sha256": fs.digest(after),
    }
    candidate = fs.store_immutable(root / "manifests", fs.canonical(receipt))
    # Validate the exact as-yet-unselected candidate with the same read rules.
    # The head is not promoted until after the candidate is fully qualified.
    recovered = candidate_wire(root, candidate, single, cross, bridge, fs)
    need(recovered == after, "inconsistent staged source receipt", cross)
    return candidate


def candidate_wire(root: Path, candidate: str, single, cross, bridge, fs) -> bytes:
    """Research candidate reader: temporarily select in an isolated cloned root.

    To avoid a competing canonical selector, qualification can instead use the
    same strict read on a *disposable clone*, never the original HEAD.
    """
    import os
    from pathlib import Path
    # This clone is intentionally read-only against the caller's original;
    # data is small synthetic-only and benchmark claims are NOT made.
    with tempfile.TemporaryDirectory(prefix="loam-admission-candidate-") as tmp:
        temp_root = Path(tmp) / "source"
        shutil.copytree(root, temp_root)
        fs.head_write(temp_root, candidate)
        return read(temp_root, single, cross, bridge, fs)[2]


def publish(root: Path, expected: str, before: bytes, after: bytes,
            clock, single, cross, bridge, fs, zone: str = TZ) -> str:
    need((root / ".test-only-single-head").read_text("ascii") == single.MARKER,
         "not a research-only household", cross)
    with fs.writer_lock(root):
        current, man, existing = read(root, single, cross, bridge, fs)
        # An acknowledged or ambiguous successful retry performs NO clock read
        # and creates NO second knowledge-day or journal generation.
        if man.get("version") == 2 and man["operation"] == OP:
            need(man["previous"] == expected and existing == after,
                 "conflicting already-applied source operation", cross)
            return current
        need(current == expected and existing == before and man["ordinal"] == 0,
             "stale source or unqualified baseline", cross)
        need(zone == TZ, "unauthorized household time-zone change", cross)
        first = aware_utc(clock(), cross)
        # Staging may span midnight. This first receipt is not yet accepted.
        prepared(root, current, before, after, first, zone,
                 single, cross, bridge, fs)
        final = aware_utc(clock(), cross)
        need(final >= first, "UTC admission clock moved backwards", cross)
        # Rebuild with the FINAL observed cut, even for same-day instants;
        # the first source/manifest objects are harmless invisible orphans.
        qualified_head = prepared(root, current, before, after, final, zone,
                                  single, cross, bridge, fs)
        # This physical switch is the single visible head. The sampled
        # instant is a *logical cut immediately before the swap*, not proof
        # of wall-clock completion time after the swap.
        fs.head_write(root, qualified_head)
        selected, receipt, rebuilt = read(root, single, cross, bridge, fs)
        need(selected == qualified_head and rebuilt == after and
             receipt["accepted_at_utc"] == stamp(final, cross),
             "accepted head does not contain sampled admission cut", cross)
        return selected


class Clock:
    def __init__(self, *times: datetime):
        self.times = iter(times)
        self.reads = 0

    def __call__(self):
        self.reads += 1
        return next(self.times)


def iso(s: str) -> datetime:
    return datetime.fromisoformat(s)


def expect_refuse(action, cross, description: str) -> None:
    try:
        action()
    except cross.Refused:
        return
    raise AssertionError("unsafe clock admission: " + description)


def check():
    single, cross, bridge, fs = existing()
    scenarios = []
    with tempfile.TemporaryDirectory(prefix="loam-annual-clock-receipt-") as workdir:
        base = Path(workdir)
        native, outputs = base / "native", base / "native-snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", native)
        bridge.checked_run(ROOT / "tools" / "NativeCrossFamilyYearSource.lean",
                           native, outputs)
        before = (outputs / "before.household.loam").read_bytes()
        after = (outputs / "after.household.loam").read_bytes()
        seed = base / "seed"
        initial = single.bootstrap(seed, before, cross, bridge, fs)

        def case(name: str, clock: Clock, want_day: str):
            target = base / name
            shutil.copytree(seed, target)
            selected = publish(target, initial, before, after, clock,
                               single, cross, bridge, fs)
            head, man, rebuilt = read(target, single, cross, bridge, fs)
            assert head == selected and rebuilt == after
            assert man["accepted_day"] == want_day
            assert man["source"]["year"] == int(want_day[:4])
            assert (target / "journal" / "2026" /
                    read(seed, single, cross, bridge, fs)[1]["entries"][0]["hash"]
                    ).read_bytes() == before
            return target, man

        # Effective Scheduled day is 2026-11-08. It must NOT determine
        # the source year. 2026-12-31 15:00 UTC = 2027-01-01 00:00 JST.
        rollover_clock = Clock(
            iso("2026-12-31T14:59:59+00:00"),
            iso("2026-12-31T15:00:00+00:00"),
        )
        rolled, man = case("rollover", rollover_clock, "2027-01-01")
        assert (rolled / "journal" / "2026").exists()
        assert man["source"]["year"] == 2027
        assert (rolled / "journal" / "2027" / man["source"]["hash"]).exists()
        assert rollover_clock.reads == 2
        scenarios.append("JST midnight during preparation -> new year, not effective year")

        # Midnight in UTC is NOT necessarily midnight in the household zone.
        _, same = case("utc-midnight", Clock(
            iso("2026-12-30T23:59:59+00:00"),
            iso("2026-12-31T00:00:00+00:00"),
        ), "2026-12-31")
        assert same["source"]["year"] == 2026
        scenarios.append("UTC boundary without local-day change -> same local year")

        _, later = case("late-first-admission", Clock(
            iso("2027-01-02T15:30:00+00:00"),
            iso("2027-01-02T16:00:00+00:00"),
        ), "2027-01-03")
        assert later["ordinal"] == 1
        scenarios.append("first use Jan 3 creates no preceding empty year")

        # Retrying after a lost acknowledgement must not read a changed clock.
        no_more_clock = Clock()
        previous, _, _ = read(rolled, single, cross, bridge, fs)
        retry = publish(rolled, initial, before, after, no_more_clock,
                        single, cross, bridge, fs)
        assert retry == previous and no_more_clock.reads == 0
        scenarios.append("committed retry leaves accepted day/ordinal untouched")

        for label, clock in (
            ("rollback", Clock(iso("2027-01-02T00:00:00+00:00"),
                               iso("2027-01-01T23:00:00+00:00"))),
            ("naive", Clock(iso("2026-12-31T12:00:00"),
                            iso("2026-12-31T15:00:00+00:00"))),
        ):
            candidate_root = base / label
            shutil.copytree(seed, candidate_root)
            expect_refuse(lambda: publish(candidate_root, initial, before, after,
                                          clock, single, cross, bridge, fs),
                          cross, label)
            assert read(candidate_root, single, cross, bridge, fs)[0] == initial
        scenarios.append("clock regression/naive time refused without head promotion")

        wrong_zone = base / "wrong-zone"
        shutil.copytree(seed, wrong_zone)
        expect_refuse(lambda: publish(
            wrong_zone, initial, before, after,
            Clock(iso("2026-12-31T15:00:00+00:00")),
            single, cross, bridge, fs, zone="UTC"), cross,
            "unauthorized time-zone change")
        assert read(wrong_zone, single, cross, bridge, fs)[0] == initial

        # A self-consistently re-hashed manifest with an incorrect day
        # remains INVALID; hashes alone are not a calendar-day rule.
        for label, rewrite in (
            ("forged-local-day", lambda m: m.update(accepted_day="2026-12-31")),
            ("forged-time-zone", lambda m: m.update(time_zone="UTC")),
            ("wrong-year-object", lambda m: m["source"].update(year=2026)),
            ("reordered-ordinal", lambda m: m.update(ordinal=2)),
        ):
            target = base / label
            shutil.copytree(rolled, target)
            forged = json.loads(json.dumps(man))
            rewrite(forged)
            forged_head = fs.store_immutable(target / "manifests", fs.canonical(forged))
            fs.head_write(target, forged_head)
            expect_refuse(lambda: read(target, single, cross, bridge, fs),
                          cross, label)
        scenarios.append("wrong accepted day/zone/year/ordinal refused even with valid manifest hash")

        # Full native re-admission after the research receipt's replay.
        qualified = base / "native-reconstructed"
        qualified.mkdir()
        (qualified / "household.loam").write_bytes(
            read(rolled, single, cross, bridge, fs)[2])
        bridge.checked_run(ROOT / "tools" / "NativeCrossFamilyYearSource.lean",
                           "verify", qualified)
        assert read(seed, single, cross, bridge, fs)[0] == initial

        return {
            "status": "PASS: controlled annual admission-day receipt over native source",
            "scenarios": scenarios,
            "cross_family_native_replay": True,
            "unchanged_original_baseline": True,
            "limitations": (
                "Synthetic injected clock only; final pre-head logical cut is "
                "not independently trusted time or physical commit instant. "
                "No cross-generation clock anti-rollback, power-loss proof, "
                "multi-year generalized writer or production migration."
            ),
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        parser.print_help()
    else:
        print(json.dumps(check(), indent=2))


if __name__ == "__main__":
    main()
