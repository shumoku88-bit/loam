from pathlib import Path

path = Path("Loam/Tui/Cli.lean")
text = path.read_text(encoding="utf-8")

import_marker = "import Loam.Tui.Record\n"
imports = (
    "import Loam.Tui.LocusAdmissionAdministration\n"
    "import Loam.Tui.LocusAdmissionAdministrationSession\n"
)
if "import Loam.Tui.LocusAdmissionAdministration\n" not in text:
    if import_marker not in text:
        raise SystemExit("Record import marker not found")
    text = text.replace(import_marker, imports + import_marker, 1)

marker = "  else if isHome && (key = .input 'a' || key = .input 'A') then\n"
block = """  else if isHome && (key = .input 'm' || key = .input 'M') then
    let world ←
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let catalog ← currentLocusCatalog dataDir world
    let admin := Loam.Tui.LocusAdmissionAdministration.initial catalog
    let adminFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds admin)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame adminFrame
    let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
      bounds root admin adminFrame
    let home := { state with surface := .home none, notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
"""
if "Loam.Tui.LocusAdmissionAdministration.initial catalog" not in text:
    if marker not in text:
        raise SystemExit("Home Actual entrance marker not found")
    text = text.replace(marker, block + marker, 1)

path.write_text(text, encoding="utf-8", newline="\n")
