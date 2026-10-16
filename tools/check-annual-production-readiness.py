#!/usr/bin/env python3
"""Fail-closed inventory of #2030 annual CANONICAL cutover prerequisites.

This is a non-mutating, static readiness report. It validates a deliberately
reviewed evidence ledger and current source-owner facts; it cannot prove a
future implementation from a filename or a manually checked box.

Normal --check succeeding means the inventory is coherent, NOT that annual
source publication is safe to enable. --require-ready is intentionally
nonzero while the declared product gates remain blocked.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "tools" / "annual-production-readiness.json"
SOURCE_OWNER = ROOT / "Loam" / "Authority" / "HouseholdAuthority.lean"
SCOPE_IDS = {
    "current": {"current-engine-jan1"},
    "research": {
        "single-head-sigkill", "repeat-2028", "native-view-parity",
        "explicit-query-policy",
    },
    "cutover": {
        "one-production-head", "production-admission-clock",
        "all-family-source-publication", "filesystem-power-loss",
        "recovery-freshness", "native-reader-restore",
        "configuration-coherence", "migration-and-backup",
        "production-pty-acceptance", "bounded-performance",
        "derived-git-tackler",
    },
}
STATES = {
    "current": {"qualified_existing_engine"},
    "research": {"qualified_synthetic_only"},
    "cutover": {"blocked", "qualified_product"},
}
GATE_FIELDS = {"id", "scope", "status", "evidence", "next"}
ROOT_FIELDS = {
    "schema", "tracking_issue", "observed_authority",
    "note", "production_cutover_enabled", "gates",
}


class InvalidReadiness(ValueError):
    pass


def demand(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidReadiness(message)


def evaluate(data: dict, root: Path) -> dict:
    """Validate exact metadata without treating evidence paths as proof."""
    demand(type(data) is dict and set(data) == ROOT_FIELDS,
           "readiness ledger schema mismatch")
    demand(data["schema"] == 1 and type(data["schema"]) is int,
           "unsupported annual-readiness schema version")
    demand(data["tracking_issue"] == 2030 and
           type(data["tracking_issue"]) is int,
           "ledger must track the authoritative annual issue")
    demand(data["observed_authority"] == "household.loam",
           "canonical authority changed: audit production before proceeding")
    demand(type(data["production_cutover_enabled"]) is bool,
           "cutover enabled marker must be boolean")
    demand(type(data["note"]) is str and bool(data["note"]),
           "missing explicit limits of machine-readiness claims")
    demand(type(data["gates"]) is list, "gates not an array")

    current_source = root / "Loam" / "Authority" / "HouseholdAuthority.lean"
    demand(current_source.is_file(), "current production source owner not found")
    source_text = current_source.read_text("utf-8")
    demand('def fileName : String := "household.loam"' in source_text and
           "def publishObserved?" in source_text and
           "def loadCurrentWithActual?" in source_text,
           "current HouseholdImage ownership has changed: refresh readiness audit")

    seen = set()
    counts = {"current": 0, "research": 0, "cutover": 0}
    blocked = []
    for item in data["gates"]:
        demand(type(item) is dict and set(item) == GATE_FIELDS,
               "readiness item missing explicit evidence/scope/status/next")
        ident, scope, state = item["id"], item["scope"], item["status"]
        demand(type(ident) is str and type(scope) is str and
               scope in SCOPE_IDS and ident in SCOPE_IDS[scope],
               "unknown/readiness scope or ID: " + repr(ident))
        demand(ident not in seen, "duplicate readiness ID " + ident)
        seen.add(ident)
        demand(type(state) is str and state in STATES[scope],
               "research evidence must not be labeled production qualification")
        demand(type(item["next"]) is str and bool(item["next"].strip()),
               "gate requires a concrete next qualification action: " + ident)
        evidence = item["evidence"]
        demand(type(evidence) is list and bool(evidence) and
               len(evidence) == len(set(map(str, evidence))),
               "gate lacks distinct evidence paths: " + ident)
        for rel in evidence:
            demand(type(rel) is str and bool(rel) and
                   not rel.startswith("/") and "\\" not in rel and
                   all(p not in ("", ".", "..") for p in rel.split("/")),
                   "unsafe evidence path: " + repr(rel))
            path = (root / rel).resolve()
            demand(path.is_relative_to(root.resolve()) and path.is_file(),
                   "missing/escaping evidence path for " + ident + ": " + rel)
        counts[scope] += 1
        if scope == "cutover" and state == "blocked":
            blocked.append({"id": ident, "next": item["next"]})
    required = set().union(*SCOPE_IDS.values())
    demand(seen == required,
           "gate deletion/addition requires explicit checker review: " +
           repr(sorted(required.symmetric_difference(seen))))
    qualified = all(item["status"] == "qualified_product"
                    for item in data["gates"] if item["scope"] == "cutover")
    is_ready = data["production_cutover_enabled"] and qualified

    # This report is NOT itself authorization to flip production selection.
    # Even if later explicitly marked ready, an independent human-reviewed
    # physical protocol and executable product acceptance are still required.
    return {
        "schema": 1,
        "tracking_issue": 2030,
        "installed_authority": data["observed_authority"],
        "ledger_valid": True,
        "existing_engine_qualified": counts["current"],
        "synthetic_research_qualified": counts["research"],
        "cutover_gates": counts["cutover"],
        "cutover_blocked": len(blocked),
        "cutover_enabled_in_ledger": data["production_cutover_enabled"],
        "ready_in_ledger": is_ready,
        "limitations": (
            "Static evidence inventory only; statuses do not prove future "
            "durability, chronology, production TUI migration or trusted freshness."
        ),
        "blockers": blocked,
    }


def self_test(original: dict) -> None:
    result = evaluate(original, ROOT)
    demand(result["cutover_blocked"] > 0 and not result["ready_in_ledger"],
           "unsafe report accidentally claims cutover-ready")
    scenarios = [
        ("missing gate", lambda x: x["gates"].pop()),
        ("duplicate gate", lambda x: x["gates"].append(x["gates"][0])),
        ("research to product", lambda x: x["gates"][1].update(
            status="qualified_product")),
        ("bad authority", lambda x: x.update(observed_authority="annual.head")),
        ("invalid evidence", lambda x: x["gates"][0].update(
            evidence=["../../loam-data/household.loam"])),
        ("enabled with blockers", lambda x: x.update(
            production_cutover_enabled=True)),
    ]
    for name, mutate in scenarios:
        changed = copy.deepcopy(original)
        mutate(changed)
        if name == "enabled with blockers":
            demand(not evaluate(changed, ROOT)["ready_in_ledger"],
                   "unsafe cutover on toggle alone")
        else:
            try:
                evaluate(changed, ROOT)
            except InvalidReadiness:
                pass
            else:
                raise AssertionError("ledger accepted tampering: " + name)
    print("PASS: annual cutover inventory schema, scope and fail-closed blockers")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args()
    try:
        original = json.loads(LEDGER.read_text("utf-8"))
        report = evaluate(original, ROOT)
        if args.self_test:
            self_test(original)
        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        else:
            print(
                "ANNUAL_PRODUCTION_READINESS: "
                f"existing={report['existing_engine_qualified']} "
                f"research={report['synthetic_research_qualified']} "
                f"cutover_blocked={report['cutover_blocked']} "
                f"ready={report['ready_in_ledger']}"
            )
            for blocker in report["blockers"]:
                print("  BLOCKED " + blocker["id"] + ": " + blocker["next"])
        if args.require_ready and not report["ready_in_ledger"]:
            print("REFUSE: canonical annual journal cutover is not qualified",
                  file=sys.stderr)
            return 2
        return 0
    except (InvalidReadiness, OSError, UnicodeError, json.JSONDecodeError) as ex:
        print("INVALID ANNUAL READINESS INVENTORY: " + str(ex),
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
