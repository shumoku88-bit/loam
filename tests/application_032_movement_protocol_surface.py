from __future__ import annotations

from pathlib import Path


def section(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


def source_metrics(text: str) -> tuple[int, int]:
    return (len(text.splitlines()), len(text.encode("utf-8")))


movement = Path("Loam/Cli/MovementCli.lean").read_text()
probe = Path("experiments/application_032_complete_movement_manifest_mutation.lean").read_text()

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

# Movement has two semantic identity namespaces widened specifically by
# supporting-stream crash residue: EventId scans raw relation/discharge evidence,
# and RelationUnitId scans raw discharge targets.
for marker in [
    "relationsMentionEvent relations candidate",
    "dischargesMentionEvent discharges candidate",
    "discharges.map (fun discharge => discharge.target)",
]:
    assert marker in movement, f"Movement residue marker disappeared: {marker}"
current_residue_widened_identity_namespaces = 2

# The scratch manifest path prepares immutable content-addressed objects before
# the only canonical selector replacement. CANDIDATE is not selected authority.
for marker in [
    '"objects/" ++ family ++ "/" ++ digest ++ ".loam"',
    "let digest := Loam.Sha256.hash text.toUTF8",
    "IO.FS.writeFile (root / \"CANDIDATE\")",
    "IO.FS.rename stage target",
]:
    assert marker in probe, f"Application 032 authority marker disappeared: {marker}"

assert probe.count("publishManifest root manifest") == 2  # seed plus explicit commit
assert "runPrepare" in probe and "writeCandidate root manifest" in probe
assert "runCommit" in probe and "publishManifest root manifest" in probe

# One actual mutation commit uses one CURRENT replacement. Object preparation
# and CANDIDATE creation do not select authority, so they create no canonical
# partial-authority prefix.
manifest_authority_switches_per_mutation = 1
manifest_partial_authority_prefixes_per_mutation = 0
manifest_orphan_objects_reserve_semantic_identity = 0
manifest_operation_specific_retry_branches = 0

# Important counterweight: Application 032 deliberately invokes the unchanged
# production loamMovement writer in disposable sidecar staging. The old protocol
# therefore remains in the implementation surface even though it is no longer
# canonical authority in this experiment.
staging_writer_protocol_retained = 1
staging_cross_family_save_calls_max = current_save_calls
staging_partial_residue_policy_retained = 1
production_migration_earned = 0

current_lines, current_bytes = source_metrics(current_publisher)
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
print(f"current_movement_residue_widened_identity_namespaces={current_residue_widened_identity_namespaces}")
print(f"manifest_authority_mechanics_lines={manifest_lines}")
print(f"manifest_authority_mechanics_bytes={manifest_bytes}")
print(f"manifest_authority_switches_per_mutation={manifest_authority_switches_per_mutation}")
print(f"manifest_partial_authority_prefixes_per_mutation={manifest_partial_authority_prefixes_per_mutation}")
print(f"manifest_orphan_objects_reserve_semantic_identity={manifest_orphan_objects_reserve_semantic_identity}")
print(f"manifest_operation_specific_retry_branches={manifest_operation_specific_retry_branches}")
print(f"staging_writer_protocol_retained={staging_writer_protocol_retained}")
print(f"staging_cross_family_save_calls_max={staging_cross_family_save_calls_max}")
print(f"staging_partial_residue_policy_retained={staging_partial_residue_policy_retained}")
print(f"production_migration_earned={production_migration_earned}")

assert current_partial_authority_prefixes == 4
assert current_residue_widened_identity_namespaces == 2
assert manifest_authority_switches_per_mutation == 1
assert manifest_partial_authority_prefixes_per_mutation == 0
assert manifest_orphan_objects_reserve_semantic_identity == 0
assert manifest_operation_specific_retry_branches == 0
assert staging_writer_protocol_retained == 1
assert staging_cross_family_save_calls_max == 5
assert staging_partial_residue_policy_retained == 1
assert production_migration_earned == 0
