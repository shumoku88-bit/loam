from pathlib import Path

path = Path("Loam/Tui/Cli.lean")
text = path.read_text()
old = """    let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
      bounds root admin adminFrame
"""
new = """    let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
      bounds dataDir root admin adminFrame
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f"expected exactly one Locus session caller, found {count}")
path.write_text(text.replace(old, new))
