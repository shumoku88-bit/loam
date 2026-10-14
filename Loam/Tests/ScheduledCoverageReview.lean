import Loam.Review.ScheduledCoverageReview
import Loam.Tui.ScheduledCoveragePane
import Loam.Tui.ScheduledWorkspace

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def widgetText (widgets : List Widget) : String :=
  String.intercalate "\n" <| widgets.flatMap fun widget =>
    widget.lines.map fun cells => String.ofList (cells.map Cell.glyph)

private def occurrence?
    (id date negative positive : String) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨negative⟩, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := ⟨positive⟩, quantity := Quantity.ofQuanta 1000 } ]
  pure { id := ⟨id⟩, scheduledOn := date, movement := movement }

private def checkBasics : IO Unit := do
  let monthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "gpt-plus"
    anchor := "2026-08-15"
    everyMonths := 1
    negativeLoci := ["cash"]
    positiveLoci := ["gpt-plus"]
  }
  let bimonthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "pension"
    anchor := "2026-09-15"
    everyMonths := 2
    negativeLoci := ["pension"]
    positiveLoci := ["cash"]
  }
  let emptyMonthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "utilities"
    anchor := "2026-08-15"
    everyMonths := 1
    negativeLoci := ["cash"]
    positiveLoci := ["utilities"]
  }
  expect (Loam.ScheduledCoverageReview.dateFallsOnExpectedMonth
      bimonthly "2026-11-20")
    "bimonthly monitoring did not recognize an expected calendar month"
  expect (!Loam.ScheduledCoverageReview.dateFallsOnExpectedMonth
      bimonthly "2026-12-15")
    "bimonthly monitoring treated an off-cadence month as expected"
  let some octGpt := occurrence? "scheduled-1" "2026-10-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture oct gpt")
  let some octGptLater := occurrence? "scheduled-1b" "2026-10-18" "cash" "gpt-plus"
    | throw (IO.userError "fixture second oct gpt")
  let some novGpt := occurrence? "scheduled-2" "2026-11-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture nov gpt")
  let some novPension := occurrence? "scheduled-3" "2026-11-15" "pension" "cash"
    | throw (IO.userError "fixture nov pension")
  let some decPension := occurrence? "scheduled-4" "2026-12-15" "pension" "cash"
    | throw (IO.userError "fixture off-pattern pension")

  let snapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [monthly, bimonthly, emptyMonthly]
        [octGpt, octGptLater, novGpt, novPension, decPension]
        [] "2026-10-14" 4 with
    | .error message => throw (IO.userError message)
    | .ok snapshot => pure snapshot

  expect (snapshot.months == ["2026-10", "2026-11", "2026-12", "2027-01"])
    "Scheduled coverage month grid did not start at the observation month"

  let some gpt := snapshot.rows[0]? | throw (IO.userError "missing monthly row")
  expect (gpt.firstMissing == some "2026-12")
    "monthly coverage did not expose the first missing expected month"
  let some pension := snapshot.rows[1]? | throw (IO.userError "missing bimonthly row")
  expect (pension.firstMissing == some "2027-01")
    "bimonthly coverage did not preserve anchor parity"
  let some octCell := gpt.cells[0]? | throw (IO.userError "missing October gpt cell")
  expect (octCell.explicitDays == ["15", "18"] && octCell.explicitCount == 2)
    "Scheduled coverage did not retain every explicit day in a matching month"

  let undecided := { monthly with everyMonths := 0 }
  let undecidedSnapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [undecided] [octGpt, octGptLater] [] "2026-10-14" 4 with
    | .error message => throw (IO.userError message)
    | .ok snapshot => pure snapshot
  let some undecidedRow := undecidedSnapshot.rows[0]?
    | throw (IO.userError "missing undecided row")
  expect (undecidedRow.firstMissing.isNone &&
    undecidedRow.cells.all fun cell => !cell.expected)
    "undecided Scheduled row still created future coverage expectations"

  let rendered := widgetText (Loam.Tui.ScheduledCoveragePane.lines snapshot)
  expect (contains "gpt-plus" rendered && contains "pension" rendered &&
    contains "utilities" rendered)
    "Scheduled coverage pane did not render configured plans"
  expect (contains "Plan" rendered && contains "Pace" rendered &&
    contains "Oct" rendered && contains "Nov" rendered)
    "Scheduled coverage pane did not render the Series Calendar header"
  expect (contains "15,18" rendered)
    "Scheduled coverage pane did not show multiple explicit days in one month"
  expect (contains "!" rendered)
    "Scheduled coverage pane did not mark a missing expected month"
  expect (!(contains "●" rendered) && !(contains "+" rendered))
    "Scheduled coverage calendar revived retired symbol cells"
  expect (contains "Empty cell = no occurrence expected" rendered)
    "Scheduled coverage pane did not explain intentionally empty months"
  expect (contains "does not create recurrence authority" rendered)
    "Scheduled coverage pane overstated read-side monitoring rules"
  let undecidedRendered :=
    widgetText (Loam.Tui.ScheduledCoveragePane.lines undecidedSnapshot)
  expect (contains "undecided" undecidedRendered && contains "15,18" undecidedRendered)
    "undecided Scheduled row did not remain visible with its explicit dates"

  -- The production framed table keeps the same days/gaps and never cuts a month column.
  for width in [10, 20, 32, 45, 77, 117] do
    let count := Loam.Tui.ScheduledCoveragePane.monthWindowSize width
    let table := Loam.Tui.ScheduledCoveragePane.tableWindow snapshot 0 0 count width 10
    expect (table.all fun widget => widget.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width)
      "Responsive Series Calendar cut a month column or exceeded its inner width"
  let narrowTable := widgetText
    (Loam.Tui.ScheduledCoveragePane.tableWindow snapshot 0 0 1 45 10)
  expect (contains "15,18" narrowTable && contains "!" narrowTable)
    "Narrow Series Calendar lost multiple explicit days or the missing-month marker"
  let undecidedTable := widgetText
    (Loam.Tui.ScheduledCoveragePane.tableWindow undecidedSnapshot 0 0 4 77 10)
  expect (contains "undecided" undecidedTable && contains "15,18" undecidedTable &&
      !contains "!" undecidedTable)
    "Framed Series Calendar invented future gaps for an undecided monitoring row"
  let longName := { gpt with rule := { gpt.rule with name := "日本語の非常に長いプラン名が列幅を超える場合" } }
  let clippedName := widgetText (Loam.Tui.ScheduledCoveragePane.tableWindow
    { snapshot with rows := [longName] } 0 0 1 45 10)
  expect (contains "…" clippedName && contains "15,18" clippedName)
    "Long plan labels hid their truncation or displaced the explicit-day column"

  let goodConfig :=
    "gpt-plus\t2026-08-15\t1\tcash\tgpt-plus\n" ++
    "pension\t2026-09-15\t2\tpension\tcash\n" ++
    "support\t2026-09-15\t2\tsupport\tcash\n"
  expect (Loam.ScheduledCoverageConfig.decode? goodConfig).isSome
    "Scheduled coverage config rejected valid monthly/bimonthly rules"
  expect (Loam.ScheduledCoverageConfig.decode?
      "undecided\t2026-09-15\t0\tpension\tcash\n").isSome
    "Scheduled coverage config rejected the explicit undecided read-side state"
  expect (Loam.ScheduledCoverageConfig.decode?
      "one\t2026-09-15\t1\tpension\tcash\ntwo\t2026-10-15\t2\tpension\tcash\n").isNone
    "Scheduled coverage config accepted an ambiguous duplicate signed-Locus selector"

  let changedMonthly := { monthly with anchor := "2026-10-15", everyMonths := 3 }
  let updated ←
    match Loam.ScheduledCoverageConfig.upsertRule [monthly, bimonthly] changedMonthly with
    | .error message => throw (IO.userError message)
    | .ok rules => pure rules
  let some updatedGpt := updated.find? (fun rule => rule.name == "gpt-plus")
    | throw (IO.userError "Scheduled coverage upsert lost existing rule")
  expect (updatedGpt.anchor == "2026-10-15" && updatedGpt.everyMonths == 3 &&
    updated.length == 2)
    "Scheduled coverage upsert did not replace the matching signed-Locus monitor in place"
  expect (Loam.ScheduledCoverageConfig.encode? updated).isSome
    "Scheduled coverage writer could not encode its updated rule set"

  let removed := Loam.ScheduledCoverageConfig.removeShape
    updated changedMonthly.negativeLoci changedMonthly.positiveLoci
  expect (removed.length == 1 &&
    !(removed.any fun rule => rule.name == "gpt-plus"))
    "Scheduled coverage monitoring removal did not remove only the matching plan shape"

  let conflictingName : Loam.ScheduledCoverageConfig.Rule := {
    name := "gpt-plus"
    anchor := "2026-10-15"
    everyMonths := 1
    negativeLoci := ["other-source"]
    positiveLoci := ["other-target"]
  }
  match Loam.ScheduledCoverageConfig.upsertRule [monthly] conflictingName with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError
      "Scheduled coverage upsert silently reused a display name for a different plan shape")

private def checkCompletedCoverage : IO Unit := do
  let monthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "gpt-plus"
    anchor := "2026-08-15"
    everyMonths := 1
    negativeLoci := ["cash"]
    positiveLoci := ["gpt-plus"] }
  let some octGpt := occurrence? "scheduled-1" "2026-10-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture completed October")
  let some octGptLater := occurrence? "scheduled-1b" "2026-10-18" "cash" "gpt-plus"
    | throw (IO.userError "fixture open October")
  let some novGpt := occurrence? "scheduled-2" "2026-11-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture open November")
  -- Lifecycle evidence, not disappearance from the open frontier, covers a completed month.
  let some scheduled := ScheduledMemory.ofOccurrences? [octGpt, octGptLater, novGpt]
    | throw (IO.userError "fixture Scheduled memory")
  let some event := Event.ofEffects? ⟨"paid"⟩ []
    | throw (IO.userError "fixture completion Event")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "fixture Event memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals?
      [{ source := octGpt.id, target := some (.actual event.id) }]
    | throw (IO.userError "fixture completed terminal")
  let evidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events }
  let completed ← match Loam.ScheduledCoverageReview.projectEvidence
      [monthly] evidence "2026-10-14" 4 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some completedRow := completed.rows[0]?
    | throw (IO.userError "missing completed row")
  let some mixed := completedRow.cells[0]?
    | throw (IO.userError "missing current-month cell")
  expect (mixed.explicitDays == ["18"] && mixed.completedDays == ["15"] &&
      !mixed.isMissing && completedRow.firstMissing == some "2026-12")
    "Completed current-month evidence hid an open date or created a false gap"
  let text := widgetText (Loam.Tui.ScheduledCoveragePane.lines completed)
  expect (contains "15✓,18" text)
    "Series Calendar did not distinguish completed and open Scheduled dates"
  let mainSnapshot : Loam.Tui.Main.Snapshot := {
    actual := { today := "2026-10-14", allRecords := [] }
    scheduled := .ok evidence }
  let detail := Loam.Tui.ScheduledWorkspace.planDetailEntries mainSnapshot completedRow
  expect (detail.length == 4)
    "Plan Detail reintroduced a false missing row for a completed month"
  let source := Loam.Tui.ScheduledWorkspace.replenishmentSourceForRow? mainSnapshot completedRow
  expect (source.map (·.id) == some novGpt.id)
    "Coverage replenishment selected completed evidence as an actionable source"
  for bounds in [{ width := 32, height := 9 }, { width := 48, height := 9 },
      { width := 48, height := 14 }, { width := 80, height := 24 },
      { width := 120, height := 30 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds mainSnapshot
      (Loam.Tui.ScheduledWorkspace.initial "2026-10-14") (.ok completed)
    expect (rendered.lines.length <= bounds.height - 1 && rendered.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
          Loam.Tui.Layout.contentWidth bounds)
      "Completed-month Series Calendar exceeded terminal bounds"
    if bounds.width >= 48 then
      expect (contains "Scheduled Series Calendar" (widgetText [rendered]))
        "Completion legend hid the compact Series Calendar heading"

  let onlyCompleted := { evidence with
    scheduled := (← match ScheduledMemory.ofOccurrences? [octGpt] with
      | none => throw (IO.userError "fixture completed-only memory")
      | some memory => pure memory) }
  let doneOnly ← match Loam.ScheduledCoverageReview.projectEvidence
      [monthly] onlyCompleted "2026-10-14" 2 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  expect (doneOnly.rows.head?.bind (·.firstMissing) == some "2026-11")
    "Completed-only current month was still marked missing"
  let dimmed := Loam.Tui.ScheduledCoveragePane.tableWindow doneOnly 0 0 2 77 10
  -- An unselected completed-only cell stays quiet.
  let unselected := Loam.Tui.ScheduledCoveragePane.tableWindow
    { doneOnly with rows := completedRow :: doneOnly.rows } 0 0 2 77 10
  expect (contains "15✓" (widgetText dimmed) && unselected.any fun widget =>
      widget.lines.any fun cells => cells.any fun cell => cell.glyph == '✓' && cell.style == .muted)
    "Completed-only month lost its day/check mark or quiet style"
  let packed := { mixed with
    explicitDays := ["01", "02", "03"]
    explicitCount := 3
    completedDays := ["04", "05"] }
  let crowded := { completed with rows := [{ completedRow with cells := [packed] }] }
  let crowdedTable := Loam.Tui.ScheduledCoveragePane.tableWindow crowded 0 0 1 45 10
  expect (contains "3p/2✓" (widgetText crowdedTable) && crowdedTable.all fun widget =>
      widget.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= 45)
    "Mixed occurrence counts overflowed or erased completion status"

  for terminal in [
      { source := octGpt.id, target := none },
      { source := octGpt.id, target := some (.scheduled octGptLater.id) }] do
    let some memory := ScheduledTerminalMemory.ofTerminals? [terminal]
      | throw (IO.userError "fixture cancellation/replacement terminal")
    let closed ← match Loam.ScheduledCoverageReview.projectEvidence
        [monthly] { evidence with terminals := memory } "2026-10-14" 2 with
      | .error message => throw (IO.userError message)
      | .ok result => pure result
    let some cell := closed.rows.head?.bind (·.cells.head?)
      | throw (IO.userError "missing cancelled/replaced month")
    expect (cell.explicitDays == ["18"] && cell.completedDays.isEmpty)
      "Cancellation or a replaced source masqueraded as completion"
  let some cancelled := ScheduledTerminalMemory.ofTerminals?
      [{ source := octGpt.id, target := none }]
    | throw (IO.userError "fixture cancelled-only terminal")
  let cancelledOnly ← match Loam.ScheduledCoverageReview.projectEvidence
      [monthly] { onlyCompleted with terminals := cancelled } "2026-10-14" 2 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  expect (cancelledOnly.rows.head?.bind (·.firstMissing) == some "2026-10")
    "Cancelled-only current month hid a real monitored gap"
  let some noEvents := EventMemory.ofEvents? []
    | throw (IO.userError "fixture empty Event memory")
  let inert ← match Loam.ScheduledCoverageReview.projectEvidence
      [monthly] { evidence with events := noEvents } "2026-10-14" 2 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some inertCell := inert.rows.head?.bind (·.cells.head?)
    | throw (IO.userError "missing inert-completion month")
  expect (inertCell.explicitDays == ["15", "18"] && inertCell.completedDays.isEmpty)
    "Coverage activated an inert completion with no retained Actual Event"
  let some conflicting := ScheduledTerminalMemory.ofTerminals?
      [{ source := octGpt.id, target := none },
       { source := octGpt.id, target := some (.actual event.id) }]
    | throw (IO.userError "fixture competing terminals")
  expect (!(Loam.ScheduledCoverageReview.projectEvidence
      [monthly] { evidence with terminals := conflicting } "2026-10-14" 2).isOk)
    "Coverage bypassed conflicting lifecycle evidence"
  expect (!(Loam.ScheduledCoverageReview.projectRecords [monthly] []
      [{ octGpt with scheduledOn := "2026-02-30" }] "2026-10-14" 2).isOk)
    "Coverage admitted an invalid completed Scheduled date"
  let yearEnd ← match Loam.ScheduledCoverageReview.projectRecords
      [monthly] [] [] "2026-12-31" 2 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  expect (yearEnd.months == ["2026-12", "2027-01"])
    "Inclusive current-month window lost the year boundary"

def main : IO Unit := do
  checkBasics
  checkCompletedCoverage
  IO.println "Scheduled coverage: current-month open/completed/gap evidence, lifecycle refusal, config updates, and bounded TUI passed."
