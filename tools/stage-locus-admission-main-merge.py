from pathlib import Path
import subprocess


def from_main(path: str) -> str:
    return subprocess.check_output(
        ["git", "show", f"origin/main:{path}"], text=True
    )

# Resolve Cli.lean from current main, then add only the Locus administration seam.
cli_path = Path("Loam/Tui/Cli.lean")
cli = from_main("Loam/Tui/Cli.lean")
if "import Loam.Tui.ActualRoutingAdministration\n" not in cli:
    raise SystemExit("Purpose routing administration import missing from current main")
imports = (
    "import Loam.Tui.LocusAdmissionAdministration\n"
    "import Loam.Tui.LocusAdmissionAdministrationSession\n"
)
if "import Loam.Tui.LocusAdmissionAdministration\n" not in cli:
    marker = "import Loam.LocusCatalog\n"
    if marker not in cli:
        raise SystemExit("LocusCatalog import marker missing")
    cli = cli.replace(marker, marker + imports, 1)

actual_marker = "  else if isHome && (key = .input 'a' || key = .input 'A') then\n"
admin_block = """  else if isHome && (key = .input 'm' || key = .input 'M') then
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
if "Loam.Tui.LocusAdmissionAdministration.initial catalog" not in cli:
    if actual_marker not in cli:
        raise SystemExit("Actual Home entrance marker missing")
    cli = cli.replace(actual_marker, admin_block + actual_marker, 1)
if "Loam.Tui.ActualRoutingAdministrationSession" not in cli:
    raise SystemExit("Purpose routing production seam was lost")
cli_path.write_text(cli, encoding="utf-8", newline="\n")

# Resolve HraHome.lean from current main and add Loci without removing Purpose routes.
home_path = Path("Loam/Tui/HraHome.lean")
home = from_main("Loam/Tui/HraHome.lean")
if "Purpose routes: [u]" not in home or "[u] purpose routes" not in home:
    raise SystemExit("Purpose routing Home affordance missing from current main")
home = home.replace(
    '    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Reports: [v]"',
    '    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Loci: [m]   Reports: [v]"',
    1,
)
home = home.replace(
    '[e] capacity  [u] purpose routes  [v] reports  [q] quit',
    '[e] capacity  [u] purpose routes  [m] loci  [v] reports  [q] quit',
    1,
)
home = home.replace(
    '[e] capacity  [u] purpose routes  [v] reports',
    '[e] capacity  [u] purpose routes  [m] loci  [v] reports',
    1,
)
if "Purpose routes: [u]   Loci: [m]" not in home:
    raise SystemExit("combined Purpose/Locus Home status was not produced")
if "[u] purpose routes  [m] loci" not in home:
    raise SystemExit("combined Purpose/Locus Home help was not produced")
home_path.write_text(home, encoding="utf-8", newline="\n")
