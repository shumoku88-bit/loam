#!/usr/bin/env python3
"""Research-only year-index closure guard for Actual and Scheduled identities.

Self-contained synthetic counterexample/executable oracle. No LOAM canonical
codec or household data is read. A pinned digest is only a modeled trusted
manifest head; it does not qualify multi-file publication or restore.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import tempfile


class Unavailable(Exception):
    """Unqualified, missing, stale or incomplete evidence; never meaning zero."""


def wire(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def yr(date: str) -> int:
    return int(date[:4])


@dataclass(frozen=True)
class Fact:
    id: str
    learned: str
    seq: int
    kind: str
    subject: str
    other: str = ""
    valid: str = ""
    amount: int = 0
    publication: str = ""


def specimen() -> list[Fact]:
    return [
        Fact("p01", "2023-02-03", 1, "actual", "a:opening", valid="2023-02-03", amount=500),
        Fact("p02", "2025-11-03", 2, "actual", "a:old", valid="2025-11-03", amount=-40),
        Fact("p03", "2025-11-04", 3, "scheduled", "s:wifi", valid="2026-01-08", amount=70),
        Fact("p04", "2026-01-08", 4, "s-complete", "s:wifi", other="a:paid", publication="pay-wifi"),
        Fact("p05", "2026-01-08", 5, "actual", "a:paid", valid="2026-01-08", amount=-70, publication="pay-wifi"),
        Fact("p06", "2027-02-10", 6, "a-correct", "a:old", other="a:corrected", valid="2025-11-03", amount=-44),
        Fact("p07", "2027-02-11", 7, "a-date", "a:corrected", valid="2027-01-03"),
        Fact("p08", "2027-03-01", 8, "actual", "a:late", valid="2025-12-28", amount=-12),
        Fact("p09", "2027-03-01", 9, "scheduled", "s:next", valid="2027-12-01", amount=90),
        Fact("p10", "2028-01-02", 10, "s-replace", "s:next", other="s:successor", publication="replace-next"),
        Fact("p11", "2028-01-02", 11, "scheduled", "s:successor", valid="2029-01-02", amount=95, publication="replace-next"),
        Fact("p12", "2028-02-03", 12, "a-correct", "a:corrected", other="a:twice", valid="2027-01-03", amount=-46),
        Fact("p13", "2028-02-04", 13, "a-date", "a:twice", valid="2025-11-03"),
        Fact("p14", "2031-01-07", 14, "actual", "a:later", valid="2031-01-07", amount=15),
    ]


def project(facts: list[dict], cutoff: str, strict: bool = True) -> tuple[dict, dict]:
    """Tiny identity/terminal oracle matching the *shape* of LOAM frontiers.

    strict makes the caller prove a terminal's Actual endpoint was selected.
    Without strict, completion without Actual becomes open, reproducing the
    negative witness observed in LOAM's real ScheduledOpenWorldInspection.
    """
    actual: dict[str, dict] = {}
    scheduled: dict[str, dict] = {}
    for f in sorted(facts, key=lambda x: x["seq"]):
        if f["learned"] > cutoff:
            continue
        k, subject, other = f["kind"], f["subject"], f["other"]
        if k == "actual":
            if subject in actual:
                raise Unavailable("duplicate Actual identity")
            actual[subject] = {"date": f["valid"], "amount": f["amount"], "current": True}
        elif k == "a-correct":
            if subject not in actual or not actual[subject]["current"] or other in actual:
                raise Unavailable("unresolved Actual correction")
            actual[subject]["current"] = False
            actual[other] = {"date": f["valid"], "amount": f["amount"], "current": True}
        elif k == "a-date":
            if subject not in actual or not actual[subject]["current"]:
                raise Unavailable("unresolved Actual validity revision")
            actual[subject]["date"] = f["valid"]
        elif k == "scheduled":
            if subject in scheduled:
                raise Unavailable("duplicate Scheduled identity")
            scheduled[subject] = {"due": f["valid"], "amount": f["amount"], "terminal": None}
        elif k in ("s-complete", "s-replace", "s-retire"):
            if subject not in scheduled or scheduled[subject]["terminal"] is not None:
                raise Unavailable("unresolved or conflicting Scheduled terminal")
            scheduled[subject]["terminal"] = (k, other)
        else:
            raise Unavailable("unsupported fact")
    for item in scheduled.values():
        terminal = item["terminal"]
        if terminal is not None:
            kind, other = terminal
            if kind == "s-complete" and strict and other not in actual:
                raise Unavailable("Scheduled completion Actual endpoint missing from selected evidence")
            if kind == "s-replace" and other not in scheduled:
                raise Unavailable("Scheduled successor missing")
    return actual, scheduled


def answer(facts: list[dict], domain: str, effective_year: int, cutoff: str,
           strict: bool = True) -> tuple[tuple, ...]:
    actual, scheduled = project(facts, cutoff, strict)
    if domain == "actual":
        return tuple(sorted((k, v["amount"], v["date"])
                            for k, v in actual.items()
                            if v["current"] and yr(v["date"]) == effective_year))
    if domain == "scheduled":
        # Just retained explicitly known open occurrences. Empty != NotDue.
        rows = []
        for k, v in scheduled.items():
            terminal = v["terminal"]
            remains_open = terminal is None or (
                terminal[0] == "s-complete" and terminal[1] not in actual)
            if remains_open and yr(v["due"]) == effective_year:
                rows.append((k, v["amount"], v["due"]))
        return tuple(sorted(rows))
    raise ValueError("unknown domain")


def references(row: dict) -> list[str]:
    k = row["kind"]
    if k in ("actual", "scheduled", "a-date"):
        return [row["subject"]]
    if k in ("a-correct", "s-complete", "s-replace"):
        return [row["subject"], row["other"]]
    if k == "s-retire":
        return [row["subject"]]
    raise Unavailable("unknown kind")


def prepare(rows: list[Fact]) -> list[dict]:
    """Construct index claims from complete witnessed source transitions.

    This preprocessing has access to all rows: it is NOT evidence that LOAM
    can currently seal annual segments, and its small oracle is not a codec.
    """
    seen_a: dict[str, tuple[str, bool]] = {}
    seen_s: dict[str, str] = {}
    prepared = []
    for fact in sorted(rows, key=lambda f: f.seq):
        f = asdict(fact)
        k, subject = f["kind"], f["subject"]
        if k == "actual":
            if subject in seen_a: raise Unavailable("duplicate actual")
            seen_a[subject] = (f["valid"], True)
            years = [yr(f["valid"])]
            domain = "actual"
        elif k == "a-correct":
            if subject not in seen_a or not seen_a[subject][1] or f["other"] in seen_a:
                raise Unavailable("invalid actual correction")
            old = seen_a[subject][0]
            seen_a[subject] = (old, False)
            seen_a[f["other"]] = (f["valid"], True)
            years = [yr(old), yr(f["valid"])]
            domain = "actual"
        elif k == "a-date":
            if subject not in seen_a or not seen_a[subject][1]:
                raise Unavailable("invalid date revision")
            old = seen_a[subject][0]
            seen_a[subject] = (f["valid"], True)
            years = [yr(old), yr(f["valid"])]
            domain = "actual"
        elif k == "scheduled":
            if subject in seen_s: raise Unavailable("duplicate Scheduled")
            seen_s[subject] = f["valid"]
            years = [yr(f["valid"])]
            domain = "scheduled"
        elif k in ("s-complete", "s-replace", "s-retire"):
            if subject not in seen_s: raise Unavailable("missing Scheduled target")
            years = [yr(seen_s[subject])]
            domain = "scheduled"
        else:
            raise Unavailable("unhandled kind")
        f["domain"] = domain
        f["years"] = sorted(set(years))
        f["refs"] = references(f)
        prepared.append(f)
    # Compound facts must be co-admitted. This is a hypothesis enforced by
    # synthetic fixture validation, not real multi-file atomic qualification.
    by_pub: dict[str, list[dict]] = {}
    for r in prepared:
        if r["publication"]:
            by_pub.setdefault(r["publication"], []).append(r)
    for group in by_pub.values():
        if len(group) != 2 or len({r["learned"] for r in group}) != 1:
            raise Unavailable("compound Scheduled/Actual publication split")
        kinds = {r["kind"] for r in group}
        if kinds not in ({"s-complete", "actual"}, {"s-replace", "scheduled"}):
            raise Unavailable("unexpected publication composition")
        # The identity of linked endpoint is not negotiable.
        left = next(r for r in group if r["kind"] in ("s-complete", "s-replace"))
        right = next(r for r in group if r["kind"] in ("actual", "scheduled"))
        if left["other"] != right["subject"]:
            raise Unavailable("mismatched Scheduled endpoint")
    return prepared


def seal(root: Path, rows: list[Fact], width: int) -> str:
    prepared = prepare(rows)
    groups: dict[int, list[dict]] = {}
    for row in prepared:
        year = yr(row["learned"])
        part = year // width * width
        groups.setdefault(part, []).append(row)
    entries = []
    for part, bodyrows in sorted(groups.items()):
        data = wire(bodyrows)
        (root / f"history-{part}.json").write_bytes(data)
        entries.append({
            "part": part,
            "sha256": sha256(data),
            "length": len(bodyrows),
            # Synthetic derived read hints, not additional finance facts.
            "claims": [
                {"id": r["id"], "learned": r["learned"], "domain": r["domain"],
                 "years": r["years"], "refs": r["refs"]}
                for r in bodyrows
            ],
        })
    manifest = wire({"width": width, "entries": entries})
    (root / "manifest.json").write_bytes(manifest)
    # A caller-supplied digest stands in for an *independently admitted,
    # pinned* authoritative head. A digest inside the manifest itself
    # would be forgeable and would not qualify completeness.
    return sha256(manifest)


class Reader:
    def __init__(self, root: Path, expected_head: str):
        self.root = root
        self.read_parts: set[int] = set()
        self.cache: dict[int, list[dict]] = {}
        try:
            bytes_ = (root / "manifest.json").read_bytes()
            if sha256(bytes_) != expected_head:
                raise Unavailable("stale or tampered manifest, not the admitted head")
            manifest = json.loads(bytes_)
            self.width = manifest["width"]
            parts = [e["part"] for e in manifest["entries"]]
            if self.width <= 0 or parts != sorted(set(parts)):
                raise Unavailable("duplicate/out-of-order partition")
            self.entries = manifest["entries"]
        except (OSError, ValueError, KeyError, TypeError) as exc:
            raise Unavailable("missing or unsupported manifest") from exc

    def get(self, entry: dict) -> list[dict]:
        part = entry["part"]
        if part in self.cache:
            return self.cache[part]
        try:
            raw = (self.root / f"history-{part}.json").read_bytes()
            if sha256(raw) != entry["sha256"]:
                raise Unavailable("segment hash mismatch")
            rows = json.loads(raw)
            if len(rows) != entry["length"]:
                raise Unavailable("segment row count mismatch")
            claims = [
                {"id": r["id"], "learned": r["learned"], "domain": r["domain"],
                 "years": r["years"], "refs": r["refs"]}
                for r in rows
            ]
            if claims != entry["claims"]:
                raise Unavailable("segment claims mismatch")
            if any(yr(r["learned"]) // self.width * self.width != part for r in rows):
                raise Unavailable("wrong learned-time partition")
        except (OSError, KeyError, TypeError, ValueError) as exc:
            raise Unavailable(f"required partition {part} absent or malformed") from exc
        self.read_parts.add(part)
        self.cache[part] = rows
        return rows

    def plan(self, domain: str, effective_year: int, cutoff: str) -> list[dict]:
        if domain not in ("actual", "scheduled"):
            raise ValueError(domain)
        claims = [(e, c) for e in self.entries for c in e["claims"]
                  if c["learned"] <= cutoff]
        selected = {c["id"] for _, c in claims if
                    c["domain"] == domain and effective_year in c["years"]}
        # Follow all related source identities, not only effective-year tags.
        # For Scheduled, this necessarily reaches completion Actual.
        nodes = {ref for _, c in claims if c["id"] in selected for ref in c["refs"]}
        changed = True
        while changed:
            changed = False
            for _, c in claims:
                if c["id"] not in selected and nodes.intersection(c["refs"]):
                    selected.add(c["id"])
                    nodes.update(c["refs"])
                    changed = True
        necessary = {e["part"] for e, c in claims if c["id"] in selected}
        rows = []
        for e in self.entries:
            if e["part"] in necessary:
                rows.extend(r for r in self.get(e)
                            if r["id"] in selected and r["learned"] <= cutoff)
        if {r["id"] for r in rows} != selected:
            raise Unavailable("incomplete indexed source selection")
        return rows

    def query(self, domain: str, effective_year: int, cutoff: str) -> tuple[tuple, ...]:
        return answer(self.plan(domain, effective_year, cutoff),
                      domain, effective_year, cutoff, strict=True)

    def financial_prefix(self, cutoff: str) -> list[dict]:
        """Conservative read plan; not a licensed Balance/Daily Pace number."""
        required = [e for e in self.entries if
                    any(c["learned"] <= cutoff for c in e["claims"])]
        rows = [r for e in required for r in self.get(e)
                if r["learned"] <= cutoff]
        # This returns *source evidence only*. Without qualified opening,
        # Scheduled coverage and pool/policy versions, no balance or pace.
        project(rows, cutoff, strict=True)
        return rows


def fail(action, message: str) -> None:
    try:
        action()
    except Unavailable:
        return
    raise AssertionError(f"unsafe accept: {message}")


def check() -> dict:
    rows = specimen()
    oracle_rows = prepare(rows)
    cutoffs = ["2023-12-31", "2025-12-31", "2026-12-31",
               "2027-01-02", "2027-12-31", "2028-12-31", "2031-12-31"]
    target_years = [2023, 2025, 2026, 2027, 2028, 2029, 2031]
    results = []
    for width in (1, 5, 10):
        with tempfile.TemporaryDirectory(prefix="loam-annual-index-") as tmp:
            root = Path(tmp)
            head = seal(root, rows, width)
            reader = Reader(root, head)
            n = 0
            for cutoff in cutoffs:
                for year in target_years:
                    for domain in ("actual", "scheduled"):
                        expected = answer(oracle_rows, domain, year, cutoff)
                        actual = reader.query(domain, year, cutoff)
                        assert actual == expected, (width, cutoff, year, domain, actual, expected)
                        n += 1
                assert reader.financial_prefix(cutoff) == [
                    r for r in oracle_rows if r["learned"] <= cutoff]
            assert n == 98
            # The unsafe Scheduled read can falsely reopen a completed bill.
            trimmed = [r for r in oracle_rows if r["subject"] != "a:paid"]
            assert ("s:wifi", 70, "2026-01-08") in answer(
                trimmed, "scheduled", 2026, "2028-12-31", strict=False)
            fail(lambda: answer(trimmed, "scheduled", 2026, "2028-12-31"),
                 "missing Scheduled completion Actual was accepted")

            if width == 1:
                assert len(reader.entries) == 6  # 2023, 2025, 2026, 2027, 2028, 2031
                isolated = Reader(root, head)
                assert isolated.query("actual", 2023, "2023-12-31") == (
                    ("a:opening", 500, "2023-02-03"),)
                assert isolated.read_parts == {2023}
                # Unused future shard need not be visited for a 2023 question.
                (root / "history-2031.json").unlink()
                assert Reader(root, head).query("actual", 2023, "2023-12-31") == (
                    ("a:opening", 500, "2023-02-03"),)
                fail(lambda: Reader(root, head).financial_prefix("2031-12-31"),
                     "required old/future financial source missing")
                # Selected completion/terminal evidence cannot be skipped.
                (root / "history-2026.json").unlink()
                fail(lambda: Reader(root, head).query("scheduled", 2026, "2028-12-31"),
                     "missing 2026 terminal and Actual")
            else:
                # Spoof a metadata-only reindex: file hash is intact but
                # expected head digest is NOT, so it must be rejected.
                manifest = json.loads((root / "manifest.json").read_bytes())
                manifest["entries"][0]["claims"][0]["years"] = [2099]
                (root / "manifest.json").write_bytes(wire(manifest))
                fail(lambda: Reader(root, head), "tampered claims under old head")
            results.append({"years_per_segment": width, "year_and_cutoff_queries": n,
                            "segments": len(reader.entries),
                            "native_actual_scheduled_semantics_guard": True,
                            "cross_year_source_closure": True,
                            "mandatory_financial_prefix": True,
                            "invalid_required_history_refused": True})
    return {
        "outcome": "PASS: bounded synthetic query planner + negative guards",
        "cases": results,
        "caveat": "Manifest digest is an EXTERNALLY PINNED hypothetical trusted head; no LOAM multi-file commit, actual native codec, historical as-known clock or numeric Daily Pace proof."
    }


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
