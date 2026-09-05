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


movement = Path("Loam/Cli/MovementCli.lean").read_text()
probe = Path("experiments/application_021_manifest_movement_probe.lean").read_text()

current_writer = section(
    movement,
    "private def publishDraftUnderOwnership",
    "/--\nRecord one balanced human-facing JPY movement",
)
current_publication_tail = section(
    movement,
    "if ← Loam.Persistence.saveActualValidityHistory?",
    "/--\nRecord one balanced human-facing JPY movement",
)
scratch_publish = section(
    probe,
    "-- APPLICATION021_PUBLISH_START",
    "-- APPLICATION021_PUBLISH_END",
)
scratch_infrastructure = section(
    probe,
    "private structure FamilyRef",
    "-- APPLICATION021_PUBLISH_START",
)

writer_lines, writer_bytes = stats("current_writer_boundary", current_writer)
tail_lines, tail_bytes = stats("current_publication_tail", current_publication_tail)
publish_lines, publish_bytes = stats("scratch_publish_boundary", scratch_publish)
infra_lines, infra_bytes = stats("scratch_manifest_infrastructure", scratch_infrastructure)

current_save_names = [
    "saveActualValidityHistory?",
    "saveEventDescriptionMemory?",
    "saveOpenRelationUnits?",
    "saveRelationDischarges?",
    "saveEventMemory?",
]
current_save_calls = sum(current_writer.count(name) for name in current_save_names)
print(f"current_cross_family_save_calls={current_save_calls}")
print(f"scratch_changed_object_preparations={scratch_publish.count('ensureObject root')}")
print(f"scratch_manifest_authority_switches={scratch_publish.count('publishManifest root next')}")

print(
    "scratch_publish_vs_current_tail_line_ratio="
    f"{publish_lines / tail_lines:.3f}"
)
print(
    "scratch_publish_plus_infra_vs_current_writer_line_ratio="
    f"{(publish_lines + infra_lines) / writer_lines:.3f}"
)

# Qualification here is intentionally structural, not a requirement that a
# prototype already wins every source metric. Keep the comparison honest by
# requiring the expected five current family publications and one manifest gate.
assert current_save_calls == 5
assert scratch_publish.count("ensureObject root") == 5
assert scratch_publish.count("publishManifest root next") == 1
