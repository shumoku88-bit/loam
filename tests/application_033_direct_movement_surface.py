from __future__ import annotations

from pathlib import Path


def section(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


def source_metrics(text: str) -> tuple[int, int]:
    return (len(text.splitlines()), len(text.encode("utf-8")))


movement = Path("Loam/Cli/MovementCli.lean").read_text()
probe = Path("experiments/application_033_direct_movement_manifest_adapter.lean").read_text()

current_publisher = section(
    movement,
    "private def publishDraftUnderOwnership",
    "/--\nRecord one balanced human-facing JPY movement",
)
current_save_names = [
    "saveActualValidityHistory?",
    "saveEventDescriptionMemory?",
    "saveOpenRelationUnits?",
    "saveRelationDischarges?",
    "saveEventMemory?",
]
current_save_calls = sum(current_publisher.count(name) for name in current_save_names)
assert current_save_calls == 5, "Movement publication save surface drifted"
current_partial_authority_prefixes = current_save_calls - 1

# The current production function still combines world reload, fresh identity
# allocation, admission, residue policy, and the five ordered sidecar saves.
for marker in [
    "freshRecordEventId?",
    "freshRelationUnitIds?",
    "relationPublicationAdmissible",
    "dischargePublicationAdmissible",
    "saveActualValidityHistory?",
    "saveEventMemory?",
]:
    assert marker in current_publisher, f"current Movement publisher drifted: {marker}"

# Application 033 copies only the admission shape into scratch because the
# corresponding production seam is private. This is deliberately measured as a
# remaining obligation rather than hidden as shared code.
scratch_admission = section(
    probe,
    "private def historyMentionsEvent",
    "private def effect",
)
for marker in [
    "freshRecordEventId?",
    "freshRelationUnitIds?",
    "relationPublicationAdmissible",
    "dischargePublicationAdmissible",
    "private def admitMovement?",
]:
    assert marker in scratch_admission, f"scratch admission marker disappeared: {marker}"

# The direct manifest mutation adapter begins from selected typed authority and
# prepares the admitted world directly. It has no sidecar materialization or
# sidecar persistence calls.
direct_adapter = section(
    probe,
    "private def runPrepareMutation",
    "private def runCommit",
)
assert "readCurrentTyped root" in direct_adapter
assert "admitMovement? current draft" in direct_adapter
assert "prepareWorld root admitted.world" in direct_adapter
assert "writeCandidate root manifest" in direct_adapter
for save_name in current_save_names:
    assert save_name not in direct_adapter, f"direct adapter regained sidecar save: {save_name}"
assert "writeWorldToSidecars" not in probe
assert "sidecar_materializations=0" in direct_adapter
assert "sidecar_save_calls=0" in direct_adapter

# The manifest mutation path itself never invokes the production writer. The CI
# workflow invokes loamMovement only later to build an independent comparison
# oracle, so this source probe keeps that distinction explicit.
manifest_mutation_sidecar_writer_protocols = 0
manifest_mutation_sidecar_save_calls = 0
manifest_partial_authority_prefixes = 0
manifest_authority_switches_per_mutation = 1
scratch_admission_rule_copy = 1
production_admission_seam_reused = 0
production_sidecar_writer_still_exists = 1
production_migration_earned = 0

current_lines, current_bytes = source_metrics(current_publisher)
admission_lines, admission_bytes = source_metrics(scratch_admission)
adapter_lines, adapter_bytes = source_metrics(direct_adapter)
manifest_mechanics = section(
    probe,
    "private structure FamilyRef where",
    "private def emptyWorld",
)
manifest_lines, manifest_bytes = source_metrics(manifest_mechanics)

print(f"current_movement_publisher_lines={current_lines}")
print(f"current_movement_publisher_bytes={current_bytes}")
print(f"current_movement_cross_family_save_calls={current_save_calls}")
print(f"current_movement_max_partial_authority_prefixes={current_partial_authority_prefixes}")
print(f"scratch_direct_admission_lines={admission_lines}")
print(f"scratch_direct_admission_bytes={admission_bytes}")
print(f"scratch_direct_adapter_lines={adapter_lines}")
print(f"scratch_direct_adapter_bytes={adapter_bytes}")
print(f"scratch_manifest_mechanics_lines={manifest_lines}")
print(f"scratch_manifest_mechanics_bytes={manifest_bytes}")
print(f"manifest_mutation_sidecar_writer_protocols={manifest_mutation_sidecar_writer_protocols}")
print(f"manifest_mutation_sidecar_save_calls={manifest_mutation_sidecar_save_calls}")
print(f"manifest_partial_authority_prefixes={manifest_partial_authority_prefixes}")
print(f"manifest_authority_switches_per_mutation={manifest_authority_switches_per_mutation}")
print(f"scratch_admission_rule_copy={scratch_admission_rule_copy}")
print(f"production_admission_seam_reused={production_admission_seam_reused}")
print(f"production_sidecar_writer_still_exists={production_sidecar_writer_still_exists}")
print(f"production_migration_earned={production_migration_earned}")

assert current_partial_authority_prefixes == 4
assert manifest_mutation_sidecar_writer_protocols == 0
assert manifest_mutation_sidecar_save_calls == 0
assert manifest_partial_authority_prefixes == 0
assert manifest_authority_switches_per_mutation == 1
assert scratch_admission_rule_copy == 1
assert production_admission_seam_reused == 0
assert production_sidecar_writer_still_exists == 1
assert production_migration_earned == 0
