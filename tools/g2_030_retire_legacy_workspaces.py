#!/usr/bin/env python3
from pathlib import Path
import re

MAIN = Path("Loam/Tui/Main.lean")
HRA_HOME = Path("Loam/Tui/HraHome.lean")
CLI = Path("Loam/Tui/Cli.lean")
TUI_ACTUAL = Path("Loam/Tests/TuiActual.lean")
TUI_SCHEDULED = Path("Loam/Tests/TuiScheduled.lean")
DAG = Path("docs/research/TUI_LEGACY_WORKSPACE_RETIREMENT_OBLIGATION_DAG.md")
DRAKON = Path("docs/drakon/build_tui_legacy_workspace_retirement_audit_map.py")

MAIN.write_text('''import Loam.ActualReview
import Loam.ScheduledReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel

namespace Loam.Tui.Main

open Loam.Tui.Kernel

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record
abbrev ScheduledRecord := Loam.ScheduledReview.Record
abbrev ScheduledEvidence := Loam.ScheduledReview.DayEvidence
abbrev ScheduledAvailability := Except String Loam.ScheduledReview.EvidenceSnapshot

structure ActualSnapshot where
  today : String
  allRecords : List ReviewRecord

/-- One admitted household read snapshot. It is process-local evidence, never TUI authority. -/
structure Snapshot where
  actual : ActualSnapshot
  /-- Scheduled refusal remains explicit and must never be reinterpreted as an empty household. -/
  scheduled : ScheduledAvailability

/-- Production root state now owns only Home date focus and a human-facing notice. -/
structure State where
  selectedDate : String
  notice : String := ""

inductive Event where
  | left
  | right
  | up
  | down
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false


def initialState (selectedDate : String) : State :=
  { selectedDate := selectedDate }


def plainLine (text : String) : Widget := .row [span text]
def mutedLine (text : String) : Widget := .row [span text .muted]
def blankLine : Widget := .row []


def recordsForDay (snapshot : Snapshot) (date : String) : List ReviewRecord :=
  Loam.ActualReview.select snapshot.actual.allRecords (.day date)


def moveDate (state : State) (offset : Int) : State :=
  match Loam.ActualDate.shiftDays? state.selectedDate offset with
  | none => { state with notice := "Calendar boundary reached." }
  | some date => { state with selectedDate := date, notice := "" }

/-- Home-only root navigation. Object workspaces own their own interaction state. -/
def update (_snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left => { state := moveDate state (-1) }
  | .right => { state := moveDate state 1 }
  | .up => { state := moveDate state (-7) }
  | .down => { state := moveDate state 7 }
  | .other => { state }


def selectedMonth (state : State) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? state.selectedDate).getD { year := 1970, month := 1 }


def calendarSlot (state : State) (row col : Nat) : Option String :=
  match (Loam.Tui.Calendar.slots (selectedMonth state))[row * 7 + col]? with
  | none => none
  | some date => date


def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.selectedDate


def homeScheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => .ok (Loam.ScheduledReview.dayEvidence scheduled state.selectedDate)

end Loam.Tui.Main
''')

home = HRA_HOME.read_text()
old_home_view = '''/-- Use the HRA-shaped Home while retaining existing production workspace views. -/\ndef view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=\n  match state.surface with\n  | .home _ => homeView bounds snapshot state\n  | .actual cursor .browse => Loam.Tui.Main.actualBrowseView cursor state\n  | .actual cursor .detail => Loam.Tui.Main.actualDetailView snapshot cursor\n  | .scheduled _ cursor mode => Loam.Tui.Main.scheduledView snapshot state cursor mode\n'''
new_home_view = '''/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/\ndef view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=\n  homeView bounds snapshot state\n'''
if old_home_view not in home:
    raise SystemExit("HraHome compatibility dispatcher anchor changed")
home = home.replace(old_home_view, new_home_view)
HRA_HOME.write_text(home)

cli = CLI.read_text()
cli, n = re.subn(
    r'''def eventOfKey : Loam\.Tui\.Terminal\.Key → Event\n(?:  \|.*\n)+?\n/-- HRA's Home navigation grammar''',
    '''def eventOfKey : Loam.Tui.Terminal.Key → Event\n  | .left => .left\n  | .right => .right\n  | .up => .up\n  | .down => .down\n  | .input 'q' => .quit\n  | .input 'Q' => .quit\n  | _ => .other\n\n/-- HRA's Home navigation grammar''',
    cli,
    count=1,
)
if n != 1:
    raise SystemExit("Cli eventOfKey anchor changed")
cli = cli.replace(
    '''  let key ← Loam.Tui.Terminal.readKey\n  let isHome := match state.surface with | .home _ => true | _ => false\n  let isActualBrowse := match state.surface with | .actual _ .browse => true | _ => false\n  if isHome && key = .enter then''',
    '''  let key ← Loam.Tui.Terminal.readKey\n  if key = .enter then''')
cli = cli.replace("else if isHome && ", "else if ")
cli = cli.replace("if isHome && ", "if ")
cli = cli.replace("surface := .home none, ", "")
cli = cli.replace(
    "else if (isHome || isActualBrowse) && (key = .input 'r' || key = .input 'R') then",
    "else if (key = .input 'r' || key = .input 'R') then")
old_destination = '''    let destination :=\n      if isActualBrowse then\n        { state with\n            surface := .actual (cursorForDay fresh state.selectedDate) .browse\n            notice := notice }\n      else\n        { state with notice := notice }\n'''
if old_destination not in cli:
    raise SystemExit("Cli legacy Record return anchor changed")
cli = cli.replace(old_destination, '''    let destination := { state with notice := notice }\n''')
cli = cli.replace(
    "    let event := if isHome then homeEventOfKey key else eventOfKey key",
    "    let event := homeEventOfKey key")
for stale in ["state.surface", "surface :=", "isHome", "isActualBrowse", "cursorForDay"]:
    if stale in cli:
        raise SystemExit(f"Cli legacy residue remains: {stale}")
CLI.write_text(cli)

actual = TUI_ACTUAL.read_text()
actual, n = re.subn(
    r'''\nprivate def initialCursor : Loam\.Tui\.Main\.ReviewCursor :=.*?\n\ndef main : IO Unit := do''',
    "\n\ndef main : IO Unit := do",
    actual,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit("TuiActual legacy helper anchor changed")
actual, n = re.subn(
    r'''\n  let start := initialCursor.*?\n  IO\.println "TUI Actual: HRA workspace mechanics and retained legacy navigation checks passed\."''',
    '\n  IO.println "TUI Actual: HRA workspace mechanics and production viewport checks passed."',
    actual,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit("TuiActual legacy regression anchor changed")
for stale in ["ReviewCursor", "moveReviewNext", "actualBrowseView", "reviewWindowStart", "visibleReviewRows"]:
    if stale in actual:
        raise SystemExit(f"TuiActual legacy residue remains: {stale}")
TUI_ACTUAL.write_text(actual)

TUI_SCHEDULED.write_text('''import Loam.Tui.HraHome
import Loam.Tui.Terminal

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

/-- Inspect structured glyph/style cells rather than terminal escape output. -/
private def hasStyledText (widget : Widget) (text : String) (style : Style) : Bool :=
  widget.lines.any fun cells =>
    (List.range (cells.length + 1)).any fun start =>
      let segment := (cells.drop start).take text.length
      String.ofList (segment.map Cell.glyph) == text &&
        segment.all (fun cell => cell.style == style)

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled? (index : Nat) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-100), change groceries 100]
  pure {
    id := ⟨"scheduled-" ++ toString index⟩
    scheduledOn := "2026-09-07"
    movement := movement
  }

private def fixtureSnapshot : IO Loam.Tui.Main.Snapshot := do
  let records ← requireSome ((List.range 12).mapM scheduled?)
    "Scheduled fixtures were not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? records)
    "Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    terminals := terminals
    events := events
  }
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := []
  }
  pure { actual := actual, scheduled := .ok scheduledSnapshot }

def main : IO Unit := do
  let snapshot ← fixtureSnapshot
  let home := Loam.Tui.Main.initialState "2026-09-07"
  let bounds : Bounds := { width := 140, height := 42 }

  match Loam.Tui.Main.homeScheduledEvidence snapshot home with
  | .ok (.due _ rest) =>
      expect (rest.length + 1 == 12)
        "Home selected-day Scheduled evidence lost retained due occurrences"
  | _ => throw (IO.userError "Home selected-day Scheduled evidence stopped being Due")

  let dueTodayView := Loam.Tui.HraHome.view bounds snapshot home
  expect (contains "Scheduled: Due (12)" (widgetText dueTodayView))
    "Home status lost the selected-day Scheduled due count"
  expect (hasStyledText dueTodayView "[07 ]" .selectedUnderlined)
    "Scheduled on Today was incorrectly marked Pending"

  let unknownHome := Loam.Tui.Main.initialState "2026-09-08"
  match Loam.Tui.Main.homeScheduledEvidence snapshot unknownHome with
  | .ok .unknown => pure ()
  | _ => throw (IO.userError "Home Scheduled evidence collapsed an unknown day")
  let unknownText := widgetText (Loam.Tui.HraHome.view bounds snapshot unknownHome)
  expect (contains "unknown; no completeness horizon is claimed" unknownText)
    "Home collapsed Scheduled Unknown into an empty-day claim"

  let pendingActual : Loam.Tui.Main.ActualSnapshot := {
    snapshot.actual with today := "2026-09-08"
  }
  let pendingSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := pendingActual
  }
  let pendingScheduled ←
    match pendingSnapshot.scheduled with
    | .error message => throw (IO.userError message)
    | .ok scheduled => pure scheduled
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-08" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect (pending.length == 12)
        "past-date current-open Scheduled projection lost retained occurrences"
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-07" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect pending.isEmpty
        "Scheduled due on the boundary was incorrectly classified as past-date pending"

  let pendingHome := Loam.Tui.Main.initialState "2026-09-08"
  let pendingText := widgetText (Loam.Tui.HraHome.view bounds pendingSnapshot pendingHome)
  expect (contains "Pending: 12" pendingText)
    "Home status did not expose the past-date current-open Scheduled count"
  expect (contains "Pending Scheduled:" pendingText)
    "Home did not expose its pending Scheduled section"
  expect (contains "2026-09-07  [Still open]" pendingText)
    "Home pending section lost the original expected date"
  expect (contains "07!" pendingText)
    "Home calendar did not mark the original date of a past-date current-open Scheduled"
  expect (contains "expected date passed; Scheduled is still current-open" pendingText)
    "Home calendar marker lost its non-rescheduling explanation"

  let sameDayView := Loam.Tui.HraHome.view bounds pendingSnapshot pendingHome
  expect (hasStyledText sameDayView "[08 ]" .selectedUnderlined)
    "Today + focus lost its combined presentation"
  expect (hasStyledText sameDayView " 07! " .normal)
    "Pending-only calendar cell changed"
  let moved := (Loam.Tui.Main.update pendingSnapshot pendingHome .right).state
  expect (moved.selectedDate == "2026-09-09") "Home focus did not advance"
  let movedView := Loam.Tui.HraHome.view bounds pendingSnapshot moved
  expect (hasStyledText movedView " 08  " .underlined)
    "Today indication followed focus instead of the snapshot date"
  expect (hasStyledText movedView "[09 ]" .selected)
    "Focus-only cell lost the existing selected style"
  let movedAgain := (Loam.Tui.Main.update pendingSnapshot moved .right).state
  let movedAgainView := Loam.Tui.HraHome.view bounds pendingSnapshot movedAgain
  expect (hasStyledText movedAgainView " 08  " .underlined &&
    hasStyledText movedAgainView "[10 ]" .selected &&
    hasStyledText movedAgainView " 09  " .normal)
    "Moving focus left stale emphasis or moved Today"

  -- A real Pending date is strictly before Today. Synthetic marker input checks
  -- presentation composition without weakening that evidence boundary.
  let overlap : Widget := .column <| (List.range 6).map fun row =>
    .row (Loam.Tui.HraHome.hraCalendarSpans "2026-09-08" ["2026-09-08"] moved row)
  expect (hasStyledText overlap " 08! " .underlined)
    "Synthetic Today + Pending lost its marker or underline"
  let focusedOverlap : Widget := .column <| (List.range 6).map fun row =>
    .row (Loam.Tui.HraHome.hraCalendarSpans "2026-09-08" ["2026-09-08"] pendingHome row)
  expect (hasStyledText focusedOverlap "[08!]" .selectedUnderlined)
    "Synthetic Today + Focus + Pending lost a presentation cue"

  -- SGR attributes accumulate: each style must clear the previous underline,
  -- background and dim attributes before setting its own (including dirty redraw).
  for style in [Style.normal, .selected, .muted, .underlined, .selectedUnderlined] do
    let sgr := Loam.Tui.Terminal.ansiStyle style
    expect (sgr.startsWith "\\x1b[0;" || sgr == "\\x1b[0m")
      "Terminal style can leak attributes into the next calendar cell"

  IO.println "TUI Scheduled: Home Unknown/Pending and independent Today/focus presentation passed."
''')

dag = DAG.read_text()
dag = dag.replace(
    "Status: **Generation-2 audit evidence — SIMPLIFY IDENTIFIED / MIGRATION REQUIRED**",
    "Status: **Generation-2 implementation — LEGACY WORKSPACE RETIRED / QUALIFICATION REQUIRED**")
dag += '''\n## Retirement implementation\n\nThe production HRA long-list bridge passed before removal. The branch now removes\n`ReviewCursor`, `ScheduledCursor`, browse/detail modes, legacy `Surface` variants,\nlegacy renderers, the hidden Tab entrance, and the Actual-browse return special\ncase. `Main.State` is reduced to selected Home date plus notice, while SelectedDay,\nHraActual, and HraScheduled remain the only object-workspace owners.\n\nThe implementation is not yet graduated until Production TUI, Compression Audit,\nand Selected Lean Observations pass on the retired topology.\n'''
DAG.write_text(dag)

drakon = DRAKON.read_text()
drakon = drakon.replace(
    '"audit": "Home Enter is intercepted by SelectedDay, a by HraActual, and p by HraScheduled. Legacy Main Actual has no normal entrance; physical Tab still falls through to Main.update and opens legacy Scheduled.",',
    '"audit": "Home Enter is owned by SelectedDay, a by HraActual, and p by HraScheduled. The retired root has no Actual/Scheduled Surface variants and physical Tab now falls through to a no-op Home event rather than opening a second Scheduled workspace.",')
drakon = drakon.replace(
    '''            ("decision", "Physical Tab?", "YES"),\n            ("action", "hidden compatibility -> Main.update .tab"),\n            ("action", "legacy Surface.scheduled"),''',
    '''            ("decision", "Physical Tab?", "NO DOCUMENTED ACTION"),\n            ("action", "Home event -> other / no-op"),\n            ("action", "no legacy workspace state exists"),''')
drakon = drakon.replace(
    '"audit": "ReviewCursor, ScheduledCursor, browse/detail modes, Surface Actual/Scheduled variants, old renderers, and compatibility dispatch form one connected island. Shared snapshots, Home date state, calendar helpers, and read helpers remain outside it.",',
    '"audit": "The compatibility island has been removed. Main now retains shared snapshots, Home date/notice state, date navigation, calendar helpers, and Home read projections only; object workspace state belongs to SelectedDay, HraActual, and HraScheduled.",')
drakon = drakon.replace(
    '''            ("action", "ReviewCursor / ScheduledCursor"),\n            ("action", "legacy Surface variants + transitions"),\n            ("action", "legacy browse/detail renderers"),\n            ("action", "HraHome compatibility dispatch"),\n            ("action", "Cli hidden Tab / legacy return handling"),\n            ("action", "RETIRE candidate after migration"),''',
    '''            ("action", "ReviewCursor / ScheduledCursor retired"),\n            ("action", "legacy Surface variants + transitions retired"),\n            ("action", "legacy browse/detail renderers retired"),\n            ("action", "HraHome renders Home only"),\n            ("action", "Cli hidden Tab / legacy return handling retired"),\n            ("action", "QUALIFY retired topology"),''')
drakon = drakon.replace(
    '"audit": "Only legacy tests currently reach the 11th row and verify a moving local window. Modern HRA workspaces have independent eight-row windows, so those guarantees must be tested directly before old cursor tests are deleted.",',
    '"audit": "The bridge is now explicit in production HRA tests: both HraActual and HraScheduled reach the 11th item, move their own eight-row viewport, keep selected detail synchronized, and refuse movement beyond the final row without moving selection.",')
drakon = drakon.replace(
    '''            ("action", "legacy 12-row tests"),\n            ("action", "migrate to HraActual / HraScheduled"),\n            ("decision", "production long-list tests green?", "YES"),\n            ("action", "retire legacy island"),\n            ("action", "full Production TUI qualification"),''',
    '''            ("action", "legacy 12-row guarantee identified"),\n            ("action", "migrated to HraActual / HraScheduled"),\n            ("decision", "production long-list tests green?", "YES"),\n            ("action", "legacy island retired"),\n            ("action", "full Production TUI qualification pending"),''')
DRAKON.write_text(drakon)

# Final static guards: production code must not retain the compatibility vocabulary.
checks = {
    MAIN: ["ReviewCursor", "ScheduledCursor", "ActualMode", "ScheduledMode", "Surface", "actualBrowseView", "scheduledBrowseView"],
    HRA_HOME: ["state.surface", "actualBrowseView", "scheduledView"],
    CLI: ["state.surface", "isActualBrowse", "cursorForDay", "Event.tab"],
    TUI_ACTUAL: ["ReviewCursor", "actualBrowseView", "reviewWindowStart"],
    TUI_SCHEDULED: ["ScheduledCursor", "scheduledBrowseView", "Main.update snapshot home .tab"],
}
for path, stale_terms in checks.items():
    text = path.read_text()
    for stale in stale_terms:
        if stale in text:
            raise SystemExit(f"{path}: legacy residue remains: {stale}")

print("G2-030 legacy workspace retirement staged")
