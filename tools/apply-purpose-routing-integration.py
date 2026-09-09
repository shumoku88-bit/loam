from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old!r}")
    path.write_text(text.replace(old, new, 1))


cli = Path("Loam/Tui/Cli.lean")
replace_once(
    cli,
    "import Loam.Tui.ScheduledRoutingSession\nimport Loam.Tui.Reports\n",
    "import Loam.Tui.ScheduledRoutingSession\n"
    "import Loam.Tui.ActualRoutingAdministration\n"
    "import Loam.Tui.ActualRoutingAdministrationSession\n"
    "import Loam.Tui.Reports\n",
)
replace_once(
    cli,
    "import Loam.CapacityReview\nimport Loam.CurrentCoverageReview\n",
    "import Loam.CapacityReview\n"
    "import Loam.CurrentCoverageReview\n"
    "import Loam.ActualRoutingReview\n",
)

capacity_entrance = """  else if isHome && (key = .input 'e' || key = .input 'E') then
    let capacitySnapshot ←
"""
admin_entrance = """  else if isHome && (key = .input 'u' || key = .input 'U') then
    let routingSnapshot ←
      match ← Loam.ActualRoutingReview.loadSnapshot dataDir root snapshot.actual.today with
      | .error message => throw (IO.userError message)
      | .ok routingSnapshot => pure routingSnapshot
    let administration := Loam.Tui.ActualRoutingAdministration.initial routingSnapshot
    let administrationFrame :=
      compileWidget (Loam.Tui.ActualRoutingAdministration.view bounds administration)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame administrationFrame
    let notice ← Loam.Tui.ActualRoutingAdministrationSession.run
      bounds (dataDir / "actual-routing.loam") administration administrationFrame
    let home := { state with surface := .home none, notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if isHome && (key = .input 'e' || key = .input 'E') then
    let capacitySnapshot ←
"""
replace_once(cli, capacity_entrance, admin_entrance)

home = Path("Loam/Tui/HraHome.lean")
replace_once(
    home,
    '"   Pending: " ++ pendingStatus ++\n    "   Budget: [c]   Capacity: [e]   Reports: [v]"',
    '"   Pending: " ++ pendingStatus ++\n    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Reports: [v]"',
)
replace_once(
    home,
    '  , mutedLine "   [c] Budget uses the current explicit preset; [e] raw Capacity/actions."\n',
    '  , mutedLine "   [c] Budget uses the current explicit preset; [e] raw Capacity/actions."\n'
    '  , mutedLine "   [u] Purpose routes audits explicit Expense Loci and edits Actual routing."\n',
)
replace_once(
    home,
    '[mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [v] reports  [q] quit"]',
    '[mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [v] reports  [q] quit"]',
)
replace_once(
    home,
    '    , mutedLine "[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [v] reports"\n',
    '    , mutedLine "[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [v] reports"\n',
)
