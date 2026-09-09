from pathlib import Path


def replace_exact(path: Path, old: str, new: str, expected: int = 1) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} matches, found {count}: {old!r}")
    path.write_text(text.replace(old, new))


workflow = Path('.github/workflows/tui.yml')

path_anchor = "      - 'Loam/Tests/TuiLocusAdmissionAdministration.lean'\n      - 'Loam/Tui/**'\n"
path_block = (
    "      - 'Loam/Tests/TuiLocusAdmissionAdministration.lean'\n"
    "      - 'Loam/AccountingRolePublisher.lean'\n"
    "      - 'Loam/Persistence/AccountingRolePersistence.lean'\n"
    "      - 'Loam/Tests/AccountingRolePublisher.lean'\n"
    "      - 'Loam/Tests/TuiAccountingRoleAdministration.lean'\n"
    "      - 'Loam/Tui/**'\n"
)
replace_exact(workflow, path_anchor, path_block, expected=2)

step_anchor = """      - name: Verify Locus admission administration interaction
        run: lake env lean --run Loam/Tests/TuiLocusAdmissionAdministration.lean

      - name: Run shared Actual review checks
"""
step_block = """      - name: Verify Locus admission administration interaction
        run: lake env lean --run Loam/Tests/TuiLocusAdmissionAdministration.lean

      - name: Build shared initial AccountingRole publisher boundary
        run: lake build Loam.AccountingRolePublisher

      - name: Verify virgin-Locus initial AccountingRole publication
        run: lake env lean --run Loam/Tests/AccountingRolePublisher.lean "$(mktemp -d)/accounting-role"

      - name: Verify AccountingRole administration interaction
        run: lake env lean --run Loam/Tests/TuiAccountingRoleAdministration.lean

      - name: Run shared Actual review checks
"""
replace_exact(workflow, step_anchor, step_block)
