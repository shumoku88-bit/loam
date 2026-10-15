#!/usr/bin/env python3
"""Research bridge: real native Household generations over immutable section blobs.

This is section-level copy-on-write, NOT an annual-partitioned Actual codec.
Synthetic native households only; no production data read or changed.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Loam" / "Tests" / "ScheduledBatchReplacement.lean"
NATIVE = ROOT / "tools" / "NativeHouseholdSectionBridge.lean"
PROTOCOL = ROOT / "tools" / "research-annual-fs-killpoints.py"
HEADER = "LOAM-HOUSEHOLD-IMAGE\t2\n"


def storage():
    spec = importlib.util.spec_from_file_location("annual_fs_protocol", PROTOCOL)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_wire(raw: bytes) -> list[tuple[str, str]]:
    try:
        s = raw.decode("utf-8")
    except UnicodeDecodeError as ex:
        raise ValueError("invalid wire encoding") from ex
    if not s.startswith(HEADER):
        raise ValueError("unsupported HouseholdImage version")
    pos, parts = len(HEADER), []
    names = set()
    while pos < len(s):
        end = s.find("\n", pos)
        if end < 0:
            raise ValueError("unterminated section")
        line = s[pos:end].split("\t")
        if len(line) != 3 or line[0] != "SECTION":
            raise ValueError("bad section framing")
        name = line[1]
        if not name or "\r" in name or name in names:
            raise ValueError("invalid/duplicate section")
        try:
            length = int(line[2])
        except ValueError as ex:
            raise ValueError("invalid character length") from ex
        if length < 0 or not line[2].isascii() or not line[2].isdigit():
            raise ValueError("invalid length")
        begin = end + 1
        body = s[begin:begin + length]
        if len(body) != length:
            raise ValueError("truncated body")
        names.add(name)
        parts.append((name, body))
        pos = begin + length
    return parts


def encode(parts: list[tuple[str, str]]) -> bytes:
    return (HEADER + "".join(
        f"SECTION\t{name}\t{len(body)}\n{body}" for name, body in parts
    )).encode("utf-8")


def checked_run(*args: str) -> None:
    run = subprocess.run(
        ["lake", "env", "lean", "--run", *map(str, args)],
        cwd=ROOT, text=True, capture_output=True,
    )
    if run.returncode:
        raise AssertionError(
            f"native Lean command {args} failed:\n"
            f"stdout: {run.stdout[-4000:]}\nstderr: {run.stderr[-4000:]}"
        )


def commit_sections(fs, repo: Path, wire: bytes, declared_year: int) -> tuple[str, dict]:
    parts = parse_wire(wire)
    entries = []
    for name, body in parts:
        h = fs.store_immutable(repo / "segments", body.encode("utf-8"))
        entries.append({"name": name, "hash": h})
    manifest = {"version": 1, "research_year_label": declared_year, "sections": entries}
    head = fs.store_immutable(repo / "manifests", fs.canonical(manifest))
    fs.head_write(repo, head)
    return head, manifest


def read_generation(fs, repo: Path) -> tuple[bytes, str, dict]:
    try:
        h = (repo / "HEAD").read_text("ascii").strip()
        if not fs.HASH.fullmatch(h):
            raise fs.Unavailable("missing/invalid committed head")
        blob = (repo / "manifests" / h).read_bytes()
        if fs.digest(blob) != h:
            raise fs.Unavailable("selected manifest digest mismatch")
        manifest = json.loads(blob)
        if manifest["version"] != 1 or not isinstance(manifest["sections"], list):
            raise fs.Unavailable("manifest schema unsupported")
        names = set()
        parts = []
        for entry in manifest["sections"]:
            name, blob_id = entry["name"], entry["hash"]
            if name in names or not name or not fs.HASH.fullmatch(blob_id):
                raise fs.Unavailable("invalid manifest section")
            names.add(name)
            body = (repo / "segments" / blob_id).read_bytes()
            if fs.digest(body) != blob_id:
                raise fs.Unavailable("section hash mismatch")
            parts.append((name, body.decode("utf-8")))
        whole = encode(parts)
        if parse_wire(whole) != parts:
            raise fs.Unavailable("reconstructed outer image differs")
        return whole, h, manifest
    except (OSError, KeyError, ValueError, TypeError, UnicodeError) as ex:
        raise fs.Unavailable("required HouseholdImage evidence unavailable") from ex


def should_refuse(action, label: str) -> None:
    try:
        action()
    except Exception as ex:
        if ex.__class__.__name__ == "Unavailable":
            return
        raise
    raise AssertionError("unsafe accept: " + label)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        parser.print_help()
        return
    fs = storage()
    with tempfile.TemporaryDirectory(prefix="loam-native-section-bridge-") as td:
        base = Path(td)
        native_root = base / "native-source"
        output = base / "native-snapshots"
        checked_run(FIXTURE, "setup", native_root)
        checked_run(NATIVE, "produce", native_root, output)

        repo = base / "split-prototype"
        repo.mkdir()
        (repo / "segments").mkdir()
        (repo / "manifests").mkdir()
        (repo / ".writer.lock").touch()
        generations = []
        raw_images = []
        changed = []
        previous = None

        # These are experiment-only labels for captured accepted generations,
        # NOT inferred real learned-times, and NOT physical annual Actual rows.
        for index, year in enumerate((2026, 2027, 2027, 2028)):
            original = (output / f"snapshot-{index}.wire").read_bytes()
            raw_images.append(original)
            parts = parse_wire(original)
            assert encode(parts) == original, "non-byte-exact HouseholdImage framing"
            current_parts = dict(parts)
            changed.append([
                name for name, value in parts
                if previous is None or previous.get(name) != value
            ])
            previous = current_parts
            head, manifest = commit_sections(fs, repo, original, year)
            restored, recovered_head, recovered_manifest = read_generation(fs, repo)
            assert restored == original and recovered_head == head
            assert recovered_manifest == manifest
            recovered_root = base / f"recovered-{index}"
            recovered_root.mkdir()
            (recovered_root / "household.loam").write_bytes(restored)
            checked_run(NATIVE, "verify", recovered_root)
            generations.append(head)

        assert len(set(generations)) == 4
        assert changed[1:] == [["Actual"], ["Actual"], ["Actual"]], changed
        first = dict(parse_wire(raw_images[0]))
        last = dict(parse_wire(raw_images[-1]))
        assert first["Scheduled"] == last["Scheduled"]
        assert first["CustomEvidence"] == last["CustomEvidence"]

        final_head = generations[-1]
        final_manifest = read_generation(fs, repo)[2]
        assert sum(item["name"] == "Actual" for item in final_manifest["sections"]) == 1

        # Missing a referenced cross-family Scheduled section cannot produce
        # an apparently valid all-clear result. Fail closed before Lean Review.
        selected_scheduled = next(i["hash"] for i in final_manifest["sections"]
                                  if i["name"] == "Scheduled")
        (repo / "segments" / selected_scheduled).unlink()
        should_refuse(lambda: read_generation(fs, repo), "missing Scheduled segment")
        fs.store_immutable(repo / "segments", last["Scheduled"].encode("utf-8"))

        # Corrupt retained Actual bytes under a valid selected manifest.
        actual = next(i["hash"] for i in final_manifest["sections"] if i["name"] == "Actual")
        original_actual = (repo / "segments" / actual).read_bytes()
        (repo / "segments" / actual).write_bytes(b"corrupted")
        should_refuse(lambda: read_generation(fs, repo), "corrupt admitted Actual")
        (repo / "segments" / actual).write_bytes(original_actual)

        # A correct, older head is structurally self-consistent and passes.
        # This explicitly does NOT prevent silent rollback.
        fs.head_write(repo, generations[0])
        old_wire, _, _ = read_generation(fs, repo)
        assert old_wire == raw_images[0]
        fs.head_write(repo, final_head)
        assert read_generation(fs, repo)[0] == raw_images[-1]

        section_files = list((repo / "segments").iterdir())
        manifest_files = list((repo / "manifests").iterdir())
        output = {
            "status": "PASS: native HouseholdImage generations round-trip through immutable sections",
            "native_generations_qualified": len(generations),
            "sections_changed_by_generation": changed,
            "whole_images_total_bytes": sum(map(len, raw_images)),
            "unique_immutable_section_bytes": sum(x.stat().st_size for x in section_files),
            "manifest_bytes": sum(x.stat().st_size for x in manifest_files),
            "unique_section_count": len(section_files),
            "preserved_scheduled_and_unknown_sections": True,
            "missing_or_corrupt_section_refused": True,
            "valid_old_head_rollback_undetected": True,
            "limits": (
                "Full Actual section rewritten on every Real Actual correction; "
                "this is section COW, NOT annual-partitioned Actual or qualified historical time."
            ),
        }
        print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
