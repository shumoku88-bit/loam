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
scheduled = Path("Loam/Cli/ScheduledCli.lean").read_text()
correction = Path("Loam/Cli/CorrectionCli.lean").read_text()
capacity = Path("Loam/Cli/CapacityCli.lean").read_text()
basis = Path("Loam/Cli/QuantityBasisCorrectionCli.lean").read_text()
probe = Path("experiments/application_022_manifest_writer_amortization.lean").read_text()

current_tails = {
    "movement": section(
        movement,
        "if ← Loam.Persistence.saveActualValidityHistory?",
        "/--\nRecord one balanced human-facing JPY movement",
    ),
    "scheduled_completion": section(
        scheduled,
        "Loam.Persistence.saveScheduledCompletionMemory?",
        "/--\nActivate one already-prepared Scheduled completion draft",
    ),
    "event_correction": section(
        correction,
        "Loam.Persistence.saveEventCorrectionMemory?",
        "/--\nAppend or resume one replacement Event",
    ),
    "capacity": section(
        capacity,
        "Loam.Persistence.saveCapacityEffectiveMemory?",
        "/-- Record one dated JPY capacity movement under capacity-file writer ownership. -/",
    ),
    "quantity_basis_correction": section(
        basis,
        "Loam.Persistence.saveQuantityBasisCorrectionMemory?",
        "/--\nCorrect one current basis quantity append-only under basis-file writer ownership.",
    ),
}

current_lines = 0
current_bytes = 0
for name, text in current_tails.items():
    lines, size = stats(f"current_{name}_publication_tail", text)
    current_lines += lines
    current_bytes += size

print(f"current_five_writer_publication_tail_lines={current_lines}")
print(f"current_five_writer_publication_tail_bytes={current_bytes}")

infra = section(
    probe,
    "-- APPLICATION022_INFRA_START",
    "-- APPLICATION022_INFRA_END",
)
adapters = section(
    probe,
    "-- APPLICATION022_ADAPTERS_START",
    "-- APPLICATION022_ADAPTERS_END",
)
infra_lines, infra_bytes = stats("scratch_shared_manifest_infrastructure", infra)
adapter_lines, adapter_bytes = stats("scratch_five_writer_adapters", adapters)

scratch_lines = infra_lines + adapter_lines
scratch_bytes = infra_bytes + adapter_bytes
print(f"scratch_shared_plus_five_adapters_lines={scratch_lines}")
print(f"scratch_shared_plus_five_adapters_bytes={scratch_bytes}")
print(f"scratch_vs_current_tail_line_ratio={scratch_lines / current_lines:.3f}")
print(f"scratch_vs_current_tail_byte_ratio={scratch_bytes / current_bytes:.3f}")
print(f"scratch_minus_current_tail_lines={scratch_lines - current_lines}")
print(f"scratch_minus_current_tail_bytes={scratch_bytes - current_bytes}")

save_names = [
    "saveActualValidityHistory?",
    "saveEventDescriptionMemory?",
    "saveOpenRelationUnits?",
    "saveRelationDischarges?",
    "saveEventMemory?",
    "saveScheduledCompletionMemory?",
    "saveEventCorrectionMemory?",
    "saveCapacityEffectiveMemory?",
    "saveCapacityMemory?",
    "saveQuantityBasisCorrectionMemory?",
    "saveQuantityBasisMemory?",
]
current_save_calls = sum(
    sum(text.count(name) for name in save_names)
    for text in current_tails.values()
)
print(f"current_cross_family_save_calls={current_save_calls}")
print(f"scratch_writer_adapter_count={adapters.count('private def publish')}")
print(f"scratch_generic_authority_call_sites={adapters.count('publishChanges root current')}")

assert current_save_calls == 16
assert adapters.count("private def publish") == 5
assert adapters.count("publishChanges root current") == 5
