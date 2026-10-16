#!/usr/bin/env python3
"""Read-only cutover preflight against current native HouseholdAuthority.

Synthetic Lean-published images only; this does not select, install or promote
an annual journal. All candidate and current files live under TemporaryDirectory.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "tools" / "NativeAnnualMaterializationPreflight.lean"


def existing():
    spec = importlib.util.spec_from_file_location(
        "native_annual_parity_bridge",
        ROOT / "tools" / "research-native-annual-section-bridge.py"
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check():
    bridge = existing()
    with tempfile.TemporaryDirectory(prefix="loam-native-parity-") as tmp:
        work = Path(tmp)
        household = work / "household"
        snapshots = work / "snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", household)
        bridge.checked_run(bridge.NATIVE, "produce", household, snapshots)
        final = snapshots / "snapshot-3.wire"
        prior = snapshots / "snapshot-2.wire"
        original = (household / "household.loam").read_bytes()
        assert original == final.read_bytes()

        def run(mode: str, path: Path):
            bridge.checked_run(CHECKER, mode, household, path)
            assert (household / "household.loam").read_bytes() == original

        run("match", final)
        run("refuse", prior)

        parts = bridge.parse_wire(original)
        assert "CustomEvidence" in dict(parts)
        assert "Scheduled" in dict(parts)
        assert "Actual" in dict(parts)

        variations = {
            "changed-unknown": [
                (name, body + "DIFFERENT" if name == "CustomEvidence" else body)
                for name, body in parts
            ],
            "missing-unknown": [
                (name, body) for name, body in parts
                if name != "CustomEvidence"
            ],
            "missing-scheduled": [
                (name, body) for name, body in parts
                if name != "Scheduled"
            ],
            "malformed-scheduled": [
                (name, "NOT-A-SCHEDULED-IMAGE\n" if name == "Scheduled" else body)
                for name, body in parts
            ],
        }
        for label, payload in variations.items():
            candidate = work / (label + ".household.loam")
            candidate.write_bytes(bridge.encode(payload))
            run("refuse", candidate)

        return {
            "status": "PASS: current native authority parity is read-only and exact",
            "native_generations": 4,
            "accepted_exact_current": True,
            "refused_previous_valid_generation": True,
            "refused_unknown_section_mutation_and_absence": True,
            "refused_scheduled_absence_and_invalid_codec": True,
            "installed_source_unchanged": True,
            "limits": (
                "Candidate bytes from synthetic fixture, not an installed annual "
                "authority. Current household.loam stays the sole source. "
                "No migration, two-head coordination, durability, trusted-time "
                "or source-history freshness guarantee."
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
