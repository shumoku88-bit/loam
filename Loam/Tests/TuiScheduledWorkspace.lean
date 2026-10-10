import Loam.Review.ScheduledCoverageReview
import Loam.Review.ScheduledCoverageSelector
import Loam.Tui.Main
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.ScheduledCoverageSetup

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def yen : MeasureId := ⟨"jpy"⟩

private def change (locus : String) (quanta : Int) : MovementChange LocusId :=
  { coordinate := ⟨locus⟩, quantity := Quantity.ofQuanta quanta }

private def scheduledRecord?
    (id date fromLocus toLocus : String) (quanta : Int) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change fromLocus (-quanta), change toLocus quanta]
  pure {
    id := ⟨id⟩
    scheduledOn := date
    movement := movement
  }

private def scheduledWorkspaceSnapshot : IO Loam.Tui.Main.Snapshot := do
  let first ← requireSome (scheduledRecord? "scheduled-0" "2026-09-07" "paypay" "food" 100)
    "first Scheduled fixture was not admitted"
  let second ← requireSome (scheduledRecord? "scheduled-1" "2026-09-07" "smbc" "paypay" 200)
    "second Scheduled fixture was not admitted"
  let future ← requireSome (scheduledRecord? "scheduled-2" "2026-09-08" "paypay" "books" 300)
    "future-day Scheduled fixture was not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [first, second, future])
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

private def longScheduledWorkspaceSnapshot (count : Nat) : IO Loam.Tui.Main.Snapshot := do
  let rows ← requireSome
    ((List.range count).mapM fun index =>
      scheduledRecord? ("scheduled-long-" ++ toString index) "2026-09-07"
        "wallet" "food" (Int.ofNat (index + 1)))
    "long Scheduled fixtures were not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? rows)
    "long Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted for long fixture"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted for long fixture"
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

private def checkNavigationFooter
    (snapshot : Loam.Tui.Main.Snapshot)
    (coverageSnapshot : Loam.ScheduledCoverageReview.Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.State) : IO Unit := do
  -- Both framed workspaces have two operation rows at the physical bottom.
  -- Bright keys and dim labels are separate spans, never additional accent colors.
  for mode in [Loam.Tui.ScheduledWorkspace.ViewMode.coverage, .planDetail] do
    for width in [32, 48, 80, 120, 180] do
      let bounds : Bounds := { width, height := 24 }
      let footerState := { coverage with viewMode := mode }
      let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage
        bounds snapshot footerState (.ok coverageSnapshot)
      let lastTwo := rendered.lines.drop (rendered.lines.length - 2)
      let footerText := widgetText (.column (lastTwo.map fun cells =>
        Widget.row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)))
      expect (lastTwo.length == 2 && contains "[q]" footerText &&
          !contains "MISSING" footerText && !contains "guidance" footerText &&
          lastTwo.all (fun cells =>
            Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width - 1 &&
            cells.all (fun cell => cell.style == .normal || cell.style == .muted)) &&
          lastTwo.all (fun cells => (cells.filter (fun cell => cell.glyph == '[')).all
            (fun cell => cell.style == .normal)))
        "Framed Scheduled footer was not two bounded operation-only rows with bright keys"
      if width >= 80 then
        for key in ["[e]", "[b]", "[p]", "[s]"] do
          expect (contains key footerText) "Desktop footer hid an existing maintenance action"
      let withBoundary := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot
        { footerState with notice := "At first row." } (.ok coverageSnapshot)
      let borderRows := fun (widget : Widget) => widget.lines.zipIdx.filterMap fun (cells, index) =>
        if cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰') then some index else none
      expect (borderRows rendered == borderRows withBoundary &&
          rendered.lines.drop (rendered.lines.length - 2) ==
            withBoundary.lines.drop (withBoundary.lines.length - 2))
        "Ordinary feedback shifted the Scheduled frame or operation bar"
      let bottomBorder ← requireSome (borderRows rendered).getLast?
        "Scheduled operation-footer specimen lost its table frame"
      let nextLine := String.ofList ((rendered.lines[bottomBorder + 1]?.getD []).map Cell.glyph)
      expect (contains (if mode == .coverage then "days" else "Explicit dates") nextLine)
        "Scheduled meaning legend was not adjacent to the table"
  let opaqueCause := "publisher-refused-" ++ String.ofList (List.replicate 100 'x')
  for mode in [Loam.Tui.ScheduledWorkspace.ViewMode.coverage, .planDetail] do
    let text := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 48, height := 30 } snapshot { coverage with viewMode := mode, notice := opaqueCause }
      (.ok coverageSnapshot))
    expect (contains opaqueCause (text.replace "\n" ""))
      "Scheduled status clipped an unbroken publisher refusal token"

private def checkMonthsLayout : IO Unit := do
  let snapshot ← longScheduledWorkspaceSnapshot 40
  let state : Loam.Tui.ScheduledWorkspace.State := {
    focusDate := "2026-09-07", viewMode := .futureBoard, occurrenceRow := 35 }
  let selected ← requireSome (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state)
    "Months layout specimen lost its selected occurrence"
  let quantity := Loam.MeasurePresentation.groupDisplayedNumber
    (toString (selected.quantityAt ⟨"food"⟩).quanta) ++ " jpy"
  let borderRows := fun (widget : Widget) => widget.lines.zipIdx.filterMap fun (cells, index) =>
    if cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰') then some index else none
  for bounds in [{ width := 80, height := 18 }, { width := 80, height := 24 },
      { width := 120, height := 30 }, { width := 144, height := 50 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.view bounds snapshot state
    let text := widgetText rendered
    let selectedLines := rendered.lines.filter fun cells => cells.any
      (fun cell => cell.style == .selected)
    expect (selectedLines.length == 1 && contains quantity
        (String.ofList ((selectedLines.flatten.filter (fun cell => cell.style == .selected)).map Cell.glyph)) &&
        contains "40 explicit" text && !contains "====" text)
      "Framed Months lost its selected row, exact quantity, or explicit count"
    for month in ["2026-09", "2026-10", "2026-11", "2026-12", "2027-01", "2027-02"] do
      expect (contains ("╭ " ++ month) text) "Framed Months did not retain all six calendar months"
    expect (rendered.lines.all fun cells => cells.all fun cell =>
        cell.style == .normal || cell.style == .muted ||
        cell.style == .series1 || cell.style == .selected)
      "Months added decorative accent colors"
    if bounds.height >= 24 then
      expect (contains ("+" ++ quantity) text && contains ("-" ++ quantity) text &&
          contains ("ID: " ++ selected.id.token) text && contains "Selected Scheduled" text)
        "Months details lost signed quantities or the exact selected identity"
    let notice := Loam.Tui.ScheduledWorkspace.view bounds snapshot
      { state with notice := "At first month." }
    let next := Loam.Tui.ScheduledWorkspace.view bounds snapshot { state with occurrenceRow := 36 }
    expect (borderRows rendered == borderRows notice && borderRows rendered == borderRows next)
      "Months geometry changed with a short notice or a different selected occurrence"
    let lastTwo := rendered.lines.drop (rendered.lines.length - 2)
    expect (lastTwo.length == 2 && lastTwo.all (fun cells => cells.all
        (fun cell => cell.style == .normal || cell.style == .muted)))
      "Months did not reuse the operation-only two-row footer"
  for width in [0, 1, 2, 20, 32, 48, 80, 120] do
    for height in [0, 1, 2, 6, 10, 18, 24, 50] do
      let rendered := Loam.Tui.ScheduledWorkspace.view { width, height } snapshot state
      expect (rendered.lines.length <= height - 1 && rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth { width, height }))
        "Months escaped its physical terminal rectangle"
  let narrow := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 48, height := 24 } snapshot state)
  expect (contains "Months [compact]" narrow && contains "[v] List" narrow &&
      contains "Selected Scheduled" narrow && contains selected.id.token narrow)
    "Narrow Months lost its List fallback or selected-record detail"
  let failed := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 }
    { snapshot with scheduled := .error "Scheduled read refused" } state)
  expect (contains "Months [Unavailable]" failed && contains "Scheduled read refused" failed &&
      !contains "0 explicit" failed && !contains "No explicit plan" failed)
    "Months collapsed failed Scheduled evidence into empty month counts"
  let refusal := "publisher refuses the complete cause " ++ String.ofList (List.replicate 100 'x')
  let refused := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 48, height := 30 }
    snapshot { state with notice := refusal })
  expect (contains (String.ofList (List.replicate 100 'x')) (refused.replace "\n" ""))
    "Months clipped an unbroken publisher refusal token"

private def checkListLayout : IO Unit := do
  let snapshot ← longScheduledWorkspaceSnapshot 40
  let state := { Loam.Tui.ScheduledWorkspace.initialList "2026-09-07" with occurrenceRow := 35 }
  let selected ← requireSome (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state)
    "List layout specimen lost its selected occurrence"
  let quantity := Loam.MeasurePresentation.groupDisplayedNumber
    (toString (selected.quantityAt ⟨"food"⟩).quanta) ++ " jpy"
  let borderRows := fun (widget : Widget) => widget.lines.zipIdx.filterMap fun (cells, index) =>
    if cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰') then some index else none
  for bounds in [{ width := 80, height := 24 }, { width := 100, height := 30 },
      { width := 140, height := 40 }, { width := 48, height := 10 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.view bounds snapshot state
    let text := widgetText rendered
    let selection := rendered.lines.flatten.filter (fun cell => cell.style == .selected)
    expect (contains quantity (String.ofList (selection.map Cell.glyph)) &&
        contains "36/40" text && contains "Date" text && contains "Quanta" text &&
        !contains "====" text)
      "List lost its aligned columns, selected quantity, or selection position"
    if bounds.height >= 24 then
      expect (contains selected.id.token text && contains ("+" ++ quantity) text &&
          contains ("-" ++ quantity) text)
        "List detail changed the selected identity or signed movement quantities"
    let blocked := Loam.Tui.ScheduledWorkspace.view bounds snapshot
      { state with notice := "No next Scheduled row." }
    let next := Loam.Tui.ScheduledWorkspace.view bounds snapshot { state with occurrenceRow := 36 }
    expect (borderRows rendered == borderRows blocked && borderRows rendered == borderRows next)
      "List geometry changed with ordinary feedback or selection"
    expect (rendered.lines.all fun cells => cells.all fun cell =>
        cell.style == .normal || cell.style == .muted ||
        cell.style == .series1 || cell.style == .selected)
      "List introduced decorative accent colors"
  for width in [0, 1, 2, 20, 32, 48, 80, 120] do
    for height in [0, 1, 2, 6, 10, 18, 24, 50] do
      for pane in [Loam.Tui.ScheduledWorkspace.Pane.loci, .occurrences] do
        let rendered := Loam.Tui.ScheduledWorkspace.view { width, height } snapshot { state with pane }
        expect (rendered.lines.length <= height - 1 && rendered.lines.all (fun cells =>
            Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
              Loam.Tui.Layout.contentWidth { width, height }))
          "List escaped its physical rectangle in one of its focus panes"
  let mixed ← scheduledWorkspaceSnapshot
  let all := (Loam.Tui.ScheduledWorkspace.update mixed
    (Loam.Tui.ScheduledWorkspace.initialList "2026-09-07") .cycleFilter).state
  let foodIndex ← requireSome (((Loam.Tui.ScheduledWorkspace.lociForScope mixed all).zipIdx.find?
    (fun (token, _) => token == "food")).map Prod.snd) "mixed List fixture lost food"
  let filtered := { all with pane := .loci, locusRow := foodIndex + 1 }
  let filteredRecord ← requireSome (Loam.Tui.ScheduledWorkspace.selectedRecord? mixed filtered)
    "List filtering lost its exact selected occurrence"
  expect (filteredRecord.id.token == "scheduled-0" &&
      (Loam.Tui.ScheduledWorkspace.visibleRecords mixed filtered).length == 1)
    "List Locus filtering changed the canonical browse selection"
  let leftText := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 48, height := 24 } mixed filtered)
  let right := (Loam.Tui.ScheduledWorkspace.update mixed filtered .focusRight).state
  let rightText := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 48, height := 24 } mixed right)
  expect (contains "╭ Loci" leftText && !contains "╭ Scheduled (" leftText &&
      contains "Locus: food" rightText && contains "╭ Scheduled (1)" rightText &&
      contains filteredRecord.id.token rightText && !contains "scheduled-1" rightText &&
      !contains "scheduled-2" rightText)
    "Compact List showed the wrong focus pane or leaked nonmatching occurrences"
  let unavailable := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 }
    { mixed with scheduled := .error "List read refused" } all)
  let unknown := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } mixed
    (Loam.Tui.ScheduledWorkspace.initialList "2026-09-09"))
  let emptyMemory ← requireSome (ScheduledMemory.ofOccurrences? []) "empty List memory was not admitted"
  let evidence ← match mixed.scheduled with
    | .error message => throw (IO.userError message)
    | .ok evidence => pure evidence
  let empty := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 }
    { mixed with scheduled := .ok { evidence with scheduled := emptyMemory } } all)
  expect (contains "Scheduled [Unavailable]" unavailable && !contains "Scheduled (0)" unavailable &&
      contains "Scheduled [Unknown]" unknown && !contains "none due" unknown &&
      contains "Scheduled (0)" empty && contains "no current-open Scheduled occurrences" empty &&
      !contains "Unavailable" empty && !contains "Unknown" empty)
    "List merged unavailable, unknown, and known-empty evidence"
  let longLabel := "日本語の長いLocus名が左側の枠を超えるときには省略を明示する"
  let longRecord ← requireSome (scheduledRecord? "long-label" "2026-09-07" "wallet" longLabel 100)
    "long-label List fixture was not admitted"
  let longMemory ← requireSome (ScheduledMemory.ofOccurrences? [longRecord])
    "long-label List memory was not admitted"
  let longSnapshot := { mixed with scheduled := .ok { evidence with scheduled := longMemory } }
  let longState := { all with pane := .loci, locusRow := 2 }
  let longText := widgetText (Loam.Tui.ScheduledWorkspace.view
    { width := 80, height := 24 } longSnapshot longState)
  expect (contains "…" longText && contains "long-label" longText)
    "List silently clipped a Japanese label or changed the selected record"

def main : IO Unit := do
  checkMonthsLayout
  checkListLayout
  let snapshot ← scheduledWorkspaceSnapshot

  -- Shared current-open read order is date first, then Scheduled identity.
  -- Retained order is intentionally reversed for the same-date pair.
  let sameDateZ ← requireSome
    (scheduledRecord? "z-same-day" "2026-09-10" "wallet" "food" 10)
    "same-date z fixture was not admitted"
  let sameDateA ← requireSome
    (scheduledRecord? "a-same-day" "2026-09-10" "wallet" "books" 20)
    "same-date a fixture was not admitted"
  let orderedMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [sameDateZ, sameDateA])
    "same-date ordered Scheduled memory was not admitted"
  let orderedTerminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "same-date empty terminal memory was not admitted"
  let orderedEvents ← requireSome (EventMemory.ofEvents? [])
    "same-date empty Event memory was not admitted"
  let orderedEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := orderedMemory
    terminals := orderedTerminals
    events := orderedEvents
  }
  let ordered ←
    match Loam.ScheduledReview.orderedCurrentOpenRecords orderedEvidence with
    | .error message => throw (IO.userError message)
    | .ok rows => pure rows
  expect (ordered.map (fun row => row.id.token) == ["a-same-day", "z-same-day"])
    "shared Scheduled read order did not use identity as the same-date tie-breaker"
  let earliest ←
    match Loam.ScheduledReview.earliestCurrentOpenRecord orderedEvidence with
    | .error message => throw (IO.userError message)
    | .ok row => pure row
  expect ((earliest.map (fun row => row.id.token)) == some "a-same-day")
    "earliest current-open Scheduled diverged from the shared ordered frontier"

  let overview := Loam.Tui.ScheduledWorkspace.initial "2026-09-07"
  expect (overview.viewMode == .coverage && overview.scope == .allCurrent)
    "Scheduled production initializer did not open on the all-current Coverage overview"

  let start := Loam.Tui.ScheduledWorkspace.initialList "2026-09-07"

  -- 1. Focus Day scope shows only today's Scheduled occurrences
  expect ((Loam.Tui.ScheduledWorkspace.recordsForScope snapshot start).length == 2)
    "Scheduled workspace Focus Day did not return the two scheduled occurrences on 2026-09-07"

  -- Unknown day evidence stays distinct from an empty complete answer.
  let unknownState := Loam.Tui.ScheduledWorkspace.initialList "2026-09-09"
  match Loam.Tui.ScheduledWorkspace.scopeEvidence snapshot unknownState with
  | .ok .unknown => pure ()
  | _ => throw (IO.userError "Scheduled workspace Focus Day did not preserve Unknown evidence")
  let unknownText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot unknownState)
  expect (contains "Scheduled [Unknown]" unknownText &&
    contains "Unknown; no completeness horizon claimed" unknownText)
    "Scheduled workspace did not render open-world Unknown explicitly"
  expect (!contains "none due on this day" unknownText)
    "Scheduled workspace collapsed Unknown into an empty-day claim"

  -- Production Scheduled workspace owns its own eight-row viewport. Pin navigation beyond it
  -- before the older Main Scheduled cursor implementation is retired.
  let longSnapshot ← longScheduledWorkspaceSnapshot 12
  let longStart := Loam.Tui.ScheduledWorkspace.initialList "2026-09-07"
  let longShifted := (List.range 10).foldl
    (fun current _ => (Loam.Tui.ScheduledWorkspace.update longSnapshot current .next).state)
    longStart
  expect (longShifted.occurrenceRow == 10)
    "Scheduled workspace selection could not reach the eleventh occurrence"
  let selectedLong ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedRecord? longSnapshot longShifted)
    "Scheduled workspace eleventh-row selection disappeared"
  let longViewText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } longSnapshot longShifted)
  expect (contains selectedLong.id.token longViewText)
    "Scheduled workspace moving viewport did not render its selected eleventh occurrence"
  match (Loam.Tui.ScheduledWorkspace.recordsForScope longSnapshot longStart).head? with
  | none => throw (IO.userError "Scheduled workspace long-list fixture became empty")
  | some firstLong =>
      expect (!contains firstLong.id.token longViewText)
        "Scheduled workspace eight-row viewport did not move beyond its first occurrence"
  let longLast := (List.range 11).foldl
    (fun current _ => (Loam.Tui.ScheduledWorkspace.update longSnapshot current .next).state)
    longStart
  let longBlocked := (Loam.Tui.ScheduledWorkspace.update longSnapshot longLast .next).state
  expect (longBlocked.occurrenceRow == longLast.occurrenceRow &&
    contains "No next Scheduled row" longBlocked.notice)
    "Scheduled workspace end-of-list refusal moved selection or lost its notice"

  -- Months uses spare terminal height instead of keeping every month at three rows.
  let longAll := (Loam.Tui.ScheduledWorkspace.update longSnapshot longStart .cycleFilter).state
  let longCoverage := (Loam.Tui.ScheduledWorkspace.update longSnapshot longAll .toggleView).state
  let longBoard := (Loam.Tui.ScheduledWorkspace.update longSnapshot longCoverage .toggleView).state
  let compactBoardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } longSnapshot longBoard)
  let tallBoardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 50 } longSnapshot longBoard)
  expect (!(contains "7 jpy" compactBoardText) &&
    contains "7 jpy" tallBoardText)
    "Scheduled Months did not expand month-card capacity with terminal height"

  -- 2. Scheduled opens on occurrences so j/k browses records before any explicit Locus filtering.
  expect (start.pane == .occurrences)
    "Scheduled workspace did not open on the Scheduled occurrences pane"
  let second := (Loam.Tui.ScheduledWorkspace.update snapshot start .next).state
  match Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot second with
  | none => throw (IO.userError "Scheduled workspace occurrence selection disappeared")
  | some record =>
      expect (record.id.token == "scheduled-1")
        "Scheduled workspace j/down selection did not move to the second occurrence"

  -- 3. Rendering check
  let viewWidget := Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot second
  let viewText := widgetText viewWidget
  expect (contains "Scheduled / List" viewText)
    "Scheduled workspace heading was not rendered"
  expect (contains "Selected Scheduled" viewText && contains "scheduled-1" viewText)
    "Scheduled workspace details did not render selected occurrence information"
  let refusalMessage :=
    "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let refusedState := { second with notice := refusalMessage }
  let refusedText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot refusedState)
  expect (contains refusalMessage (refusedText.replace "\n" " "))
    "Scheduled workspace did not render the complete wrapped Scheduled replacement refusal notice"

  -- 4. Cycle Filter expands to allCurrent
  let allCurrent := (Loam.Tui.ScheduledWorkspace.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.ScheduledWorkspace.recordsForScope snapshot allCurrent).length == 3)
    "Scheduled workspace filter cycle did not expand to all current-open Scheduled occurrences"
  expect (allCurrent.pane == .occurrences)
    "Scheduled workspace scope change moved focus into the Locus filter pane"

  let allCurrentText := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot allCurrent)
  expect (contains "All Current-Open" allCurrentText)
    "Scheduled workspace heading did not reflect All Current-Open scope"

  -- Coverage is the Scheduled overview; Months and List are alternate projections.
  let coverage := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .toggleView).state
  expect (coverage.viewMode == .coverage && coverage.scope == .allCurrent)
    "Scheduled list did not cycle into the Coverage overview"
  let foodRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "food"
    anchor := "2026-09-07"
    everyMonths := 1
    negativeLoci := ["paypay"]
    positiveLoci := ["food"]
  }
  let paypayRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "paypay-transfer"
    anchor := "2026-09-07"
    everyMonths := 1
    negativeLoci := ["smbc"]
    positiveLoci := ["paypay"]
  }
  let coverageSnapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [foodRule, paypayRule] (Loam.Tui.ScheduledWorkspace.recordsForScope snapshot coverage)
        "2026-09-07" 4 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let coverageText := widgetText
    (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 120, height := 30 } snapshot coverage (.ok coverageSnapshot))
  expect (contains "Scheduled" coverageText &&
    contains "food" coverageText && contains "paypay-transfer" coverageText &&
    contains "Pace" coverageText && contains "Oct" coverageText)
    "Scheduled overview did not render the recurring-plan Series Calendar"
  expect (contains "> food" coverageText &&
    contains "[j/k] plan" coverageText &&
    contains "[e] replenish" coverageText && contains "[p] pace" coverageText &&
    contains "[h/l] months" coverageText && contains "[Enter] detail" coverageText)
    "Scheduled overview did not expose its ordinary recurring-plan actions"
  expect (!contains "More:" coverageText &&
    contains "[s] undecided" coverageText &&
    contains "[n] new" coverageText &&
    contains "[v] views" coverageText)
    "Scheduled overview hid advanced actions in its operation-only footer"

  expect (contains "╭ Monitored plans" coverageText && !contains "====" coverageText &&
      contains "known through 2026-09-07" coverageText && contains "Month window:" coverageText)
    "Series Calendar retained heavy rules or lost its observation/month coordinates"

  let manyRules := (List.range 40).map fun index =>
    { foodRule with
      name := "プラン-" ++ toString index
      positiveLoci := ["target-" ++ toString index] }
  let manyCoverage ←
    match Loam.ScheduledCoverageReview.projectRecords manyRules [] "2026-09-07" 18 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let manyState := { coverage with coverageRow := 35 }
  let selectedPlan ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageRow? (.ok manyCoverage) manyState)
    "long Series Calendar selection disappeared"
  let firstPlan ← requireSome (Loam.Tui.ScheduledCoveragePane.orderedRows manyCoverage).head?
    "long Series Calendar first row disappeared"
  for bounds in [{ width := 80, height := 24 }, { width := 120, height := 30 },
      { width := 144, height := 40 }, { width := 48, height := 10 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot manyState (.ok manyCoverage)
    let text := widgetText rendered
    expect (contains selectedPlan.rule.name text && !contains firstPlan.rule.name text &&
        contains "36/40" text &&
        rendered.lines.any (fun cells => cells.any (fun cell => cell.style == .selected)))
      "Series Calendar left its selected plan off-screen or lost selection position"
    expect (rendered.lines.length <= bounds.height - 1 &&
        rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds))
      "Series Calendar exceeded its physical terminal geometry"
    expect (rendered.lines.all fun cells => cells.all fun cell =>
        cell.style == .normal || cell.style == .muted ||
        cell.style == .series1 || cell.style == .selected)
      "Series Calendar added decorative accent colors"
  for width in [0, 1, 2, 10, 20, 32, 48, 80, 120] do
    for height in [0, 1, 2, 6, 10, 18, 24, 30] do
      let bounds : Bounds := { width, height }
      let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot manyState (.ok manyCoverage)
      expect (rendered.lines.length <= height - 1 && rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds))
        "Compact or degenerate Series Calendar geometry escaped its bounds"
  let shiftedCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot { coverage with coverageMonthOffset := 2 }
    (.ok coverageSnapshot))
  expect (contains "2026-12 .. 2027-01" shiftedCalendar && contains "Dec" shiftedCalendar)
    "Framed Series Calendar changed the selected finite month window"
  let emptyCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot coverage (.ok { coverageSnapshot with rows := [] }))
  let failedCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot coverage (.error "coverage read refused"))
  expect (contains "No recurring plans are being monitored." emptyCalendar &&
      !contains "Coverage unavailable" emptyCalendar &&
      contains "[Coverage unavailable] coverage read refused" failedCalendar &&
      !contains "0/0" failedCalendar && !contains "No recurring plans" failedCalendar)
    "Series Calendar collapsed failed coverage into configured-empty evidence"
  let calendarRefusal := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 100, height := 30 } snapshot { coverage with notice := refusalMessage }
    (.ok coverageSnapshot))
  expect (contains refusalMessage (calendarRefusal.replace "\n" " "))
    "Framed Series Calendar clipped a publisher's complete refusal feedback"

  checkNavigationFooter snapshot coverageSnapshot coverage

  let coverageEvidence : Loam.Tui.ScheduledWorkspace.CoverageEvidence := .ok coverageSnapshot
  let coverageExtend :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .extendPlan
  expect (coverageExtend.command == .extendPlan)
    "Scheduled overview could not replenish its selected recurring plan directly"
  let coverageBatch :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .batchEditScheduled
  expect (coverageBatch.command == .batchEditScheduled && contains "[b] batch" coverageText)
    "Scheduled overview could not open the batch candidate sheet directly"
  let coveragePace :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .changePace
  expect (coveragePace.command == .changePace)
    "Scheduled overview could not change its selected recurring-plan pace directly"
  let coverageStop :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .stopMonitoring
  expect (coverageStop.command == .stopMonitoring)
    "Scheduled overview could not mark its selected recurring plan undecided directly"

  let coverageNext :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .next).state
  expect (coverageNext.coverageRow == 1)
    "Scheduled overview j/k selection did not move between recurring plans"
  let coverageLaterMonth :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverage .focusRight).state
  expect (coverageLaterMonth.coverageMonthOffset == 1)
    "Scheduled Series Calendar l did not move the month window"
  let coverageEarlierMonth :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverageLaterMonth .focusLeft).state
  expect (coverageEarlierMonth.coverageMonthOffset == 0)
    "Scheduled Series Calendar h did not move the month window back"
  let selectedCoverage ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageRow? coverageEvidence coverageNext)
    "Scheduled overview selected recurring plan disappeared"
  expect (selectedCoverage.rule.name == "paypay-transfer")
    "Scheduled overview row selection diverged from displayed order"

  -- Coverage replenishment starts before the first monitored gap, not at a later
  -- off-cadence explicit occurrence. This mirrors the household support case
  -- where extra Nov/Jan/Mar/May dates must not shift a bimonthly Oct/Dec/Feb/Apr pace.
  let supportOct ← requireSome
    (scheduledRecord? "support-oct" "2026-10-15" "support" "smbc" 11240)
    "support October fixture was not admitted"
  let supportNov ← requireSome
    (scheduledRecord? "support-nov" "2026-11-15" "support" "smbc" 11240)
    "support November fixture was not admitted"
  let supportFeb ← requireSome
    (scheduledRecord? "support-feb" "2027-02-15" "support" "smbc" 11240)
    "support February fixture was not admitted"
  let supportMar ← requireSome
    (scheduledRecord? "support-mar" "2027-03-15" "support" "smbc" 11240)
    "support March fixture was not admitted"
  let supportMay ← requireSome
    (scheduledRecord? "support-may" "2027-05-15" "support" "smbc" 11240)
    "support May fixture was not admitted"
  let supportRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "support"
    anchor := "2026-10-15"
    everyMonths := 2
    negativeLoci := ["support"]
    positiveLoci := ["smbc"]
  }
  let supportRecords := [supportOct, supportNov, supportFeb, supportMar, supportMay]
  let supportScheduled ← requireSome (ScheduledMemory.ofOccurrences? supportRecords)
    "support Scheduled memory fixture was not admitted"
  let supportTerminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "support terminal memory fixture was not admitted"
  let supportEvents ← requireSome (EventMemory.ofEvents? [])
    "support Event memory fixture was not admitted"
  let supportEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := supportScheduled
    terminals := supportTerminals
    events := supportEvents
  }
  let supportSnapshot : Loam.Tui.Main.Snapshot := {
    actual := { today := "2026-09-30", allRecords := [] }
    scheduled := .ok supportEvidence
  }
  let supportCoverageSnapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [supportRule] supportRecords "2026-09-30" 8 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some supportRow := supportCoverageSnapshot.rows[0]?
    | throw (IO.userError "support coverage row disappeared")
  expect (supportRow.firstMissing == some "2026-12")
    "support coverage fixture did not expose December as its first gap"
  let supportState := Loam.Tui.ScheduledWorkspace.initial "2026-09-30"
  let supportSource ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageReplenishmentRecord?
      supportSnapshot (.ok supportCoverageSnapshot) supportState)
    "support replenishment source disappeared"
  expect (supportSource.id.token == "support-oct")
    "Scheduled replenishment extended from a later off-cadence occurrence instead of the first gap"

  let supportDec ← requireSome
    (scheduledRecord? "support-dec" "2026-12-15" "support" "smbc" 11240)
    "support December fixture was not admitted"
  let supportFilledRecords := supportRecords ++ [supportDec]
  let supportFilledScheduled ← requireSome
    (ScheduledMemory.ofOccurrences? supportFilledRecords)
    "filled support Scheduled memory fixture was not admitted"
  let supportFilledEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := supportFilledScheduled
    terminals := supportTerminals
    events := supportEvents
  }
  let supportFilledSnapshot : Loam.Tui.Main.Snapshot := {
    actual := { today := "2026-09-30", allRecords := [] }
    scheduled := .ok supportFilledEvidence
  }
  let supportFilledCoverage ←
    match Loam.ScheduledCoverageReview.projectRecords
        [supportRule] supportFilledRecords "2026-09-30" 8 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some supportFilledRow := supportFilledCoverage.rows[0]?
    | throw (IO.userError "filled support coverage row disappeared")
  expect (supportFilledRow.firstMissing == some "2027-04")
    "support replenishment did not advance from the filled December gap to April"
  let supportNextSource ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageReplenishmentRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportState)
    "second support replenishment source disappeared"
  expect (supportNextSource.id.token == "support-feb")
    "Scheduled replenishment did not resume from the latest on-cadence occurrence before the next gap"

  let openPlan :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverageNext .openSelectedPlan).state
  expect (openPlan.viewMode == .planDetail)
    "Scheduled overview Enter action did not open focused Plan Detail"
  let planBack :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence openPlan .back
  expect (planBack.command == .stay && planBack.state.viewMode == .coverage)
    "Scheduled Plan Detail q/back did not return to the Series Calendar"

  let supportPlan :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportState .openSelectedPlan).state
  expect (supportPlan.viewMode == .planDetail)
    "support Series Calendar row did not open Plan Detail"
  let supportPlanText := widgetText
    (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 120, height := 30 }
      supportFilledSnapshot supportPlan (.ok supportFilledCoverage))
  expect (contains "Scheduled / Plan / support" supportPlanText &&
    contains "2026-11-15" supportPlanText && contains "[outside pace]" supportPlanText &&
    contains "2026-12-15" supportPlanText && contains "[on pace]" supportPlanText &&
    contains "2027-04" supportPlanText && contains "MISSING monitored month" supportPlanText)
    "Scheduled Plan Detail did not combine explicit, outside-pace, and missing rows"
  expect (contains "╭ Occurrences / monitored gaps" supportPlanText &&
      contains "Date/Month" supportPlanText && contains "Quanta" supportPlanText &&
      contains "11,240 jpy" supportPlanText && !contains "====" supportPlanText)
    "Plan Detail lost its quiet frame, aligned columns, or exact grouped quanta"

  let manyPlanSnapshot ← longScheduledWorkspaceSnapshot 40
  let manyPlanRecords ← match manyPlanSnapshot.scheduled with
    | .error message => throw (IO.userError message)
    | .ok evidence => match Loam.ScheduledReview.orderedCurrentOpenRecords evidence with
      | .error message => throw (IO.userError message)
      | .ok records => pure records
  let manyPlanRule := { foodRule with
    name := "日本語の長いプラン名を切り詰める際にも選択した予定を保つ"
    negativeLoci := ["wallet"]
    everyMonths := 0 }
  let manyPlanCoverage ← match Loam.ScheduledCoverageReview.projectRecords
      [manyPlanRule] manyPlanRecords "2026-09-07" 18 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let manyPlanState := { coverage with viewMode := .planDetail, planRow := 35 }
  let selectedManyPlan ← requireSome (Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord?
    manyPlanSnapshot (.ok manyPlanCoverage) manyPlanState) "long Plan Detail selection disappeared"
  let selectedQuantity := Loam.MeasurePresentation.groupDisplayedNumber
    (toString (selectedManyPlan.quantityAt ⟨"food"⟩).quanta) ++ " jpy"
  for bounds in [{ width := 80, height := 24 }, { width := 120, height := 30 },
      { width := 144, height := 40 }, { width := 48, height := 10 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds manyPlanSnapshot
      manyPlanState (.ok manyPlanCoverage)
    let selectedLines := rendered.lines.filter fun cells =>
      cells.any (fun cell => cell.style == .selected)
    expect (selectedLines.length == 1 && contains selectedQuantity
        (String.ofList ((selectedLines.flatten.filter (fun cell => cell.style == .selected)).map Cell.glyph)) &&
        contains "36/40" (widgetText rendered))
      "Plan Detail scrolled its selected occurrence off-screen or changed its quantity"
    expect (rendered.lines.all fun cells => cells.all fun cell =>
        cell.style == .normal || cell.style == .muted ||
        cell.style == .series1 || cell.style == .selected)
      "Plan Detail added decorative accent colors"
  for width in [0, 1, 2, 10, 20, 32, 48, 80, 120] do
    for height in [0, 1, 2, 6, 10, 18, 24, 30] do
      let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage { width, height }
        manyPlanSnapshot manyPlanState (.ok manyPlanCoverage)
      expect (rendered.lines.length <= height - 1 && rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth { width, height }))
        "Plan Detail exceeded its physical terminal geometry"
  let narrowPlan := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 48, height := 10 } manyPlanSnapshot manyPlanState (.ok manyPlanCoverage))
  expect (contains "…" narrowPlan)
    "Plan Detail silently clipped a long Japanese plan label"
  let bounds : Bounds := { width := 80, height := 24 }
  let plainPlan := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds supportFilledSnapshot
    supportPlan (.ok supportFilledCoverage)
  let boundaryPlan := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds supportFilledSnapshot
    { supportPlan with notice := "At first row." } (.ok supportFilledCoverage)
  expect (plainPlan.lines.zipIdx.filterMap (fun (cells, index) =>
        if cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰') then some index else none) ==
      boundaryPlan.lines.zipIdx.filterMap (fun (cells, index) =>
        if cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰') then some index else none))
    "A short navigation notice shifted the Plan Detail frame"
  let unknownPlan := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } { supportFilledSnapshot with scheduled := .error "read refused" }
    supportPlan (.ok supportFilledCoverage))
  let failedCoveragePlan := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } supportFilledSnapshot supportPlan (.error "coverage refused"))
  expect (contains "[Unavailable] Scheduled: read refused" unknownPlan &&
      contains "[Coverage unavailable] coverage refused" failedCoveragePlan &&
      !contains "0/0" unknownPlan && !contains "0/0" failedCoveragePlan &&
      !contains "No current-open occurrences" unknownPlan)
    "Plan Detail collapsed failed evidence into an empty plan or monitored gaps"
  let planRefusal := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 100, height := 30 } supportFilledSnapshot
    { supportPlan with notice := refusalMessage } (.ok supportFilledCoverage))
  expect (contains refusalMessage (planRefusal.replace "\n" " "))
    "Plan Detail clipped the publisher's complete refusal feedback"
  let splitMovement ← requireSome (BalancedMovement.ofChanges? yen
    [change "wallet" (-100), change "books" 25, change "food" 75])
    "split Plan Detail fixture was not admitted"
  let splitPlan : ScheduledOccurrence String := {
    id := ⟨"split-plan"⟩, scheduledOn := "2026-09-07", movement := splitMovement }
  let hugePlan ← requireSome (scheduledRecord? "huge-plan" "2026-09-07" "wallet" "food"
    1234567890123456789012345678901234567890) "huge Plan Detail fixture was not admitted"
  for (record, loci, expected) in [(splitPlan, ["books", "food"], "split (3)"),
      (hugePlan, ["food"], "too wide")] do
    let memory ← requireSome (ScheduledMemory.ofOccurrences? [record])
      "special-quantity Plan Detail memory was not admitted"
    let rule := { manyPlanRule with positiveLoci := loci }
    let specialCoverage ← match Loam.ScheduledCoverageReview.projectRecords
        [rule] [record] "2026-09-07" 18 with
      | .error message => throw (IO.userError message)
      | .ok result => pure result
    let specialSnapshot := { supportFilledSnapshot with
      scheduled := .ok { supportFilledEvidence with scheduled := memory } }
    let text := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 80, height := 24 } specialSnapshot { manyPlanState with planRow := 0 }
      (.ok specialCoverage))
    expect (contains expected text && !contains "100 jpy" text && !contains "1,234,567,890" text)
      "Plan Detail invented a split total or truncated an oversized quantity into a plausible amount"

  let supportOutside :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportPlan .next).state
  let outsideRecord ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportOutside)
    "Scheduled Plan Detail lost its selected outside-pace occurrence"
  expect (outsideRecord.id.token == "support-nov")
    "Scheduled Plan Detail j/k did not move directly to the next occurrence"
  let cancelOutside :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportOutside .cancelScheduled
  expect (cancelOutside.command == .cancelScheduled)
    "Scheduled Plan Detail could not cancel an explicit outside-pace occurrence directly"

  let supportMissing :=
    (List.range 5).foldl
      (fun current _ =>
        (Loam.Tui.ScheduledWorkspace.updateWithCoverage
          supportFilledSnapshot (.ok supportFilledCoverage) current .next).state)
      supportPlan
  expect
    ((Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportMissing).isNone)
    "Scheduled Plan Detail missing marker unexpectedly became an explicit occurrence"
  let cancelMissing :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportMissing .cancelScheduled
  expect (cancelMissing.command == .stay && contains "missing monitored month" cancelMissing.state.notice)
    "Scheduled Plan Detail did not protect a presentation-only missing row from cancellation"

  let coverageFill :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .fillCurrentCycle
  expect (coverageFill.command == .stay && contains "Use e" coverageFill.state.notice)
    "Scheduled overview compatibility fill action did not redirect to replenishment"

  let board :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverage .toggleView).state
  expect (board.viewMode == .futureBoard && board.scope == .allCurrent &&
    board.pane == .occurrences && board.locusRow == 0)
    "Scheduled Months view did not normalize into the all-current occurrence view"
  let boardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } snapshot board)
  expect (contains "Scheduled / Months" boardText &&
    contains "╭ 2026-09" boardText && contains "╭ 2026-10" boardText)
    "Scheduled Months view did not render its six-month calendar blocks"
  expect (contains "Selected Scheduled" boardText && contains "Expected Effects (exact quanta)" boardText)
    "Scheduled Months view lost the shared selected-record details"
  let boardLeft := (Loam.Tui.ScheduledWorkspace.update snapshot board .focusLeft).state
  expect (boardLeft.pane == .occurrences && boardLeft.futureBoardMonthOffset == 0 &&
    contains "current calendar month" boardLeft.notice)
    "Scheduled Months left navigation did not stop cleanly at the current month"
  let boardRight :=
    (Loam.Tui.ScheduledWorkspace.update snapshot board .focusRight).state
  expect (boardRight.futureBoardMonthOffset == 1 && boardRight.pane == .occurrences)
    "Scheduled Months right navigation did not shift the six-month window"
  let boardRightText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } snapshot boardRight)
  expect (contains "2026-10 .. 2027-03" boardRightText &&
    contains "╭ 2026-10" boardRightText && contains "╭ 2027-03" boardRightText &&
    contains "horizontal wheel" boardRightText)
    "Scheduled Months shifted window did not render the expected later calendar range"
  let boardBack :=
    (Loam.Tui.ScheduledWorkspace.update snapshot boardRight .focusLeft).state
  expect (boardBack.futureBoardMonthOffset == 0)
    "Scheduled Months left navigation did not return to the previous calendar window"
  let boardFilter := (Loam.Tui.ScheduledWorkspace.update snapshot board .cycleFilter).state
  expect (boardFilter.scope == .allCurrent &&
    contains "Months always uses the current-open frontier" boardFilter.notice)
    "Scheduled Months view unexpectedly changed its all-current scope"
  let boardExtend := Loam.Tui.ScheduledWorkspace.update snapshot board .extendPlan
  expect (boardExtend.command == .extendPlan)
    "Scheduled Months view did not expose the simple extend action for its selected record"
  let boardStop := Loam.Tui.ScheduledWorkspace.update snapshot board .stopMonitoring
  expect (boardStop.command == .stopMonitoring)
    "Scheduled Months view did not expose the simple undecided action for its selected record"
  let boardFill := Loam.Tui.ScheduledWorkspace.update snapshot board .fillCurrentCycle
  expect (boardFill.command == .fillCurrentCycle)
    "Scheduled Months lost the compatibility fill action"
  let listAgain := (Loam.Tui.ScheduledWorkspace.update snapshot board .toggleView).state
  expect (listAgain.viewMode == .list)
    "Scheduled Months toggle did not continue to List"

  -- 5. Loci navigation and filtering
  let toLoci := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .focusLeft).state
  expect (toLoci.pane == .loci)
    "Scheduled workspace focusLeft did not switch to loci pane"

  -- 6. Object-local command emission from occurrences pane
  let occPane := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .focusRight).state

  let completeStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .completeScheduled
  expect (completeStep.command == .completeScheduled)
    "Scheduled workspace completeScheduled event did not emit completeScheduled command"

  let batchStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .batchEditScheduled
  expect (batchStep.command == .batchEditScheduled)
    "Scheduled occurrence could not open batch candidate editing"
  let shortNoticeState := { occPane with
    viewMode := Loam.Tui.ScheduledWorkspace.ViewMode.futureBoard
    notice := "Revised 2 Scheduled occurrences." }
  let shortNoticeText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 80, height := 18 } snapshot shortNoticeState)
  expect (contains shortNoticeState.notice shortNoticeText &&
    contains "[b] batch" shortNoticeText && contains "[x] cancel" shortNoticeText &&
    contains "[q] back" shortNoticeText)
    "short Months viewport hid batch publication feedback or displaced an existing action"
  for mode in [Loam.Tui.ScheduledWorkspace.ViewMode.list, .coverage, .planDetail] do
    let noticeState := { shortNoticeState with viewMode := mode }
    let text := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 80, height := 18 } snapshot noticeState coverageEvidence)
    expect (contains noticeState.notice text)
      "Scheduled projection hid canonical publication feedback in a short viewport"
  let replaceStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .replaceScheduled
  expect (replaceStep.command == .replaceScheduled)
    "Scheduled workspace replaceScheduled event did not emit replaceScheduled command"

  let cancelStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .cancelScheduled
  expect (cancelStep.command == .cancelScheduled)
    "Scheduled workspace cancelScheduled event did not emit cancelScheduled command"

  let createStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .createScheduled
  expect (createStep.command == .createScheduled)
    "Scheduled workspace createScheduled event did not emit createScheduled command"

  let extendStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .extendPlan
  expect (extendStep.command == .extendPlan)
    "Scheduled workspace extendPlan event did not emit extendPlan command"

  let paceStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .changePace
  expect (paceStep.command == .changePace)
    "Scheduled workspace changePace event did not emit changePace command"

  let stopMonitoringStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .stopMonitoring
  expect (stopMonitoringStep.command == .stopMonitoring)
    "Scheduled workspace stopMonitoring event did not emit stopMonitoring command"

  let fillStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .fillCurrentCycle
  expect (fillStep.command == .fillCurrentCycle)
    "Scheduled workspace fillCurrentCycle event did not emit fillCurrentCycle command"

  let monitorStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .monitorCoverage
  expect (monitorStep.command == .monitorCoverage)
    "Scheduled workspace monitorCoverage event did not emit monitorCoverage command"

  let selectedForMonitor ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot occPane)
    "Scheduled workspace monitoring source disappeared"
  let monitorRule ←
    match Loam.Tui.ScheduledCoverageSetup.ruleFor? selectedForMonitor 1 with
    | .error message => throw (IO.userError message)
    | .ok rule => pure rule
  expect (monitorRule.anchor == selectedForMonitor.scheduledOn &&
    monitorRule.everyMonths == 1 &&
    monitorRule.name == "food")
    "Scheduled monitoring setup did not derive anchor/cadence/display identity from the selected occurrence"
  expect (Loam.ScheduledCoverageSelector.matchesRule selectedForMonitor monitorRule)
    "Scheduled monitoring setup produced a rule that the shared coverage selector would not match"

  let backStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .back
  expect (backStep.command == .back)
    "Scheduled workspace back event did not emit back command"

  -- 7. From loci pane, complete/replace/cancel are refused and emit .stay with notice
  let lociCompleteStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .completeScheduled
  expect (lociCompleteStep.command == .stay)
    "Scheduled workspace completeScheduled from loci pane unexpectedly emitted a non-stay command"
  expect (contains "Scheduled pane" lociCompleteStep.state.notice)
    "Scheduled workspace complete notice from loci pane was missing guidance"
  let lociFillStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .fillCurrentCycle
  expect (lociFillStep.command == .stay && contains "Scheduled pane" lociFillStep.state.notice)
    "Scheduled workspace cycle fill from loci pane was not refused with guidance"
  let lociMonitorStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .monitorCoverage
  expect (lociMonitorStep.command == .stay && contains "Scheduled pane" lociMonitorStep.state.notice)
    "Scheduled workspace monitoring from loci pane was not refused with guidance"

  -- 8. Startup refusal remains explicit and blocks Scheduled writes.
  let unavailable : Loam.Tui.Main.Snapshot :=
    { snapshot with scheduled := .error "scheduled fixture unavailable" }
  let unavailableText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } unavailable start)
  expect (contains "Scheduled [Unavailable]" unavailableText &&
    contains "[Unavailable] scheduled fixture unavailable" unavailableText)
    "Scheduled workspace collapsed startup refusal into an empty Scheduled workspace"
  let unavailableBatch := Loam.Tui.ScheduledWorkspace.update unavailable start .batchEditScheduled
  expect (unavailableBatch.command == .stay)
    "unavailable Scheduled authority admitted batch editing"
  let unavailableCreate := Loam.Tui.ScheduledWorkspace.update unavailable start .createScheduled
  expect (unavailableCreate.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableCreate.state.notice)
    "Scheduled workspace emitted a write intent while Scheduled evidence was unavailable"
  let unavailableExtend := Loam.Tui.ScheduledWorkspace.update unavailable start .extendPlan
  expect (unavailableExtend.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableExtend.state.notice)
    "Scheduled workspace emitted extend intent while Scheduled evidence was unavailable"
  let unavailablePace := Loam.Tui.ScheduledWorkspace.update unavailable start .changePace
  expect (unavailablePace.command == .stay &&
    contains "[Unavailable] Scheduled" unavailablePace.state.notice)
    "Scheduled workspace emitted pace-change intent while Scheduled evidence was unavailable"
  let unavailableStop := Loam.Tui.ScheduledWorkspace.update unavailable start .stopMonitoring
  expect (unavailableStop.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableStop.state.notice)
    "Scheduled workspace emitted monitoring-removal intent while Scheduled evidence was unavailable"
  let unavailableFill := Loam.Tui.ScheduledWorkspace.update unavailable start .fillCurrentCycle
  expect (unavailableFill.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableFill.state.notice)
    "Scheduled workspace emitted cycle-fill intent while Scheduled evidence was unavailable"
  let unavailableMonitor := Loam.Tui.ScheduledWorkspace.update unavailable start .monitorCoverage
  expect (unavailableMonitor.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableMonitor.state.notice)
    "Scheduled workspace emitted monitoring intent while Scheduled evidence was unavailable"

  IO.println "TUI Scheduled: Scheduled workspace mechanics and startup unavailability passed."
