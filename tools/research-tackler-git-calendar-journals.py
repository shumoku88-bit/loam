#!/usr/bin/env python3
"""Research: current LOAM Actual -> Tackler-shaped annual text view in Git.

Uses real Lean-qualified disposable synthetic HouseholdImage generations.
This is a DERIVED current-effective-date projection, NOT annual canonical
LOAM authority, a publication-year history, or a full Tackler parser proof.
"""
from __future__ import annotations

from datetime import date
from hashlib import sha256
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LEAN_FIXTURE = ROOT / "Loam" / "Tests" / "ScheduledBatchReplacement.lean"
LEAN_NATIVE = HERE / "NativeHouseholdSectionBridge.lean"
LEAN_EXPORT = HERE / "NativeTacklerProjection.lean"
ROLE = {"bank": "Assets:Bank", "wifi": "Expenses:Wifi"}
TOKEN = re.compile(r"^[a-zA-Z0-9_:.-]+$")


class Rejected(ValueError):
    pass


def run(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(args, cwd=cwd or ROOT, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(
            f"{args[0]} exited {result.returncode}: "
            f"{result.stderr[-2500:] or result.stdout[-2500:]}"
        )
    return result.stdout.strip()


def git(repo: Path, *args: str) -> str:
    return run("git", "-C", str(repo), *args)


def read_projection(path: Path) -> list[dict]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "LOAM-NATIVE-TACKLER-READ-MODEL\t1":
        raise Rejected("expected LOAM-qualified native Actual read model")
    entries: list[dict] = []
    active = None
    seen = set()
    for line in lines[1:]:
        fields = line.split("\t")
        if fields[0] == "T" and len(fields) == 3 and active is None:
            _, day, ident = fields
            if not TOKEN.fullmatch(ident) or ident in seen:
                raise Rejected("invalid or duplicate Current Event ID")
            try:
                valid = date.fromisoformat(day)
            except ValueError as exc:
                raise Rejected("malformed valid date") from exc
            if valid.isoformat() != day:
                raise Rejected("noncanonical valid date")
            active = {"date": day, "id": ident, "effects": []}
            seen.add(ident)
        elif fields[0] == "P" and len(fields) == 4 and active is not None:
            _, locus, measure, quantity = fields
            if locus not in ROLE or measure != "jpy" or not re.fullmatch(r"-?[0-9]+", quantity):
                raise Rejected("nonrepresentable role, measure or quantity")
            amount = int(quantity)
            if amount == 0:
                raise Rejected("Tackler ordinary posting forbids zero")
            active["effects"].append((locus, amount))
        elif fields == ["END"] and active is not None:
            postings = active["effects"]
            if len(postings) < 2 or sum(v for _, v in postings) != 0:
                raise Rejected("not a complete balanced single-Measure transaction")
            entries.append(active)
            active = None
        else:
            raise Rejected("unsupported read model syntax")
    if active is not None:
        raise Rejected("unterminated Event")
    return entries


def render_tackler(entry: dict) -> str:
    # Tackler 26.10 journal syntax, intentionally limited to tested JPY fixture.
    lines = [
        f"{entry['date']} 'LOAM event {entry['id']}",
        f"  # ext-id: {entry['id']}",
    ]
    for locus, quanta in entry["effects"]:
        lines.append(f"  {ROLE[locus]}  {quanta} JPY")
    return "\n".join(lines) + "\n"


def write_read_model(repo: Path, entries: list[dict]) -> dict[str, str]:
    dest = repo / "txns"
    if dest.exists():
        shutil.rmtree(dest)
    written = {}
    for entry in entries:
        year = entry["date"][:4]
        # Deterministic path from qualified stable Event ID, no path traversal.
        hashed_id = sha256(entry["id"].encode("utf-8")).hexdigest()
        rel = f"txns/{year}/event-{hashed_id}.txn"
        if rel in written:
            raise Rejected("derived event path collision")
        out = repo / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        content = render_tackler(entry)
        out.write_text(content, encoding="utf-8")
        written[rel] = content
    return written


def recorded_paths(repo: Path, rev: str) -> list[str]:
    return git(repo, "ls-tree", "-r", "--name-only", rev, "--", "txns").splitlines()


def recorded_file(repo: Path, rev: str, path: str) -> str:
    if not path.startswith("txns/") or ".." in path:
        raise Rejected("invalid git path")
    return git(repo, "show", f"{rev}:{path}") + "\n"


def tackler_config(repo: Path) -> Path:
    """Minimal exact Tackler config, no external chart or price authority."""
    config = repo.parent / "tackler-research.toml"
    # Both backends share the same configuration and source files.
    config.write_text(
        '[kernel]\n'
        'strict = false\n'
        'audit = { mode = false, hash = "SHA-256" }\n'
        'timestamp = { default-time = 00:00:00, timezone = { name = "UTC" } }\n'
        '\n'
        '[kernel.input]\n'
        'storage = "fs"\n'
        '\n'
        '[kernel.input.fs]\n'
        f'path = "{repo.as_posix()}"\n'
        'dir = "txns"\n'
        'ext = "txn"\n'
        '\n'
        '[kernel.input.git]\n'
        f'repo = "{(repo / ".git").as_posix()}"\n'
        'ref = "HEAD"\n'
        'dir = "txns"\n'
        'ext = "txn"\n'
        '\n'
        '[transaction]\n'
        'accounts = { path = "none" }\n'
        'commodities = { path = "none" }\n'
        'tags = { path = "none" }\n'
        '\n'
        '[report]\n'
        'report-timezone = "UTC"\n'
        'scale = { min = 2, max = 2 }\n'
        'accounts = []\n'
        'targets = ["balance"]\n'
        'balance = { title = "Balance Report", type = "flat" }\n'
        'balance-group = { title = "Balance Group Report", type = "flat", group-by = "month" }\n'
        'register = { title = "Register Report", timestamp-style = "date" }\n'
        '\n'
        '[export]\n'
        'targets = []\n'
        'equity = { accounts = ["Assets:.*"], equity-account = "Equity:Balance" }\n',
        encoding="utf-8",
    )
    return config


def tackler_account_rows(output: str) -> list[str]:
    """Compare only actual accounting rows, not backend metadata."""
    result = []
    for line in output.splitlines():
        tokens = line.split()
        if any(token in ("Assets:Bank", "Expenses:Wifi") for token in tokens):
            result.append(" ".join(tokens))
    if not any("Assets:Bank" in row for row in result):
        raise AssertionError("Tackler did not report Assets:Bank")
    if not any("Expenses:Wifi" in row for row in result):
        raise AssertionError("Tackler did not report Expenses:Wifi")
    return sorted(result)


def verify_tackler_fs_git(repo: Path, config: Path, commit: str, expected: list[dict]) -> None:
    """Execute *real* Tackler v26.10.1 on FS and a fixed Git tree."""
    base = ("tackler", "--config", str(config), "--reports", "balance")
    fs_output = run(*base, "--input.storage", "fs")
    git_output = run(*base, "--input.storage", "git",
                     "--input.git.commit", commit)
    fs_rows = tackler_account_rows(fs_output)
    git_rows = tackler_account_rows(git_output)
    if fs_rows != git_rows:
        raise AssertionError(
            "Tackler current FS vs fixed Git committed tree balance differs: "
            + repr((fs_rows, git_rows))
        )
    if len(expected) == 0:
        raise AssertionError("empty synthetic native input")


def check(verify_tackler: bool = False) -> dict:
    with tempfile.TemporaryDirectory(prefix="loam-tackler-git-calendar-") as temp:
        work = Path(temp)
        source = work / "qualified-native-source"
        captures = work / "captures"
        run("lake", "env", "lean", "--run", str(LEAN_FIXTURE), "setup", str(source))
        run("lake", "env", "lean", "--run", str(LEAN_NATIVE),
            "produce", str(source), str(captures))

        journal = work / "tackler-git-read-model"
        journal.mkdir()
        git(journal, "init", "-q")
        git(journal, "config", "user.name", "LOAM research synthetic fixture")
        git(journal, "config", "user.email", "research@example.invalid")

        tackler_cfg = tackler_config(journal) if verify_tackler else None
        commits = []
        states = []
        entry_ids = []
        for generation in range(4):
            recovered = work / f"read-only-generation-{generation}"
            recovered.mkdir()
            shutil.copyfile(
                captures / f"snapshot-{generation}.wire",
                recovered / "household.loam")
            exported = work / f"qualified-{generation}.tsv"
            run("lake", "env", "lean", "--run", str(LEAN_EXPORT),
                str(recovered), str(exported))
            entries = read_projection(exported)
            entry_ids.append([entry["id"] for entry in entries])
            current = write_read_model(journal, entries)
            git(journal, "add", "-A", "--", "txns")
            git(journal, "commit", "-q", "-m", f"synthetic admitted view {generation}")
            sha = git(journal, "rev-parse", "HEAD")
            assert len(sha) == 40
            paths = recorded_paths(journal, sha)
            if paths != sorted(current):
                raise AssertionError("Git committed different transaction set")
            for path in paths:
                if recorded_file(journal, sha, path) != current[path]:
                    raise AssertionError("pinned Git view bytes differ from filesystem")
            if verify_tackler:
                assert tackler_cfg is not None
                verify_tackler_fs_git(journal, tackler_cfg, sha, entries)
            commits.append(sha)
            states.append(current)

        assert len(set(commits)) == 4
        assert len(states[0]) == 1 and all("/2026/" in x for x in states[0])
        assert len(states[1]) == 2 and any("/2025/" in x for x in states[1])
        assert len(states[2]) == 2 and any("/2025/" in x for x in states[2])
        assert len(states[3]) == 2 and any("/2027/" in x for x in states[3])
        assert not any("/2025/" in x for x in states[3])
        assert not any("/2028/" in x for x in states[3])
        assert not (journal / "txns" / "2028").exists()

        assert entry_ids == [
            ["scheduled-completion:paid"],
            ["record-1", "scheduled-completion:paid"],
            ["replacement-1", "scheduled-completion:paid"],
            ["scheduled-completion:paid", "replacement-1"],
        ], entry_ids

        # Git holds exact earlier snapshots; a later read-model update cannot
        # rewrite the old pinned commit. These are query-visible *current*
        # projections at successive known generations, not automatic learned time.
        prior_path = next(x for x in states[1] if "/2025/" in x)
        assert prior_path not in states[3]
        assert recorded_file(journal, commits[1], prior_path) == states[1][prior_path]
        assert git(journal, "status", "--porcelain") == ""

        # Selected-current-year view is nonauthoritative and can be absent.
        assert all(p.startswith("txns/") for p in states[3])
        # The native canonical snapshot still contains superseded Event and
        # correction evidence omitted by current PTA read projection.
        base = (captures / "snapshot-3.wire").read_bytes()
        assert b"REPLACES" in base and b"record-1" in base
        assert "record-1" not in entry_ids[-1]

        # A malformed read-model input never silently invents a valid posting.
        bad = work / "bad.tsv"
        bad.write_text(
            "LOAM-NATIVE-TACKLER-READ-MODEL\t1\n"
            "T\t2027-01-01\tbad\nP\tbank\tjpy\t-1\nEND\n")
        try:
            read_projection(bad)
        except Rejected:
            pass
        else:
            raise AssertionError("unbalanced Tackler projection accepted")

        return {
            "status": "PASS: native current Actual projection -> calendar-year Tackler-shaped Git read model",
            "qualified_household_generations": 4,
            "git_commits": [x[:12] for x in commits],
            "calendar_years_in_last_view": sorted({
                p.split("/")[1] for p in states[-1]
            }),
            "read_model_files_per_generation": [len(x) for x in states],
            "real_tackler_fs_git_parity": verify_tackler,
            "cross_year_effective_date_reprojection": True,
            "old_git_commit_exactly_replayable": True,
            "superseded_corrected_actual_kept_only_in_loam_canonical": True,
            "no_idle_year_file": True,
            "limits": (
                "Real Tackler is executed only when --tackler is passed. "
                "Git tracks disposable current-Actual view, NOT canonical year journals. "
                "Real learned-time partition, multi-family source authority and automatic "
                "Git commit at canonical publication boundary remain unimplemented."
            ),
        }


if __name__ == "__main__":
    if sys.argv[1:] not in (["--check"], ["--check", "--tackler"]):
        raise SystemExit(
            "usage: research-tackler-git-calendar-journals.py --check [--tackler]")
    print(json.dumps(check(verify_tackler="--tackler" in sys.argv[1:]),
                     ensure_ascii=False, indent=2))
