#!/usr/bin/env python3
"""Drive the native Lean HouseholdAuthority against disposable synthetic images.

Requires a built Lean project and tools/benchmark-daily-pace-knowledge.py.
No operational household root, loam-data, or user-supplied file is touched.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT / "tools" / "benchmark-daily-pace-knowledge.py"


def previous_module():
    spec = importlib.util.spec_from_file_location("knowledge_reference", PREVIOUS)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclass inspects sys.modules
    spec.loader.exec_module(module)
    return module


def source_body(rows, previous):
    # Real normalized-Actual codec will validate the synthetic Event body.
    parts = ["LOAM-NORMALIZED-ACTUAL\t4\n"]
    for row in rows:
        if row.kind == "K" and row.identity.startswith("actual:"):
            parts.append(
                f"TX\t{row.identity}\t{previous.iso(row.day)}\tNODESC\n"
                "EFFECT\tbank\tjpy\t-1\n"
                "EFFECT\twifi\tjpy\t1\n"
                "ENDTX\n"
            )
    return "".join(parts)


def wire(sections):
    return "LOAM-HOUSEHOLD-IMAGE\t2\n" + "".join(
        f"SECTION\t{name}\t{len(body)}\n{body}" for name, body in sections
    )


def parse_lean(text):
    matched = [line.split("\t") for line in text.splitlines() if line.startswith("BENCH\t")]
    if len(matched) != 1 or len(matched[0]) != 9:
        raise AssertionError(f"unexpected native Lean result: {text[-3000:]}")
    return dict(zip((
        "initial_bytes", "final_bytes", "previous_bytes",
        "install_us", "qualified_load_us", "publish_us", "post_publish_load_us"
    ), map(int, matched[0][2:])))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--years", nargs="+", type=int, default=[1, 10, 20])
    parser.add_argument("--per-year", nargs="+", type=int, default=[50, 730])
    parser.add_argument("--read-rounds", type=int, default=3)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if any(y <= 0 for y in args.years) or any(n < 0 for n in args.per_year) or args.read_rounds < 1:
        parser.error("years and read-rounds > 0; per-year >= 0")
    previous = previous_module()
    results = []
    with tempfile.TemporaryDirectory(prefix="loam-household-knowledge-probe-") as tmp:
        root = Path(tmp)
        for years in args.years:
            for yearly in args.per_year:
                _, rows = previous.make_entries(years, yearly)
                grouped = {}
                base = source_body(rows, previous)
                extension = (
                    "TX\tnew-benchmark-event\t2026-10-15\tNODESC\n"
                    "EFFECT\tbank\tjpy\t-1\nEFFECT\twifi\tjpy\t1\nENDTX\n"
                )
                for mode, payload in (
                    ("tagged", previous.encode_tagged(rows)),
                    ("bucketed", previous.encode_bucketed(rows)),
                ):
                    work = root / f"{years}-{yearly}-{mode}"
                    work.mkdir()
                    # UNKNOWN research section. Not a new admitted canonical
                    # family; actual publisher must refuse editing it.
                    image = wire((
                        ("Actual", base),
                        ("ResearchKnowledge", payload.decode("ascii")),
                    ))
                    seed = work / "seed.txt"
                    seed.write_text(image, encoding="utf-8")
                    new_body = work / "next-actual.txt"
                    new_body.write_text(base + extension, encoding="utf-8")
                    destination = work / "live"
                    run = subprocess.run([
                        "lake", "env", "lean", "--run",
                        "tools/BenchHouseholdKnowledge.lean", str(destination),
                        str(seed), str(new_body), str(args.read_rounds)
                    ], cwd=ROOT, text=True, capture_output=True, check=True)
                    parsed = parse_lean(run.stdout)
                    assert parsed["initial_bytes"] == len(image.encode("utf-8"))
                    assert parsed["previous_bytes"] == parsed["initial_bytes"]
                    assert parsed["final_bytes"] - parsed["initial_bytes"] == len(extension)
                    grouped[mode] = parsed
                tagged, bucketed = grouped["tagged"], grouped["bucketed"]
                assert tagged["final_bytes"] - bucketed["final_bytes"] == (
                    len(previous.encode_tagged(rows)) - len(previous.encode_bucketed(rows))
                )
                results.append({
                    "years": years, "per_year": yearly,
                    "existing_actual_events": base.count("ENDTX\n"),
                    "reference_rows": len(rows),
                    "tagged": tagged, "bucketed": bucketed,
                    "metadata_bytes_saved_in_complete_image":
                        tagged["initial_bytes"] - bucketed["initial_bytes"],
                    "preservation_and_stale_rejection": True,
                })
    print(json.dumps({
        "method": "native Lean HouseholdImage qualification/install/load/Actual publish; knowledge is an unknown research section, not admitted canonical data",
        "read_rounds": args.read_rounds,
        "results": results
    }, indent=2))


if __name__ == "__main__":
    main()
