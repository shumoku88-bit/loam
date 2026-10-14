#!/usr/bin/env python3
"""Declarative inventory comparison, not a kernel check; accepts two raw evidence ZIPs."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile


def inventory(path):
    with zipfile.ZipFile(path) as archive:
        rows = [json.loads(line) for line in archive.read("inventory.jsonl").splitlines()]
    return rows[0]["modules"], rows[1:]


a_path, b_path = map(Path, sys.argv[1:])
a_owners, a = inventory(a_path)
b_owners, b = inventory(b_path)
a_theorems = {(r["owner"], r["name"]) for r in a if r["theorem"]}
b_theorems = {(r["owner"], r["name"]) for r in b if r["theorem"]}
assert a_owners == b_owners and len(a_owners) == 22
assert len(a_theorems) == 415 and a_theorems == b_theorems
assert any("admitAll?_isSome_eq_currentUnitsAdmissible" in name for _, name in b_theorems)
assert any("buildCoverageIndex_getD_eq_currentCoverageFor" in name for _, name in b_theorems)
a_names, b_names = {r["name"] for r in a}, {r["name"] for r in b}
print(json.dumps(dict(
    evidence_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [a_path, b_path]},
    owners_equal=True, modules=len(a_owners), theorem_owner_names_equal=True,
    theorems=len(a_theorems), source_private_correspondence_proofs_present=True,
    baseline_declarations=len(a), candidate_declarations=len(b),
    removed=sorted(a_names - b_names), added=sorted(b_names - a_names)
), indent=2))
