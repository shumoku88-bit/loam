from pathlib import Path

# Make the new Home entrance discoverable without changing Home semantics.
home_path = Path("Loam/Tui/HraHome.lean")
home = home_path.read_text(encoding="utf-8")
home = home.replace(
    '    "   Budget: [c]   Capacity: [e]   Reports: [v]"',
    '    "   Budget: [c]   Capacity: [e]   Loci: [m]   Reports: [v]"',
)
home = home.replace(
    '[i] attention  [c] budget  [e] capacity  [v] reports  [q] quit',
    '[i] attention  [c] budget  [e] capacity  [m] loci  [v] reports  [q] quit',
)
home = home.replace(
    '[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [v] reports',
    '[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [m] loci  [v] reports',
)
if "Loci: [m]" not in home or "[m] loci" not in home:
    raise SystemExit("Home Locus entrance help patch did not apply")
home_path.write_text(home, encoding="utf-8", newline="\n")

# Generate the intended Production TUI workflow update as an ordinary temporary file.
# The GitHub connector will copy this validated text into the protected workflow path.
tui_path = Path(".github/workflows/tui.yml")
tui = tui_path.read_text(encoding="utf-8")
path_marker = "      - 'Loam/Tests/LocusCatalog.lean'\n"
path_add = (
    "      - 'Loam/Tests/LocusCatalog.lean'\n"
    "      - 'Loam/LocusAdmissionPublisher.lean'\n"
    "      - 'Loam/Tests/LocusAdmissionPublisher.lean'\n"
    "      - 'Loam/Tests/TuiLocusAdmissionAdministration.lean'\n"
)
count = tui.count(path_marker)
if count != 2:
    raise SystemExit(f"expected two LocusCatalog path markers, found {count}")
tui = tui.replace(path_marker, path_add)

step_marker = (
    "      - name: Verify display/history and admission-scoped Locus catalog\n"
    "        run: lake env lean --run Loam/Tests/LocusCatalog.lean\n\n"
)
step_add = step_marker + (
    "      - name: Build shared Locus admission publisher boundary\n"
    "        run: lake build Loam.LocusAdmissionPublisher\n\n"
    "      - name: Verify add-only manifest-backed Locus admission\n"
    "        run: lake env lean --run Loam/Tests/LocusAdmissionPublisher.lean \"$(mktemp -d)/locus-admission\"\n\n"
    "      - name: Verify Locus admission administration interaction\n"
    "        run: lake env lean --run Loam/Tests/TuiLocusAdmissionAdministration.lean\n\n"
)
if tui.count(step_marker) != 1:
    raise SystemExit("Production TUI catalog test marker not unique")
tui = tui.replace(step_marker, step_add, 1)

out = Path("tmp/tui-locus-admission.generated.yml")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(tui, encoding="utf-8", newline="\n")
