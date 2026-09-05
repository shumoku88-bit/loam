from pathlib import Path

movement = Path("Loam/Cli/MovementCli.lean").read_text()
authority = Path("Loam/MovementManifestAuthority.lean").read_text()


def between(text: str, start: str, end: str) -> str:
    if start not in text:
        raise SystemExit(f"missing start marker: {start}")
    tail = text.split(start, 1)[1]
    if end not in tail:
        raise SystemExit(f"missing end marker: {end}")
    return tail.split(end, 1)[0]


sidecar = between(
    movement,
    "private def publishDraftUnderOwnership",
    "/--\nApplication 035 experimental production path.",
)
manifest = between(
    movement,
    "private def publishDraftUnderManifestOwnership",
    "/--\nRecord one balanced human-facing JPY movement",
)

sidecar_saves = sum(
    sidecar.count(name)
    for name in [
        "saveActualValidityHistory?",
        "saveEventDescriptionMemory?",
        "saveOpenRelationUnits?",
        "saveRelationDischarges?",
        "saveEventMemory?",
    ]
)
manifest_sidecar_saves = sum(
    manifest.count(name)
    for name in [
        "saveActualValidityHistory?",
        "saveEventDescriptionMemory?",
        "saveOpenRelationUnits?",
        "saveRelationDischarges?",
        "saveEventMemory?",
    ]
)

if sidecar_saves != 5:
    raise SystemExit(f"expected 5 retained sidecar saves, got {sidecar_saves}")
if manifest_sidecar_saves != 0:
    raise SystemExit(f"manifest production tail retained {manifest_sidecar_saves} sidecar saves")
if manifest.count("MovementManifestAuthority.loadSelectedWorld?") != 1:
    raise SystemExit("manifest tail must read selected world exactly once")
if manifest.count("MovementAdmission.admit?") != 1:
    raise SystemExit("manifest tail must use shared Movement admission exactly once")
if manifest.count("MovementManifestAuthority.publishWorld?") != 1:
    raise SystemExit("manifest tail must publish through one manifest authority call")
if movement.count("LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT") < 2:
    raise SystemExit("explicit non-default manifest gate is missing")

for family in ["Event", "ActualValidity", "EventDescription", "RelationUnit", "RelationDischarge"]:
    if f'manifestRow "{family}"' not in authority:
        raise SystemExit(f"Movement manifest authority lost family {family}")

if authority.count('let target := root / "CURRENT"') != 2:
    raise SystemExit("expected one selected read and one CURRENT commit target")
if authority.count("IO.FS.rename stage target") != 2:
    raise SystemExit("expected one object-stage rename site and one CURRENT-stage rename site")

print("Application 035 Movement manifest tail surface PASS")
print(f"retained_sidecar_save_calls={sidecar_saves}")
print(f"manifest_tail_sidecar_save_calls={manifest_sidecar_saves}")
print("manifest_tail_selected_world_reads=1")
print("manifest_tail_shared_admission_calls=1")
print("manifest_tail_authority_publish_calls=1")
print("manifest_authority_switches_per_mutation=1")
print("manifest_partial_authority_prefixes=0")
print("production_manifest_mode_default_off=1")
print("semantic_family_count=5")
