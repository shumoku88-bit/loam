#!/usr/bin/env python3
"""One-time offline migration tool from legacy LOAM multi-stream topology to single-file normalized Actual.

Converts:
  <data_dir>/movement-authority/
  <data_dir>/corrections.loam
  <data_dir>/actual-reversals.loam
Into:
  <data_dir>/actual.loam
  <data_dir>/locus-admission.loam

And optionally removes the legacy multi-stream files when --apply is provided.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
from pathlib import Path

# Add tools directory to path
tools_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(tools_dir))

from current_to_normalized_actual import project, read_selected_objects
from normalized_actual import encode, parse


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def extract_locus_admission(root: Path) -> bytes:
    current = root / "movement-authority" / "CURRENT"
    if not current.is_file():
        raise RuntimeError("missing movement-authority/CURRENT")
    lines = current.read_text(encoding="utf-8").splitlines()
    for line in lines[1:]:
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) == 3 and fields[0] == "LocusAdmission":
            _, relative, digest = fields
            obj_path = root / "movement-authority" / relative
            if not obj_path.is_file():
                raise RuntimeError(f"missing LocusAdmission object: {obj_path}")
            data = obj_path.read_bytes()
            if sha256(data) != digest:
                raise RuntimeError("LocusAdmission digest mismatch")
            return data
    raise RuntimeError("LocusAdmission row not found in CURRENT manifest")


def perform_migration(data_dir: Path, apply: bool = False) -> None:
    data_dir = data_dir.resolve()
    print(f"=== LOAM Normalized Actual Offline Migration ===")
    print(f"Target directory: {data_dir}")
    print(f"Mode: {'APPLY (destructive cutover)' if apply else 'PREFLIGHT / DRY-RUN'}")

    # 1. Verify existence of legacy files
    movement_authority = data_dir / "movement-authority"
    corrections_file = data_dir / "corrections.loam"
    reversals_file = data_dir / "actual-reversals.loam"

    if not movement_authority.is_dir():
        raise RuntimeError(f"Missing directory: {movement_authority}")

    # 2. Extract and project actual.loam
    print("Projecting legacy movement-authority into normalized Actual...")
    actual_model = project(data_dir)
    actual_bytes = encode(actual_model)
    print(f"  Projected {len(actual_model.txs)} transactions, {len(actual_bytes)} bytes")

    # Verify round-trip parsing
    reparsed = parse(actual_bytes)
    assert len(reparsed.txs) == len(actual_model.txs), "Transaction count mismatch on re-parse"
    print("  Round-trip parse of actual.loam bytes: SUCCESS")

    # 3. Extract locus-admission.loam
    print("Extracting LocusAdmission policy into locus-admission.loam...")
    locus_bytes = extract_locus_admission(data_dir)
    locus_lines = locus_bytes.decode("utf-8").splitlines()
    assert locus_lines[0] == "LOAM-LOCUS-ADMISSION-VOCABULARY\t1", "Invalid LocusAdmission header"
    loci_count = len([l for l in locus_lines[1:] if l.startswith("LOCUS\t")])
    print(f"  Extracted {loci_count} approved Loci, {len(locus_bytes)} bytes")

    target_actual = data_dir / "actual.loam"
    target_locus = data_dir / "locus-admission.loam"

    if not apply:
        print("\n--- PREFLIGHT SUMMARY ---")
        print(f"Would create: {target_actual} ({len(actual_bytes)} bytes)")
        print(f"Would create: {target_locus} ({len(locus_bytes)} bytes)")
        print(f"Would remove: {movement_authority}")
        if corrections_file.is_file():
            print(f"Would remove: {corrections_file}")
        if reversals_file.is_file():
            print(f"Would remove: {reversals_file}")
        print("\nPreflight check PASSED cleanly. Run with --apply to execute cutover.")
        return

    # 4. Atomic write of new canonical files
    print("\nWriting new canonical files atomically...")
    stage_actual = data_dir / "actual.loam.loam-stage"
    stage_locus = data_dir / "locus-admission.loam.loam-stage"

    stage_actual.write_bytes(actual_bytes)
    os.replace(stage_actual, target_actual)
    print(f"  Published: {target_actual}")

    stage_locus.write_bytes(locus_bytes)
    os.replace(stage_locus, target_locus)
    print(f"  Published: {target_locus}")

    # 5. Remove legacy files
    print("Retiring legacy files...")
    shutil.rmtree(movement_authority)
    print(f"  Removed: {movement_authority}")
    if corrections_file.is_file():
        corrections_file.unlink()
        print(f"  Removed: {corrections_file}")
    if reversals_file.is_file():
        reversals_file.unlink()
        print(f"  Removed: {reversals_file}")

    print("\nMigration completed successfully! Production runtime is now NEW-ONLY.")


def main() -> int:
    parser = argparse.ArgumentParser(description="One-time offline migration to normalized Actual.")
    parser.add_argument("data_dir", type=Path, help="Path to loam-data root")
    parser.add_argument("--apply", action="store_true", help="Execute migration (modifies repository)")
    args = parser.parse_args()

    try:
        perform_migration(args.data_dir, apply=args.apply)
        return 0
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
