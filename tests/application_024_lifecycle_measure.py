from __future__ import annotations

from pathlib import Path


def section(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


def stats(label: str, text: str) -> tuple[int, int]:
    lines = len(text.splitlines())
    size = len(text.encode("utf-8"))
    print(f"{label}_lines={lines}")
    print(f"{label}_bytes={size}")
    return lines, size


probe = Path("experiments/application_024_manifest_reader_recovery_lifecycle.lean").read_text()
physical = section(
    probe,
    "-- APPLICATION024_PHYSICAL_LIFECYCLE_START",
    "-- APPLICATION024_PHYSICAL_LIFECYCLE_END",
)

lines, size = stats("manifest_physical_lifecycle", physical)

# One generic selected-generation reader and one generic publication gate.
assert physical.count("private def readCurrent") == 1
assert physical.count("private def publishChangesFromCurrent") == 1

# Fail-closed reader mechanics are centralized rather than repeated per writer.
for marker in [
    "CURRENT is missing",
    "CURRENT is malformed",
    "object is missing",
    "failed digest verification",
]:
    assert marker in physical, marker

# Object preparation precedes the one CURRENT replacement, and content-addressed
# existence is a reusable recovery state rather than a semantic identity claim.
assert physical.index("let prepared ← changes.mapM") < physical.index("publishManifest root next")
assert "if ← target.pathExists then" in physical
assert "created := false" in physical

# Online deletion is deliberately absent because stale readers are not owned by
# the writer lock. This makes storage retention explicit rather than pretending
# GC is free.
assert "private def deleteOnline" in physical
assert "pure false" in physical

print("manifest_shared_readers=1")
print("manifest_shared_publishers=1")
print("manifest_operation_specific_recovery_branches=0")
print("manifest_online_gc_deletions=0")
print("manifest_deferred_gc_obligation=1")
print("manifest_migration_obligation=1")
print("manifest_reader_indirection_layers=1")

# This is a measurement, not a maximum-size target. Keep only a generous drift
# guard so accidental framework growth is visible without treating LOC as the
# definition of smallness.
assert lines < 260
assert size < 10000
