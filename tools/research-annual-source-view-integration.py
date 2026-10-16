#!/usr/bin/env python3
"""Synthetic annual-source head replay -> native Actual/Scheduled read-view gate.

This exercises a real multi-year immutable journal candidate, as distinct
from merely handing a native whole-image fixture to the parity gate. No
production data, current writer, or read-selection behavior is modified.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NATIVE_VIEW = ROOT / "tools" / "NativeAnnualSourceReadViewProbe.lean"
PACE_SUPPORT = ROOT / "tools" / "NativeAnnualPaceSupportFixture.lean"
PACE_VIEW = ROOT / "tools" / "NativeAnnualPaceReadViewProbe.lean"
QUERY_POLICY_VIEW = ROOT / "tools" / "NativeAnnualQueryPolicyProbe.lean"


def imported(name: str, file: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / file)
    assert spec and spec.loader
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


def check():
    multi = imported("native_multiyear_integration",
                     "research-annual-multiyear-receipts.py")
    clock, single, cross, bridge, fs, actual, delta = env = multi.existing()
    with tempfile.TemporaryDirectory(prefix="loam-annual-source-view-") as tmp:
        work = Path(tmp)
        installed = work / "installed"
        snapshots = work / "snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", installed)
        # The independent zero-origin assertion is installed BEFORE H0.
        # Its exact bytes then survive every year-source delta, not only H3.
        bridge.checked_run(PACE_SUPPORT, installed)
        bridge.checked_run(bridge.NATIVE, "produce", installed, snapshots)
        native_images = [
            (snapshots / f"snapshot-{i}.wire").read_bytes()
            for i in range(4)
        ]
        current_native = (installed / "household.loam").read_bytes()
        assert current_native == native_images[3]

        # The writer/replay is the same Git-independent single-head prototype
        # qualified by #2035, with no source edits to any accepted past year.
        journal = work / "source"
        head = single.bootstrap(journal, native_images[0], cross, bridge, fs)
        previously_selected = [head]
        for idx, (op, when) in enumerate((
            ("movement-2027", "2026-12-31T15:00:01+00:00"),
            ("correction-2027", "2027-07-01T01:00:00+00:00"),
            ("validity-2028", "2027-12-31T15:00:01+00:00"),
        ), start=1):
            instant = multi.utc(when)
            head = multi.publish(
                journal, head, op, native_images[idx - 1],
                native_images[idx], clock.Clock(instant, instant), env
            )
            previously_selected.append(head)
            assert multi.read(journal, env)[2] == native_images[idx]

        # The reader pins one committed HEAD with complete closed predecessors.
        selected, manifest, candidate, _, _ = multi.read(journal, env)
        assert selected == head and manifest["ordinal"] == 3
        assert manifest["accepted_day"] == "2028-01-01"
        assert candidate == native_images[3]
        candidate_path = work / "materialized-from-annual-head.household.loam"
        candidate_path.write_bytes(candidate)

        def native(mode: str, candidate_file: Path):
            bridge.checked_run(NATIVE_VIEW, mode, installed, candidate_file)
            assert (installed / "household.loam").read_bytes() == current_native

        # A real head-reconstructed image now flows through the Lean read view.
        # It must match BOTH existing Actual and Scheduled native reader answers.
        native("match", candidate_path)
        bridge.checked_run(PACE_VIEW, "match", installed, candidate_path)
        bridge.checked_run(QUERY_POLICY_VIEW, "match", installed, candidate_path)
        assert (installed / "household.loam").read_bytes() == current_native

        # A perfectly well-formed older selected head is NOT current.
        # Current installed-source parity refuses it without trusting its year.
        fs.head_write(journal, previously_selected[1])
        old_candidate = work / "older-valid-source.household.loam"
        old_candidate.write_bytes(multi.read(journal, env)[2])
        native("refuse", old_candidate)
        bridge.checked_run(PACE_VIEW, "refuse", installed, old_candidate)
        bridge.checked_run(QUERY_POLICY_VIEW, "refuse", installed, old_candidate)
        fs.head_write(journal, head)

        # A missing middle-year source cannot be elided to fabricate 2028.
        broken = work / "missing-middle-2027"
        shutil.copytree(journal, broken)
        middle = multi.reassemble(journal, previously_selected[2], env)[0]
        missing = broken / "journal" / "2027" / middle["source"]["hash"]
        missing.unlink()
        multi.reject(lambda: multi.read(broken, env),
                     "2028 read with missing 2027 correction", cross)

        # A whole-image parser could admit absent optional families, but the
        # native read view must reject an absent required Actual or Scheduled.
        sections = bridge.parse_wire(candidate)
        for family in ("Actual", "Scheduled"):
            altered = work / f"missing-{family}.household.loam"
            altered.write_bytes(bridge.encode([
                (name, body) for name, body in sections if name != family
            ]))
            native("refuse", altered)

        assert (installed / "household.loam").read_bytes() == current_native
        assert candidate_path.read_bytes() == candidate
        return {
            "status": "PASS: annual source HEAD replay to native Actual+Scheduled read view",
            "year_source_ordinals": [1, 2, 3],
            "source_years": [2027, 2027, 2028],
            "native_current_parity": True,
            "actual_and_scheduled_same_generation": True,
            "current_quantity_support_same_generation": True,
            "explicit_current_truth_pace_parity": True,
            "exact_query_policy_bytes_pinned": True,
            "external_policy_change_visible_not_history": True,
            "pension_cycle_crosses_Jan_1": True,
            "unknown_origin_not_zero": True,
            "valid_older_selected_head_refused": True,
            "missing_2027_predecessor_refused": True,
            "missing_Actual_or_Scheduled_refused": True,
            "installed_household_unchanged": True,
            "limits": (
                "Only three Actual-only source publications plus native retained "
                "Scheduled. Separate #2033 proves paired Actual+Scheduled change. "
                "Injected clock, synthetic data and full replay, not installed "
                "production source years, trusted clock, power-loss proof, "
                "valid head rollback detection, or selective read."
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
