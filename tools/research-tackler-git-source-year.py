#!/usr/bin/env python3
"""Research-only readable calendar-year source journal, Git-pinned replay.

Takes four REAL Lean-admitted HouseholdImage generations from disposable
synthetic native publishers. Experimental writer-admission dates are injected
by the TEST, not learned from validOn, wall time or Git commit timestamps.

A full initial HouseholdImage and changed original Actual TX wire blocks are
filed under their test *publication* year. This is NOT a production canonical
writer, not an as-known-time authority, and not a Tackler .txn grammar.
"""
from __future__ import annotations

import importlib.util
import json
from datetime import date
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools"
JOURNAL_RE = re.compile(r"^journal/([0-9]{4})/([0-9]{6})\.(household|actual-patch)\.loam$")
HASH = re.compile(r"^[a-f0-9]{64}$")
HEADER = "LOAM-SOURCE-YEAR-TX-PATCH\t1\n"


class Refused(ValueError):
    pass


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise Refused(reason)


def imported(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SOURCES / filename)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha(raw: bytes) -> str:
    return sha256(raw).hexdigest()


def command(*args: str, cwd: Path | None = None) -> bytes:
    r = subprocess.run(args, cwd=cwd or ROOT, capture_output=True)
    if r.returncode:
        raise RuntimeError(
            f"{args[0]} exit {r.returncode}: {r.stderr[-2200:].decode(errors='replace')}"
        )
    return r.stdout


def git(repo: Path, *args: str) -> bytes:
    return command("git", "-C", str(repo), *args)


def parse_day(day: str) -> date:
    try:
        result = date.fromisoformat(day)
    except ValueError as exc:
        raise Refused("invalid publication-day test evidence") from exc
    require(result.isoformat() == day, "noncanonical publication day")
    return result


def patch_for(before: bytes, after: bytes, publication_day: str, delta, bridge) -> bytes:
    """Store ONLY newly appended or changed *existing normalized Actual blocks*.

    This intentionally rejects unknown updates to other HouseholdImage families,
    settlement tails, encoding versions and unstable Event order.
    """
    parse_day(publication_day)
    old_sections = bridge.parse_wire(before)
    new_sections = bridge.parse_wire(after)
    require([n for n, _ in old_sections] == [n for n, _ in new_sections],
            "family addition/removal unsupported")
    old = dict(old_sections)
    new = dict(new_sections)
    require([n for n in old if old[n] != new[n]] == ["Actual"],
            "must change only the admitted Actual family")
    h0, tx0, trailer0 = delta.actual_blocks(old["Actual"])
    h1, tx1, trailer1 = delta.actual_blocks(new["Actual"])
    require(h0 == h1 and trailer0 == trailer1,
            "encoding/settlement change requires qualified full fallback")
    original_ids = [ident for ident, _ in tx0]
    require([ident for ident, _ in tx1[:len(tx0)]] == original_ids,
            "earlier Event identity/order changed")
    old_blocks = dict(tx0)
    changed = []
    for ident, body in tx1:
        if old_blocks.get(ident) != body:
            changed.append(("REPLACE" if ident in old_blocks else "APPEND", ident, body))
    require(bool(changed), "no admitted Actual TX difference")
    rows = [
        HEADER,
        f"PUBLICATION-DAY\t{publication_day}\n",
        f"BEFORE\t{sha(before)}\n",
        f"AFTER\t{sha(after)}\n",
    ]
    for operation, ident, block in changed:
        require("\n" not in ident and "\t" not in ident, "unsafe Event identity")
        require(block.startswith(f"TX\t{ident}\t") and block.endswith("ENDTX\n"),
                "not a complete native normalized TX")
        rows.append(f"CHANGE\t{operation}\t{ident}\n")
        rows.append(block)
    rows.append("END-PUBLICATION\n")
    return "".join(rows).encode("utf-8")


def parse_patch(raw: bytes, delta) -> tuple[str, str, str, list[tuple[str, str, str]]]:
    try:
        lines = raw.decode("utf-8").splitlines(keepends=True)
    except UnicodeDecodeError as exc:
        raise Refused("not valid UTF-8") from exc
    require(len(lines) >= 7 and lines[0] == HEADER and
            lines[-1] == "END-PUBLICATION\n", "unrecognized/unterminated publication")
    def header(index: int, name: str) -> str:
        row = lines[index]
        require(row.startswith(name + "\t") and row.endswith("\n"),
                f"missing {name} evidence")
        item = row[len(name)+1:-1]
        require(bool(item) and "\t" not in item, "malformed publication metadata")
        return item
    day = header(1, "PUBLICATION-DAY")
    parse_day(day)
    before = header(2, "BEFORE")
    after = header(3, "AFTER")
    require(bool(HASH.fullmatch(before)) and bool(HASH.fullmatch(after)) and
            before != after, "invalid/identical chain hash")
    changes = []
    pos = 4
    while pos < len(lines)-1:
        row = lines[pos]
        fields = row.removesuffix("\n").split("\t")
        require(row.endswith("\n") and len(fields) == 3 and fields[0] == "CHANGE"
                and fields[1] in ("REPLACE", "APPEND"),
                "unknown publication operation")
        _, mode, ident = fields
        pos += 1
        block: list[str] = []
        while pos < len(lines)-1:
            current = lines[pos]
            block.append(current)
            pos += 1
            if current == "ENDTX\n":
                break
        body = "".join(block)
        require(body.startswith(f"TX\t{ident}\t") and body.endswith("ENDTX\n"),
                "incomplete/mismatched normalized Actual TX")
        _, parsed, trailer = delta.actual_blocks("LOAM-NORMALIZED-ACTUAL\t1\n" + body)
        require(len(parsed) == 1 and parsed[0] == (ident, body) and trailer == "",
                "TX parser refused event boundary")
        changes.append((mode, ident, body))
    require(bool(changes) and len(set(x[1] for x in changes)) == len(changes),
            "empty/duplicate Actual changes")
    return day, before, after, changes


def apply_patch(before: bytes, raw: bytes, delta, bridge) -> tuple[bytes, str]:
    day, before_hash, after_hash, changes = parse_patch(raw, delta)
    require(sha(before) == before_hash, "publication chain has missing/wrong prefix")
    sections = bridge.parse_wire(before)
    actual = dict(sections)["Actual"]
    h, blocks, trailer = delta.actual_blocks(actual)
    originals = [ident for ident, _ in blocks]
    updated = dict(blocks)
    for mode, ident, body in changes:
        if mode == "APPEND":
            require(ident not in updated, "duplicate appended Event")
            originals.append(ident)
            updated[ident] = body
        else:
            require(ident in updated and updated[ident] != body,
                    "invalid unchanged/replaced Event")
            updated[ident] = body
    actual = delta.assembled(h, [(k, updated[k]) for k in originals], trailer)
    reconstructed = bridge.encode([
        (name, actual if name == "Actual" else old) for name, old in sections
    ])
    require(sha(reconstructed) == after_hash, "native generation differs from source")
    return reconstructed, day


def read_git_journals(repo: Path, rev: str) -> dict[str, bytes]:
    paths = git(repo, "ls-tree", "-r", "--name-only", rev, "--", "journal")
    result = {}
    for path in paths.decode("utf-8").splitlines():
        require(bool(JOURNAL_RE.fullmatch(path)), "unexpected authoritative journal path")
        result[path] = git(repo, "show", f"{rev}:{path}")
    require(bool(result), "missing journal tree")
    return result


def replay(files: dict[str, bytes], delta, bridge) -> bytes:
    """Reassemble ALL source families; fail closed. No lazy year selection."""
    require(bool(files), "no committed source journal")
    numbered = []
    for filename, body in files.items():
        match = JOURNAL_RE.fullmatch(filename)
        require(match is not None, "unexpected path")
        year, ordinal, kind = match.groups()
        numbered.append((int(ordinal), int(year), kind, body))
    numbered.sort()
    require([x[0] for x in numbered] == list(range(1, len(numbered)+1)),
            "publication sequence missing/reordered")
    require(numbered[0][2] == "household" and
            all(row[2] == "actual-patch" for row in numbered[1:]),
            "missing base or non-Actual publication")
    # Base is a qualified original HouseholdImage snapshot supplied by
    # the native test fixture; re-admission is required separately.
    current = numbered[0][3]
    bridge.parse_wire(current)
    prev_day = parse_day("2026-12-30")  # TEST FIXTURE EPOCH, not real LOAM time.
    require(numbered[0][1] == 2026, "initial test publication year incorrect")
    for _, year, _, patch in numbered[1:]:
        current, day = apply_patch(current, patch, delta, bridge)
        stamp = parse_day(day)
        require(stamp > prev_day, "nonmonotonic fixture publication sequence")
        require(stamp.year == year, "year directory is not publication year")
        prev_day = stamp
    return current


def must_refuse(action, label: str) -> None:
    try:
        action()
    except (Refused, ValueError):
        return
    raise AssertionError("unsafe acceptance of " + label)


def run_test() -> dict:
    delta = imported("loam_delta_for_year_git", "research-native-actual-publication-delta.py")
    bridge = delta.bridge_module()
    with tempfile.TemporaryDirectory(prefix="loam-git-source-year-") as temporary:
        base = Path(temporary)
        fixture = base / "synthetic-loam"
        snapshots = base / "snapshots"
        bridge.checked_run(bridge.FIXTURE, "setup", fixture)
        bridge.checked_run(bridge.NATIVE, "produce", fixture, snapshots)
        admitted = [(snapshots / f"snapshot-{idx}.wire").read_bytes()
                    for idx in range(4)]

        repo = base / "source-git"
        repo.mkdir()
        git(repo, "init", "-q")
        git(repo, "config", "user.name", "LOAM calendar source research")
        git(repo, "config", "user.email", "synthetic@example.invalid")

        # The following are EXPLICIT experiment-only writer-time witnesses.
        # Native snapshots contain NO qualified admission timestamps.
        dates = ("2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02")
        revisions = []
        publications = []
        for idx, publish_day in enumerate(dates):
            year = parse_day(publish_day).year
            rel = (f"journal/{year}/{idx+1:06d}.household.loam" if idx == 0 else
                   f"journal/{year}/{idx+1:06d}.actual-patch.loam")
            path = repo / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            payload = (admitted[0] if idx == 0 else
                       patch_for(admitted[idx-1], admitted[idx],
                                 publish_day, delta, bridge))
            path.write_bytes(payload)
            publications.append((rel, len(payload)))
            git(repo, "add", "--", rel)
            git(repo, "commit", "-q", "-m", f"synthetic qualified publication {idx+1}")
            rev = git(repo, "rev-parse", "HEAD").decode().strip()
            files = read_git_journals(repo, rev)
            require(replay(files, delta, bridge) == admitted[idx],
                    "Git source replay is not equal to native admitted generation")
            recovered = base / f"native-recovered-{idx}"
            recovered.mkdir()
            (recovered / "household.loam").write_bytes(replay(files, delta, bridge))
            bridge.checked_run(bridge.NATIVE, "verify", recovered)
            revisions.append(rev)

        # A 2027 correction to a source original effective in 2025 must
        # *not change* the committed 2026 source journal files.
        old_files = read_git_journals(repo, revisions[1])
        late_files = read_git_journals(repo, revisions[-1])
        for path, body in old_files.items():
            require(late_files.get(path) == body,
                    "sealed prior calendar-year source was overwritten")
        require(list(sorted(late_files)) == [
            "journal/2026/000001.household.loam",
            "journal/2026/000002.actual-patch.loam",
            "journal/2027/000003.actual-patch.loam",
            "journal/2027/000004.actual-patch.loam",
        ], "invalid Jan-1 partition or an invented idle journal")

        # Corrected source IDs and DATE-REV stay in their admitted publication
        # years even though effective transaction dates are 2025 or 2027.
        initial_txt = admitted[1].decode()
        require("2025-12-30" in initial_txt, "backdated event witness missing")
        correction_txt = late_files["journal/2027/000003.actual-patch.loam"].decode()
        require("REPLACES\trecord-1" in correction_txt,
                "original 2025 correction identity missing in 2027 publication")
        revision_txt = late_files["journal/2027/000004.actual-patch.loam"].decode()
        require("DATE-REV" in revision_txt and "2027-01-03" in revision_txt,
                "date-revision provenance missing from 2027 publication")

        # Ignore uncommitted working-tree tampering when a fixed Git rev
        # is read. This does NOT provide anti-rollback.
        target = repo / "journal/2026/000002.actual-patch.loam"
        target.write_text("tampered\n")
        require(replay(read_git_journals(repo, revisions[-1]), delta, bridge)
                == admitted[-1], "pinned revision confused with working tree")

        missing = dict(late_files)
        missing.pop("journal/2027/000003.actual-patch.loam")
        must_refuse(lambda: replay(missing, delta, bridge),
                    "missing interior cross-year source")
        altered = dict(late_files)
        altered["journal/2027/000004.actual-patch.loam"] = (
            altered["journal/2027/000004.actual-patch.loam"]
            .replace(b"2027-01-03", b"2027-01-04"))
        must_refuse(lambda: replay(altered, delta, bridge),
                    "tampered late DATE-REV source")

        # A valid prior Git commit is self-consistent. Without an external
        # independently trusted latest reference, rollback is NOT detectable.
        require(replay(read_git_journals(repo, revisions[1]), delta, bridge)
                == admitted[1], "legitimate earlier committed state not readable")
        require("journal/2028" not in str(late_files), "idle year was created")

        return {
            "status": "PASS: native admitted Household source reconstructs from Jan-1 Git journal text",
            "qualified_native_generations": len(admitted),
            "synthetic_publication_days_NOT_canonical_learned_time": dates,
            "git_commit_count": len(revisions),
            "source_files": publications,
            "same_generation_actual_and_scheduled_requalified": True,
            "2026_source_immutable_after_2027_correction": True,
            "missing_interior_or_modified_source_refused": True,
            "Git_pinned_view_ignores_uncommitted_tampering": True,
            "legitimate_older_Git_commit_rollback_undetectable": True,
            "limits": (
                "Test-injected admission dates; actual publication-time authority NOT yet wired. "
                "TX-scoped Actual-only changes, full Household baseline required; "
                "Tackler does NOT parse the canonical source patch grammar; "
                "no incremental lazy reader, process-kill coupling or writer integration."
            ),
        }


if __name__ == "__main__":
    if sys.argv[1:] != ["--check"]:
        raise SystemExit("usage: research-tackler-git-source-year.py --check")
    print(json.dumps(run_test(), indent=2))
