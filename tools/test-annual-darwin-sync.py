#!/usr/bin/env python3
"""Darwin/APFS syscall reconnaissance for the annual source publisher.

Compiles a tiny C syscall witness and uses it ONLY in a new throwaway directory.
Reports syscall availability separately for files and directories. A successful
readback is never described as a power-loss guarantee or a product qualification.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

if sys.platform != "darwin":
    raise SystemExit("DARWIN_ANNUAL_PROBE_REFUSED: Darwin only")


def execute(binary: Path, api: str, kind: str, path: Path) -> dict[str, str]:
    p = subprocess.run(
        [str(binary), api, kind, str(path)],
        text=True, capture_output=True, timeout=30, check=False,
    )
    if p.returncode not in (0, 3, 4):
        raise RuntimeError(f"invalid sync helper status {p.returncode}: {p.stderr}")
    return {
        "api": api, "kind": kind, "path_kind": path.name,
        "status": {0: "ok", 3: "unsupported", 4: "error"}[p.returncode],
        "detail": (p.stdout if p.returncode == 0 else p.stderr).strip(),
    }


def run_case(binary: Path, parent: Path, api: str, fail_at: str | None = None) -> dict:
    root = parent / (api + ("-inject-" + fail_at if fail_at else "-normal"))
    year = root / "journal" / "2027"
    year.mkdir(parents=True)
    observations: list[dict] = []

    def barrier(label: str, kind: str, path: Path) -> bool:
        if label == fail_at:
            observations.append({
                "api": api, "kind": kind, "path_kind": path.name,
                "status": "injected", "detail": "deliberate test refusal",
            })
            return False
        result = execute(binary, api, kind, path)
        observations.append({"cut": label, **result})
        return result["status"] == "ok"

    def finish(outcome: str, head_visible: bool) -> dict:
        head = root / "HEAD"
        if head.exists() != head_visible:
            raise AssertionError("HEAD name unexpectedly changed")
        if head_visible and head.read_bytes() != b"PUB\\t2027\\t1\\n":
            raise AssertionError("HEAD process-visible bytes changed")
        return {
            "api": api, "injection": fail_at, "outcome": outcome,
            "head_visible": head_visible, "observations": observations,
        }

    # Sync newly created directory names before allowing the HEAD to depend
    # on their contents. Unsupported directories must NOT be silently skipped.
    for name, path in (
        ("year_directory_setup", year),
        ("journal_directory_setup", root / "journal"),
        ("root_directory_setup", root),
        ("root_parent_setup", root.parent),
    ):
        if not barrier(name, "directory", path):
            return finish("refused_before_head", False)

    source_stage = year / "1.full.loam.stage"
    source = year / "1.full.loam"
    source_stage.write_bytes(b"SYNTHETIC-NOT-CANONICAL-ANNUAL-SOURCE\\n")
    if not barrier("source_stage_file", "file", source_stage):
        return finish("refused_before_head", False)
    os.replace(source_stage, source)
    if not barrier("installed_source_file", "file", source):
        return finish("refused_before_head", False)
    if not barrier("installed_source_directory", "directory", year):
        return finish("refused_before_head", False)

    head_stage = root / "HEAD.stage"
    head_stage.write_bytes(b"PUB\\t2027\\t1\\n")
    if not barrier("head_stage_file", "file", head_stage):
        return finish("refused_before_head", False)

    os.replace(head_stage, root / "HEAD")
    if not barrier("head_directory_after_replace", "directory", root):
        # The name has been replaced. Failure cannot be treated as rollback.
        return finish("outcome_unknown", True)
    return finish("barriers_returned_not_power_proof", True)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-annual-darwin-probe-") as folder:
        parent = Path(folder)
        binary = parent / "annual-darwin-sync-probe"
        subprocess.run([
            "cc", "-std=gnu11", "-Wall", "-Wextra", "-Werror",
            "-o", str(binary), "tools/annual-darwin-sync-probe.c",
        ], check=True, timeout=90)

        # A symlink must never be accepted as a file or directory target.
        safe = parent / "safe"
        safe.write_text("test-only", encoding="ascii")
        link = parent / "alias"
        link.symlink_to(safe)
        denial = execute(binary, "fsync", "file", link)
        if denial["status"] == "ok":
            raise AssertionError("O_NOFOLLOW was ignored")

        results = [run_case(binary, parent, api) for api in ("fsync", "fullfsync")]
        before = run_case(binary, parent, "fsync", "source_stage_file")
        if before["outcome"] != "refused_before_head" or before["head_visible"]:
            raise AssertionError("pre-HEAD failure was admitted")
        after = run_case(binary, parent, "fsync", "head_directory_after_replace")
        if after["outcome"] == "outcome_unknown" and not after["head_visible"]:
            raise AssertionError("post-HEAD error was misclassified")
        if after["outcome"] not in ("outcome_unknown", "refused_before_head"):
            raise AssertionError("injected post-HEAD directory sync unexpectedly succeeded")

        if not any(o["status"] == "ok" for r in results for o in r["observations"]
                   if o["kind"] == "file"):
            raise AssertionError("no successful file synchronization syscall")

        print(json.dumps({
            "marker": "ANNUAL_DARWIN_SYNC_PROBE_COMPLETED_NOT_QUALIFIED",
            "system": platform.platform(), "machine": platform.machine(),
            "symlink_target_refused": True,
            "results": results, "failure_injection": [before, after],
            "warning": "Process-visible results only. Unsupported directory flushes "
                       "block admission; no fallback; no simulated power loss.",
        }, indent=2))
        print("ANNUAL_DARWIN_SYNC_PROBE_PASS (API observation only)")


if __name__ == "__main__":
    main()
