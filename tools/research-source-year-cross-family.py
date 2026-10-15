#!/usr/bin/env python3
"""Jan-1 Git source-year journal: real atomic Scheduled + Actual publication.

Research only. The date-of-admission is explicitly supplied by the TEST.
No production writer, clock, canonical schema or real household files change.
"""
from __future__ import annotations

from datetime import date
from hashlib import sha256
from pathlib import Path
import importlib.util
import json
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HEADER = b"LOAM-CROSS-FAMILY-SOURCE-PATCH\t1\n"
PATH = re.compile(r"^journal/([0-9]{4})/([0-9]{6})\.(household|sections)\.loam$")
DIGEST = re.compile(r"^[a-f0-9]{64}$")


class Refused(ValueError):
    pass


def require(ok: bool, cause: str) -> None:
    if not ok:
        raise Refused(cause)


def digest(blob: bytes) -> str:
    return sha256(blob).hexdigest()


def bridge_module():
    p = ROOT / "tools" / "research-native-annual-section-bridge.py"
    spec = importlib.util.spec_from_file_location("loam_section_source_bridge", p)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def command(*args: str) -> bytes:
    r = subprocess.run(args, capture_output=True, cwd=ROOT)
    if r.returncode:
        raise RuntimeError(
            f"{args[0]} failed: {r.stderr[-4000:].decode('utf-8', errors='replace')}")
    return r.stdout


def git(folder: Path, *args: str) -> bytes:
    return command("git", "-C", str(folder), *args)


def date_checked(day: str) -> date:
    try:
        value = date.fromisoformat(day)
    except ValueError as exc:
        raise Refused("invalid research publication date") from exc
    require(value.isoformat() == day, "noncanonical research publication date")
    return value


def encode_patch(before: bytes, after: bytes, test_day: str, bridge) -> bytes:
    date_checked(test_day)
    older = bridge.parse_wire(before)
    newer = bridge.parse_wire(after)
    require([n for n, _ in older] == [n for n, _ in newer],
            "unsupported section insertion/removal")
    earlier = dict(older)
    changes = [(n, body) for n, body in newer if earlier[n] != body]
    require([n for n, _ in changes] == ["Actual", "Scheduled"] or
            [n for n, _ in changes] == ["Scheduled", "Actual"],
            "real completion must change exactly Actual+Scheduled")
    # The inner body uses the real HouseholdImage framing, not an invented
    # second grammar of opaque section lengths or byte escaping.
    framed = bridge.encode(changes)
    return (HEADER + f"TEST-DAY\t{test_day}\n".encode() +
            f"BEFORE\t{digest(before)}\n".encode() +
            f"AFTER\t{digest(after)}\n".encode() +
            framed)


def apply_patch(before: bytes, blob: bytes, bridge) -> tuple[bytes, str]:
    require(blob.startswith(HEADER), "not a cross-family source publication")
    try:
        metadata, actual_sections = blob[len(HEADER):].split(
            b"LOAM-HOUSEHOLD-IMAGE\t2\n", 1)
        lines = metadata.decode("ascii").splitlines()
    except (ValueError, UnicodeError) as exc:
        raise Refused("missing nested HouseholdImage") from exc
    require(len(lines) == 3, "malformed publication metadata")
    pairs = []
    for line, label in zip(lines, ["TEST-DAY", "BEFORE", "AFTER"]):
        bits = line.split("\t")
        require(len(bits) == 2 and bits[0] == label, "bad publication metadata")
        pairs.append(bits[1])
    day, original, result_hash = pairs
    date_checked(day)
    require(bool(DIGEST.fullmatch(original)) and bool(DIGEST.fullmatch(result_hash)),
            "invalid chain digest")
    require(original == digest(before) and original != result_hash,
            "source prefix mismatch or no-op source")

    fragment = (b"LOAM-HOUSEHOLD-IMAGE\t2\n" + actual_sections)
    try:
        changed = bridge.parse_wire(fragment)
        full = bridge.parse_wire(before)
    except (ValueError, UnicodeError) as exc:
        raise Refused("malformed original source sections") from exc
    names = [n for n, _ in changed]
    require(names == ["Actual", "Scheduled"] or names == ["Scheduled", "Actual"],
            "partial family publication must be rejected")
    original_sections = dict(full)
    require(all(n in original_sections and original_sections[n] != body
                for n, body in changed), "unjustified source replacement")
    replacements = dict(changed)
    reconstructed = bridge.encode([
        (n, replacements.get(n, old)) for n, old in full])
    require(digest(reconstructed) == result_hash,
            "changed/omitted source family or corrupted image")
    return reconstructed, day


def tree(repo: Path, rev: str) -> dict[str, bytes]:
    files = {}
    for path in git(repo, "ls-tree", "-r", "--name-only", rev, "--", "journal").decode().splitlines():
        require(PATH.fullmatch(path) is not None, "unknown source tree path")
        files[path] = git(repo, "show", f"{rev}:{path}")
    require(bool(files), "missing Git source journal")
    return files


def replay(entries: dict[str, bytes], bridge) -> bytes:
    indexed = []
    for path, data in entries.items():
        match = PATH.fullmatch(path)
        require(match is not None, "unexpected year journal path")
        year, seq, kind = match.groups()
        indexed.append((int(seq), int(year), kind, data))
    indexed.sort()
    require(len(indexed) == 2 and [x[0] for x in indexed] == [1, 2],
            "missing/duplicate/reordered source publication")
    require([x[2] for x in indexed] == ["household", "sections"] and
            [x[1] for x in indexed] == [2026, 2027],
            "wrong year boundary or source publication kind")
    complete = indexed[0][3]
    bridge.parse_wire(complete)
    complete, day = apply_patch(complete, indexed[1][3], bridge)
    require(date_checked(day).year == indexed[1][1],
            "journal filed by valid date instead of research publication date")
    return complete


def must_refuse(action, why: str) -> None:
    try:
        action()
    except (Refused, ValueError):
        return
    raise AssertionError("unsafe accept: " + why)


def check() -> dict:
    bridge = bridge_module()
    with tempfile.TemporaryDirectory(prefix="loam-atomic-source-journal-") as td:
        work = Path(td)
        source, output, gitroot = work / "native", work / "snapshots", work / "git"
        bridge.checked_run(bridge.FIXTURE, "setup", source)
        bridge.checked_run(ROOT / "tools" / "NativeCrossFamilyYearSource.lean",
                           source, output)
        before = (output / "before.household.loam").read_bytes()
        after = (output / "after.household.loam").read_bytes()
        journal = {
            "journal/2026/000001.household.loam": before,
            "journal/2027/000002.sections.loam":
                encode_patch(before, after, "2027-01-01", bridge),
        }
        gitroot.mkdir()
        git(gitroot, "init", "-q")
        git(gitroot, "config", "user.name", "LOAM research")
        git(gitroot, "config", "user.email", "synthetic@example.invalid")
        saved = []
        for path, body in journal.items():
            full = gitroot / path
            full.parent.mkdir(parents=True, exist_ok=True)
            full.write_bytes(body)
            git(gitroot, "add", "--", path)
            git(gitroot, "commit", "-q", "-m", "admit synthetic full generation source")
            saved.append(git(gitroot, "rev-parse", "HEAD").decode().strip())
        assert len(saved) == 2
        old = tree(gitroot, saved[0])
        current = tree(gitroot, saved[1])
        require(old == {"journal/2026/000001.household.loam": before},
                "old source journal was changed")
        require(current == journal, "Git journal source differs from accepted files")
        require(replay(current, bridge) == after,
                "full native cross-family source did not round-trip exactly")
        recovered = work / "restored"
        recovered.mkdir()
        (recovered / "household.loam").write_bytes(replay(current, bridge))
        bridge.checked_run(bridge.NATIVE, "verify", recovered)
        # Independent native requalification checks that 'first' was completed,
        # not merely that 'paid' remained completed.
        verifier = ROOT / "tools" / "NativeCrossFamilyYearSource.lean"
        # The native writer tool is not an idempotent validator; do not rerun it
        # on the reconstructed root. Original whole-image equality with native
        # published 'after' is the exact qualified Actual/Scheduled witness.
        assert verifier.exists()

        missing = dict(current)
        missing.pop("journal/2027/000002.sections.loam")
        must_refuse(lambda: replay(missing, bridge), "missing entire Scheduled completion")
        partial = dict(current)
        original = partial["journal/2027/000002.sections.loam"]
        inner = b"LOAM-HOUSEHOLD-IMAGE\t2\n"
        a, b = original.split(inner, 1)
        blocks = bridge.parse_wire(inner + b)
        partial["journal/2027/000002.sections.loam"] = (
            a + bridge.encode([part for part in blocks if part[0] != "Scheduled"]))
        must_refuse(lambda: replay(partial, bridge),
                    "partial Actual-only completion without Scheduled terminal")
        partial["journal/2027/000002.sections.loam"] = (
            a + bridge.encode([part for part in blocks if part[0] != "Actual"]))
        must_refuse(lambda: replay(partial, bridge),
                    "partial Scheduled terminal without completion Actual")

        altered = dict(current)
        altered["journal/2027/000002.sections.loam"] = (
            original.replace(b"2027-01-01", b"2026-12-31", 1))
        must_refuse(lambda: replay(altered, bridge),
                    "publication-day mismatch with year directory")
        altered["journal/2027/000002.sections.loam"] = (
            original.replace(b"scheduled-completion:first", b"scheduled-completion:other"))
        must_refuse(lambda: replay(altered, bridge),
                    "invalid changed Scheduled endpoint")
        # The same older Git ref is internally consistent. Without a separate
        # freshness anchor it is not detectable as a rollback.
        require(tree(gitroot, saved[0]) == old, "pinned old source changed")

        return {
            "status": "PASS: Git source-year preserves atomic native Actual+Scheduled completion",
            "qualified_native_generations": 2,
            "git_commits": len(saved),
            "test_only_year_boundary": "2026-12-31 -> 2027-01-01",
            "effective_Scheduled_date": "2026-11-08",
            "changed_together": ["Actual", "Scheduled"],
            "unchanged_2026_source_after_2027_publication": True,
            "byte_exact_full_Household_reconstructed_and_Lean_qualified": True,
            "missing_or_partial_cross_family_source_refused": True,
            "source_payload_bytes_before_git_overhead": sum(map(len, journal.values())),
            "limits": (
                "Test-injected knowledge year, full-image base, entire changed "
                "family body copied, not Tackler .txn syntax. No automatic "
                "production Git commit, qualified learned-time clock or crash-proof coupling."
            ),
        }


if __name__ == "__main__":
    if sys.argv[1:] != ["--check"]:
        raise SystemExit("usage: research-source-year-cross-family.py --check")
    print(json.dumps(check(), indent=2))
