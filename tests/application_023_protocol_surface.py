from __future__ import annotations

from pathlib import Path


def section(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


def require(text: str, markers: list[str], label: str) -> None:
    for marker in markers:
        assert marker in text, f"{label}: missing marker: {marker}"


movement = Path("Loam/Cli/MovementCli.lean").read_text()
movement_admission = Path("Loam/MovementAdmission.lean").read_text()
scheduled = Path("Loam/Cli/ScheduledCli.lean").read_text()
correction = Path("Loam/Cli/CorrectionCli.lean").read_text()
capacity = Path("Loam/Cli/CapacityCli.lean").read_text()
basis = Path("Loam/Cli/QuantityBasisCorrectionCli.lean").read_text()
manifest_probe = Path("experiments/application_022_manifest_writer_amortization.lean").read_text()

# Keep the physical-save boundary identical to Application 022. These are the
# maximum fan-out paths, so optional retained evidence may skip some saves at
# runtime, but no operation can exceed the count measured here.
current_slices = {
    "Movement": section(
        movement,
        "if ← Loam.Persistence.saveActualValidityHistory?",
        "/--\nRecord one balanced human-facing JPY movement",
    ),
    "Scheduled completion": section(
        scheduled,
        "match existingCompletion with\n                                                      | none =>",
        "/--\nActivate one already-prepared Scheduled completion draft",
    ),
    "Event correction": section(
        correction,
        "let relationPublished ←",
        "/--\nAppend or resume one replacement Event",
    ),
    "Capacity": section(
        capacity,
        "if ← Loam.Persistence.saveCapacityEffectiveMemory?",
        "/-- Record one dated JPY capacity movement under capacity-file writer ownership. -/",
    ),
    "QuantityBasis correction": section(
        basis,
        "if ← Loam.Persistence.saveQuantityBasisCorrectionMemory?",
        "/--\nCorrect one current basis quantity append-only",
    ),
}

save_names = {
    "Movement": [
        "saveActualValidityHistory?",
        "saveEventDescriptionMemory?",
        "saveOpenRelationUnits?",
        "saveRelationDischarges?",
        "saveEventMemory?",
    ],
    "Scheduled completion": [
        "saveScheduledCompletionMemory?",
        "saveActualValidityHistory?",
        "saveEventDescriptionMemory?",
        "saveEventMemory?",
    ],
    "Event correction": [
        "saveEventCorrectionMemory?",
        "saveActualValidityHistory?",
        "saveEventMemory?",
    ],
    "Capacity": ["saveCapacityEffectiveMemory?", "saveCapacityMemory?"],
    "QuantityBasis correction": [
        "saveQuantityBasisCorrectionMemory?",
        "saveQuantityBasisMemory?",
    ],
}

save_counts: dict[str, int] = {}
for label, names in save_names.items():
    count = sum(current_slices[label].count(name) for name in names)
    save_counts[label] = count
    assert count == len(names), f"{label}: publication shape drifted"

# A maximum n-save ordered canonical publication has n-1 non-final durable
# prefixes where some changed families have been written but the operation's
# activating/final family has not yet completed. Application 019 already
# qualified that these prefixes can remain durable while readers stay safe.
partial_prefixes = {label: max(count - 1, 0) for label, count in save_counts.items()}

# Source evidence that current correctness/recovery policy is coupled to
# retained partial cross-family evidence. Application 034 moved Movement's
# identity/admission semantics into one production Movement-specific seam, while
# the sidecar publisher still carries the Event-last physical residue policy.
# The modes remain intentionally different across writers.
require(
    movement_admission,
    [
        "relationsMentionEvent world.relations candidate",
        "dischargesMentionEvent world.discharges candidate",
        "world.discharges.map (fun discharge => discharge.target)",
    ],
    "Movement admission residue identity policy",
)
require(
    movement,
    [
        "Loam.MovementAdmission.admit? world draft",
        "remains inert until that EventId exists",
    ],
    "Movement sidecar residue publication policy",
)
require(
    scheduled,
    [
        "completionRetained",
        "dateAlreadyRetained",
        "descriptionAlreadyRetained",
        "remains inert until that EventId exists",
    ],
    "Scheduled residue policy",
)
require(
    correction,
    [
        "pendingCorrectionForTarget?",
        "correctionMentionsEvent corrections candidate",
        "historyMentionsEvent history candidate",
        "remains resumable until its referenced event is present",
    ],
    "Event correction residue policy",
)
require(
    capacity,
    [
        "effectiveMentionsMovement effective candidate",
        "effectiveEvidenceComplete memory effective",
        "already-published effective evidence is inert and requires explicit recovery",
    ],
    "Capacity residue policy",
)
require(
    basis,
    [
        "replacement basis was not published; the correction remains inactive until its referenced basis is present",
    ],
    "QuantityBasis residue policy",
)

# Fresh identity allocation is widened by supporting-stream residue in these
# three current writers. Moving Movement's allocator behind the shared admission
# seam changes source ownership, not this semantic count. Scheduled completion
# uses a deterministic EventId plus retained-evidence collision checks instead,
# while QuantityBasis correction's fresh basis allocator only scans basis memory.
current_widened_fresh_identity_writers = 3

# The Application 022 scratch topology has one generic authority primitive and
# five meaning-specific adapters. All changed objects are prepared before the
# one manifest replacement. Object paths are content-addressed by family+digest,
# not EventId/RelationUnitId/etc., so unreferenced prepared objects do not reserve
# a semantic identity namespace.
infra = section(
    manifest_probe,
    "-- APPLICATION022_INFRA_START",
    "-- APPLICATION022_INFRA_END",
)
adapters = section(
    manifest_probe,
    "-- APPLICATION022_ADAPTERS_START",
    "-- APPLICATION022_ADAPTERS_END",
)
assert infra.count("private def publishChanges") == 1
assert adapters.count("publishChanges root current") == 5
assert infra.index("let prepared ← changes.mapM") < infra.index("publishManifest root next")
require(infra, ["familyName family", "digest ++ \".loam\"", "Loam.Sha256.hash"], "manifest object identity")

current_total_saves = sum(save_counts.values())
current_total_partial_prefixes = sum(partial_prefixes.values())

print(f"current_writer_specific_publication_protocols={len(current_slices)}")
print(f"current_cross_family_save_calls={current_total_saves}")
print(f"current_max_partial_authority_prefixes={current_total_partial_prefixes}")
print("current_writers_with_explicit_partial_residue_policy=5")
print(f"current_fresh_identity_allocators_widened_by_supporting_streams={current_widened_fresh_identity_writers}")
for label in current_slices:
    token = label.lower().replace(" ", "_")
    print(f"current_{token}_save_calls={save_counts[label]}")
    print(f"current_{token}_max_partial_prefixes={partial_prefixes[label]}")

print("manifest_shared_publication_primitives=1")
print("manifest_writer_adapters=5")
print("manifest_authority_switches_for_five_operations=5")
print("manifest_partial_authority_prefixes=0")
print("manifest_orphan_objects_reserve_semantic_identity=0")
print("manifest_added_reader_indirection_layers=1")
print("manifest_added_gc_obligation=1")
print("manifest_added_migration_obligation=1")
print("writer_ownership_still_required=1")

assert current_total_saves == 16
assert current_total_partial_prefixes == 11
