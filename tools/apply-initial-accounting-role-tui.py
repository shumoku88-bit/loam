from pathlib import Path


def replace_exact(path: Path, old: str, new: str, expected: int = 1) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} matches, found {count}: {old!r}")
    path.write_text(text.replace(old, new))


cli = Path("Loam/Tui/Cli.lean")
replace_exact(
    cli,
    "import Loam.Tui.LocusAdmissionAdministrationSession\n",
    "import Loam.Tui.LocusAdmissionAdministrationSession\n"
    "import Loam.AccountingRolePublisher\n"
    "import Loam.Tui.AccountingRoleAdministration\n"
    "import Loam.Tui.AccountingRoleAdministrationSession\n",
)

home_anchor = "  else if isHome && (key = .input 'm' || key = .input 'M') then\n"
role_block = """  else if isHome && (key = .input 'o' || key = .input 'O') then
    let world ←
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let scheduledFile := dataDir / "scheduled.loam"
    let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
      | throw (IO.userError "loam: Scheduled lifecycle authority is missing, malformed, or unsupported")
    let roleFile := dataDir / "accounting-role.loam"
    if !(← roleFile.pathExists) then
      throw (IO.userError "loam: AccountingRole authority file is missing")
    let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
      | throw (IO.userError "loam: AccountingRole authority is malformed or unsupported")
    let candidates := Loam.AccountingRolePublisher.eligibleInitialLoci
      world lifecycle.scheduled roles
    let admin := Loam.Tui.AccountingRoleAdministration.initial candidates
    let adminFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds admin)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame adminFrame
    let notice ← Loam.Tui.AccountingRoleAdministrationSession.run
      bounds scheduledFile root roleFile admin adminFrame
    let home := { state with surface := .home none, notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
"""
replace_exact(cli, home_anchor, role_block + home_anchor)

home = Path("Loam/Tui/HraHome.lean")
replace_exact(
    home,
    '    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Loci: [m]   Reports: [v]"\n',
    '    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Roles: [o]   Loci: [m]   Reports: [v]"\n',
)
replace_exact(
    home,
    '  , mutedLine "   [u] Purpose routes audits explicit Expense Loci and edits Actual routing."\n',
    '  , mutedLine "   [u] Purpose routes audits explicit Expense Loci and edits Actual routing."\n'
    '  , mutedLine "   [o] Roles assigns one first AccountingRole only to a virgin admitted Locus."\n',
)
replace_exact(
    home,
    '    [mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [m] loci  [v] reports  [q] quit"]\n',
    '    [mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [o] roles  [m] loci  [v] reports  [q] quit"]\n',
)
replace_exact(
    home,
    '    , mutedLine "[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [m] loci  [v] reports"\n',
    '    , mutedLine "[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [o] roles  [m] loci  [v] reports"\n',
)
