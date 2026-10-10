import Loam.Tui.SelectedDay

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

private def compact (text : String) : String :=
  String.ofList (text.toList.filter fun char => char != ' ' && char != '\n' && char != '│')

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def food : LocusId := ⟨"food"⟩

private def actualRecord? : Option Loam.Tui.Main.ReviewRecord := do
  let event ← Event.ofEffects? ⟨"event-day"⟩
    [ Effect.ofQuantity ⟨"effect-from"⟩ paypay yen (Quantity.ofQuanta (-640))
    , Effect.ofQuantity ⟨"effect-to"⟩ food yen (Quantity.ofQuanta 640)
    ]
  pure {
    event
    date := some "2026-09-07"
    description := "コンビニ"
    replacement := none
  }

private def scheduledRecord? : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [ { coordinate := paypay, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := food, quantity := Quantity.ofQuanta 1000 }
    ]
  pure {
    id := ⟨"scheduled-day"⟩
    scheduledOn := "2026-09-07"
    movement := movement
  }

private def fixture : IO Loam.Tui.Main.Snapshot := do
  let actualRecord ← requireSome actualRecord? "Actual day fixture was not admitted"
  let scheduledRecord ← requireSome scheduledRecord? "Scheduled day fixture was not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [scheduledRecord])
    "Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := [actualRecord]
  }
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events
  }
  pure { actual, scheduled := .ok scheduledSnapshot }

private def rowIndex (needle : String) (view : Widget) : IO Nat :=
  requireSome (view.lines.findIdx? fun cells => contains needle (String.ofList (cells.map Cell.glyph)))
    ("missing rendered row: " ++ needle)

private def detailContent (view : Widget) : List String :=
  let lines := view.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  ((lines.dropWhile fun line => !contains "╭ Selected" line).drop 1).takeWhile fun line =>
    !contains "╰" line

private def press (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot)
    (state : Loam.Tui.SelectedDay.State) (event : Loam.Tui.SelectedDay.Event)
    (repeatCount : Nat := 1) : Loam.Tui.SelectedDay.State :=
  (Loam.Tui.SelectedDay.updateForBounds bounds snapshot state event repeatCount).state

private def testFrames (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let base := Loam.Tui.SelectedDay.initial "2026-09-07"
  let boundsList : List Bounds := [
    {width := 48, height := 14}, {width := 80, height := 24},
    {width := 99, height := 20}, {width := 100, height := 30}, {width := 150, height := 45}]
  for bounds in boundsList do
    for pane in [Loam.Tui.SelectedDay.Pane.actual, .scheduled] do
      for detailFocused in [false, true] do
        let state := {base with pane, detailFocused}
        let view := Loam.Tui.SelectedDay.view bounds snapshot state
        let notified := Loam.Tui.SelectedDay.view bounds snapshot {state with notice := "Record cancelled."}
        expect (view.lines.length == bounds.height - 1 && notified.lines.length == view.lines.length)
          "Selected Day exceeded its usable height"
        expect (contains "╭" (widgetText view) && contains "╰" (widgetText view) &&
          !contains "====" (widgetText view)) "Selected Day retained heavy rules or lost rounded frames"
        expect (contains "Record cancelled." (widgetText notified)) "child return feedback was hidden"
        let borders : Widget → List Nat := fun widget => widget.lines.zipIdx.filterMap fun (cells, index) =>
          let line := String.ofList (cells.map Cell.glyph)
          if contains "╭" line || contains "╰" line then some index else none
        expect (borders view == borders notified) "one-line feedback moved Selected Day frames"
        expect ((← rowIndex (if detailFocused then "[Esc/i/q]" else "[q]") notified) == bounds.height - 3)
          "Selected Day navigation was not fixed above the final action row"
        expect (view.lines.flatten.all fun cell => cell.style == .normal || cell.style == .muted ||
          cell.style == .series1 || cell.style == .selected) "Selected Day added decorative colors"
        for cells in view.lines do
          expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
            "Selected Day exceeded physical terminal columns"
        if !detailFocused then
          expect (view.lines.any fun cells => cells.any fun cell => cell.style == .selected)
            "focused list lost its selected row"
        else
          expect (!view.lines.flatten.any fun cell => cell.style == .selected)
            "inactive list claimed selected-row focus"
        if bounds.width < 100 && !detailFocused then
          expect (!contains (if pane == .actual then "╭ Scheduled" else "╭ Actual") (widgetText view))
            "compact Selected Day allocated an invisible second list"

  let longNotice := String.ofList (List.replicate 65 '界') ++ "通知末尾"
  let noticeView := Loam.Tui.SelectedDay.view {width := 48, height := 14} snapshot {base with notice := longNotice}
  expect (contains longNotice (compact (widgetText noticeView))) "wrapped feedback lost Japanese text"
  let overflow := Loam.Tui.SelectedDay.view {width := 48, height := 14} snapshot
    {base with notice := String.ofList (List.replicate 600 '界')}
  expect (contains "more feedback/help; enlarge terminal" (widgetText overflow) && overflow.lines.length == 13)
    "over-height feedback was silently truncated"

private def testPaging (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let base := Loam.Tui.SelectedDay.initial "2026-09-07"
  let boundsList : List Bounds := [
    {width := 48, height := 14}, {width := 80, height := 24},
    {width := 99, height := 20}, {width := 100, height := 30}, {width := 150, height := 45}]
  let record ← requireSome actualRecord? "many Actual reference"
  let occurrence ← requireSome scheduledRecord? "many Scheduled reference"
  let actuals ← (List.range 20).mapM fun i => do
    let event ← requireSome (Event.ofEffects? ⟨s!"row-{i}"⟩
      [Effect.ofQuantity ⟨s!"row-{i}-from"⟩ paypay yen (Quantity.ofQuanta (-640)),
       Effect.ofQuantity ⟨s!"row-{i}-to"⟩ food yen (Quantity.ofQuanta 640)]) "many Actual Event"
    pure {record with event, description := s!"ROW-{i}#"}
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? ((List.range 20).map fun i =>
    {occurrence with id := ⟨s!"plan-{i}"⟩})) "many Scheduled memory"
  let .ok evidence := snapshot.scheduled | throw (IO.userError "Scheduled reference")
  let many := {snapshot with
    actual := {snapshot.actual with allRecords := actuals}
    scheduled := .ok {evidence with scheduled}}
  for bounds in boundsList do
    let initialView := Loam.Tui.SelectedDay.view bounds many base
    let top ← rowIndex "╭ Actual" initialView
    let bottom ← rowIndex "╰ 1/20" initialView
    let heading := if contains "Description" (widgetText initialView) then 1 else 0
    let visible := bottom - top - 1 - heading
    let paged := press bounds many base .pageDown
    expect (paged.actualRow == min 19 (max 1 visible)) "Actual page ignored visible data rows"
    let last := press bounds many paged .«end»
    let selected ← requireSome (Loam.Tui.SelectedDay.selectedActual? many last) "last Actual selection"
    expect (contains selected.description (widgetText (Loam.Tui.SelectedDay.view bounds many last)))
      "last Actual row was selected off-screen"
    let first := press bounds many last .home
    expect (first.actualRow == 0) "Actual Home failed to reach first row"
    let focused := press bounds many base .focusRight
    let scheduledPage := press bounds many focused .pageDown
    expect (scheduledPage.scheduledRow == min 19 (max 1 visible)) "Scheduled page ignored visible rows"
    let endPlan := press bounds many scheduledPage .«end»
    expect (endPlan.scheduledRow == 19 && contains "20/20" (widgetText (Loam.Tui.SelectedDay.view bounds many endPlan)))
      "Scheduled selection did not follow its viewport"
    let batched := press bounds many base .next 100
    expect (batched.actualRow == 19) "batched selection exceeded or missed final row"
    let fresh := {many with actual := {many.actual with allRecords := actuals.take 2}}
    let reloaded := Loam.Tui.SelectedDay.refreshed fresh last
    expect (reloaded.actualRow == 1 && reloaded.focusDate == base.focusDate && reloaded.detailScroll == 0)
      "reload changed day or retained an invalid cursor/detail offset"

private def testWrappedDetails (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let base := Loam.Tui.SelectedDay.initial "2026-09-07"
  let boundsList : List Bounds := [
    {width := 48, height := 14}, {width := 80, height := 24},
    {width := 99, height := 20}, {width := 100, height := 30}, {width := 150, height := 45}]
  let record ← requireSome actualRecord? "wrapped Actual reference"
  let huge : Int := 12345678901234567890123456789012345678901234567890123456789012345678901234567890
  let longLocus := String.ofList (List.replicate 50 '界') ++ "-locus-tail"
  let longDescription := "説明先頭" ++ String.ofList (List.replicate 75 '界') ++ "説明末尾"
  let identity := "identity-" ++ String.ofList (List.replicate 80 'x') ++ "-identity-tail"
  let event ← requireSome (Event.ofEffects? ⟨identity⟩
    [Effect.ofQuantity ⟨"huge-from"⟩ ⟨longLocus⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-huge)),
     Effect.ofQuantity ⟨"huge-to"⟩ food ⟨"usd"⟩ (Quantity.ofQuanta huge)]) "huge Event"
  let large := {snapshot with actual := {snapshot.actual with allRecords := [{record with event, description := longDescription}]}}
  for bounds in boundsList do
    let listView := Loam.Tui.SelectedDay.view bounds large base
    expect (contains "…" (widgetText listView) && contains "see details" (widgetText listView))
      "list silently clipped long description or huge quantity"
    let mut state := press bounds large base .focusDetails
    let mut seen := String.intercalate "\n" (detailContent (Loam.Tui.SelectedDay.view bounds large state))
    for _ in List.range 200 do
      let next := press bounds large state .next
      if next.detailScroll == state.detailScroll then break
      state := next
      seen := seen ++ "\n" ++ (detailContent (Loam.Tui.SelectedDay.view bounds large state)).getLast!
    let joined := compact seen
    let grouped := Loam.MeasurePresentation.groupDisplayedNumber (toString huge)
    expect (contains longLocus joined && contains longDescription joined && contains identity joined)
      "scrollable Detail lost full Locus, Japanese description, or identity"
    expect (contains ("-" ++ grouped ++ "usd") joined && contains ("+" ++ grouped ++ "usd") joined)
      "scrollable Detail lost signed exact quantity digits or Measure"
    expect (state.actualRow == 0 && state.focusDate == base.focusDate) "detail scrolling changed evidence selection"
    let maximum := state.detailScroll
    let up := press bounds large state .previous
    expect (up.detailScroll + 1 == maximum) "one up step did not leave true detail bottom"
    let home := press bounds large up .home
    expect (home.detailScroll == 0) "detail Home did not reach top"
    let endState := press bounds large home .«end»
    expect (endState.detailScroll == maximum) "detail End missed exact last offset"
    let resized := Loam.Tui.SelectedDay.normalizedForBounds {width := 150, height := 45} large endState
    expect (resized.actualRow == 0 && resized.detailFocused && resized.detailScroll ≤ maximum)
      "resize changed selection/focus or failed to clamp wrapped details"
    let back := Loam.Tui.SelectedDay.updateForBounds bounds large state .back
    expect (back.command == .stay && !back.state.detailFocused) "detail back left the workspace"
    expect ((Loam.Tui.SelectedDay.updateForBounds bounds large back.state .back).command == .back)
      "list back failed to delegate parent navigation"

private def testReadStates (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let base := Loam.Tui.SelectedDay.initial "2026-09-07"
  let record ← requireSome actualRecord? "split Actual reference"
  let mixed ← requireSome (Event.ofEffects? ⟨"mixed"⟩
    [Effect.ofQuantity ⟨"mixed-jpy-from"⟩ paypay yen (Quantity.ofQuanta (-640)),
     Effect.ofQuantity ⟨"mixed-jpy-to"⟩ food yen (Quantity.ofQuanta 640),
     Effect.ofQuantity ⟨"mixed-usd-from"⟩ paypay ⟨"usd"⟩ (Quantity.ofQuanta (-20)),
     Effect.ofQuantity ⟨"mixed-usd-to"⟩ food ⟨"usd"⟩ (Quantity.ofQuanta 20)]) "mixed event"
  let split ← requireSome (Event.ofEffects? ⟨"split"⟩
    [Effect.ofQuantity ⟨"split-from"⟩ paypay yen (Quantity.ofQuanta (-30)),
     Effect.ofQuantity ⟨"split-to-1"⟩ food yen (Quantity.ofQuanta 10),
     Effect.ofQuantity ⟨"split-to-2"⟩ ⟨"wifi"⟩ yen (Quantity.ofQuanta 20)]) "split event"
  for (event, marker) in [(mixed, "multi (2)"), (split, "split")] do
    let observed := {snapshot with actual := {snapshot.actual with allRecords := [{record with event}]}}
    expect (contains marker (widgetText (Loam.Tui.SelectedDay.view {width := 100, height := 30} observed base)))
      "Actual list invented a total for split or multi-Measure Effects"

  for scheduled in [snapshot.scheduled, .error ("unavailable-" ++ String.ofList (List.replicate 80 '界') ++ "-failure-tail")] do
    let observed := {snapshot with scheduled}
    let state := {base with focusDate := "2026-09-08", pane := .scheduled}
    let view := Loam.Tui.SelectedDay.view {width := 48, height := 14} observed state
    expect (!contains "0/0" (widgetText view)) "Unknown/unavailable Scheduled became an admitted zero count"
    let focused := press {width := 48, height := 14} observed state .focusDetails
    let last := press {width := 48, height := 14} observed focused .«end»
    expect (contains (if scheduled.isOk then "NotDue." else "-failure-tail")
      (widgetText (Loam.Tui.SelectedDay.view {width := 48, height := 14} observed last)))
      "Scheduled diagnostic/Unknown distinction was not fully reviewable"
    expect ((Loam.Tui.SelectedDay.updateForBounds {width := 48, height := 14} observed state .completeScheduled).command == .stay)
      "Scheduled uncertainty emitted completion intent"

private def testScheduledDetails (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let huge : Int := 123456789012345678901234567890123456789012345678901234567890
  let source := String.ofList (List.replicate 40 '界') ++ "-plan-source-tail"
  let identity := "plan-" ++ String.ofList (List.replicate 70 'x') ++ "-plan-id-tail"
  let movement ← requireSome (BalancedMovement.ofChanges? ⟨"usd"⟩
    [{coordinate := ⟨source⟩, quantity := Quantity.ofQuanta (-huge)},
     {coordinate := food, quantity := Quantity.ofQuanta huge}]) "huge Scheduled movement"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences?
    [{id := ⟨identity⟩, scheduledOn := "2026-09-07", movement}]) "huge Scheduled memory"
  let .ok evidence := snapshot.scheduled | throw (IO.userError "Scheduled reference")
  let observed := {snapshot with scheduled := .ok {evidence with scheduled}}
  let bounds : Bounds := {width := 48, height := 14}
  let base : Loam.Tui.SelectedDay.State := {focusDate := "2026-09-07", pane := .scheduled}
  let listView := widgetText (Loam.Tui.SelectedDay.view bounds observed base)
  expect (contains "see details" listView && contains "…" listView) "Scheduled list silently clipped shape/quanta"
  let mut state := press bounds observed base .focusDetails
  let mut seen := String.intercalate "\n" (detailContent (Loam.Tui.SelectedDay.view bounds observed state))
  for _ in List.range 100 do
    let next := press bounds observed state .next
    if next.detailScroll == state.detailScroll then break
    state := next
    seen := seen ++ "\n" ++ (detailContent (Loam.Tui.SelectedDay.view bounds observed state)).getLast!
  let grouped := Loam.MeasurePresentation.groupDisplayedNumber (toString huge)
  expect (contains source (compact seen) && contains identity (compact seen) &&
    contains ("+" ++ grouped ++ "usd") (compact seen) && contains ("-" ++ grouped ++ "usd") (compact seen))
    "Scheduled Detail lost exact expected Effects, Locus or identity"
  expect (state.scheduledRow == 0 && state.actualRow == 0) "Scheduled detail scroll moved object selection"

private def testTransaction (snapshot : Loam.Tui.Main.Snapshot) : IO Unit := do
  let record ← requireSome actualRecord? "transaction reference"
  let unrelated := { record with
    event := {record.event with id := ⟨"other-event"⟩}
    description := "UNRELATED-TRANSACTION" }
  let observed := {snapshot with actual := {snapshot.actual with allRecords := [unrelated, record]}}
  let base := Loam.Tui.SelectedDay.initialTransaction record
  expect (base.actualTarget? == some record.event.id &&
    (Loam.Tui.SelectedDay.selectedActual? observed base).map (·.event.id) == some record.event.id)
    "focused entrance selected a day row rather than the requested Event"
  let actions : List (Loam.Tui.SelectedDay.Event × Loam.Tui.SelectedDay.Command) :=
    [(.correctActual, .correctActual), (.correctDate, .correctDate), (.reverseActual, .reverseActual),
     (.classifyMerchant, .classifyMerchant), (.manageLoci, .manageLoci), (.recordNew, .recordNew)]
  for (event, command) in actions do
    expect ((Loam.Tui.SelectedDay.update observed base event).command == command)
      "focused detail lost an existing Actual action"
  for event in [Loam.Tui.SelectedDay.Event.focusRight, .focusLeft, .focusDetails] do
    let next := (Loam.Tui.SelectedDay.update observed base event).state
    expect (next.actualTarget? == base.actualTarget? && next.pane == .actual && next.detailFocused)
      "focused detail leaked into day-browser navigation"
  expect ((Loam.Tui.SelectedDay.update observed base .back).command == .back)
    "focused detail required another back press before returning to Actual"
  for event in [Loam.Tui.SelectedDay.Event.createScheduled, .completeScheduled, .cancelScheduled, .replaceScheduled] do
    expect ((Loam.Tui.SelectedDay.update observed base event).command == .stay)
      "focused Actual emitted a Scheduled intent"

  for width in [0, 1, 2, 24, 32, 48, 80, 100, 160] do
    for height in [0, 1, 2, 6, 10, 14, 24, 40] do
      let bounds : Bounds := {width, height}
      let view := Loam.Tui.SelectedDay.view bounds observed base
      expect (view.lines.length <= height - 1 && view.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= Loam.Tui.Layout.contentWidth bounds)
        s!"transaction detail exceeded {width}x{height}"
      let text := widgetText view
      expect (!contains unrelated.description text && !contains "Household Day" text &&
        !contains "Scheduled" text && !contains "Description  " text)
        "focused detail rendered another transaction or day list"
  let bounds : Bounds := {width := 100, height := 30}
  let text := widgetText (Loam.Tui.SelectedDay.view bounds observed base)
  for needle in ["Actual / Transaction detail", "Status: Current", "コンビニ", "2026-09-07",
      "paypay", "food", "-640 jpy", "+640 jpy", "event-day",
      "Correct contents / description", "Change date", "Reverse", "Merchant", "Manage Loci", "Record new"] do
    expect (contains needle text) ("transaction detail lost: " ++ needle)

  let reversedRecord := {record with reversedBy := some ⟨"inverse-event"⟩, merchant := some .nonmerchant}
  let reversedSnapshot := {observed with actual := {observed.actual with allRecords := [reversedRecord]}}
  let reversedText := widgetText (Loam.Tui.SelectedDay.view bounds reversedSnapshot base)
  expect (contains "Reversed by: inverse-event" reversedText && contains "Merchant: Nonmerchant" reversedText &&
    !contains "[r] Reverse" reversedText && !contains "[c] Correct" reversedText &&
    !contains "[m] Merchant classification" reversedText && contains "[d] Change date" reversedText)
    "focused actions or status ignored explicit reversal / Merchant evidence"

  let moved := {observed with actual := {observed.actual with allRecords :=
    [unrelated, {record with date := some "2026-09-08"}]}}
  let reloaded := Loam.Tui.SelectedDay.refreshed moved base
  expect (reloaded.focusDate == "2026-09-08" &&
    (Loam.Tui.SelectedDay.selectedActual? moved reloaded).map (·.event.id) == some record.event.id)
    "date correction replaced focused identity with another day row"
  let replaced := {observed with actual := {observed.actual with allRecords :=
    [unrelated, {record with replacement := some unrelated.event.id}]}}
  let unavailable := Loam.Tui.SelectedDay.refreshed replaced base
  expect ((Loam.Tui.SelectedDay.selectedActual? replaced unavailable).isNone)
    "correction selected an unrelated replacement implicitly"
  let unavailableText := widgetText (Loam.Tui.SelectedDay.view bounds replaced unavailable)
  expect (contains "no longer current" unavailableText && contains "event-day" unavailableText &&
    !contains "コンビニ" unavailableText && !contains unrelated.description unavailableText)
    "corrected detail showed stale Effects or a different Event"
  for event in [Loam.Tui.SelectedDay.Event.correctActual, .correctDate, .reverseActual, .classifyMerchant] do
    expect ((Loam.Tui.SelectedDay.update replaced unavailable event).command == .stay)
      "corrected target emitted a stale mutation intent"

  let undated := {record with date := none}
  let unknown := {snapshot with actual := {snapshot.actual with allRecords := [undated]}}
  let undatedState := Loam.Tui.SelectedDay.initialTransaction undated
  let unknownText := widgetText (Loam.Tui.SelectedDay.view bounds unknown undatedState)
  expect (contains "date unknown" unknownText && !contains "[c] Correct" unknownText &&
    !contains "[d] Change date" unknownText && !contains "[n] Record new" unknownText &&
    (Loam.Tui.SelectedDay.update unknown undatedState .recordNew).command == .stay &&
    (Loam.Tui.SelectedDay.refreshed unknown base).focusDate.isEmpty)
    "undated detail invented a recording date or advertised an unsupported editor"

  let long := {record with description := String.join (List.replicate 40 "長い説明") ++ "description-tail"}
  let longSnapshot := {observed with actual := {observed.actual with allRecords := [unrelated, long]}}
  let compactBounds : Bounds := {width := 32, height := 10}
  let compactState := Loam.Tui.SelectedDay.initialTransaction long
  let last := press compactBounds longSnapshot compactState .«end»
  expect (last.detailScroll > 0 && contains "Merchant classification"
    (widgetText (Loam.Tui.SelectedDay.view compactBounds longSnapshot last)))
    "compact focused detail could not reach its actions"
  let page := press compactBounds longSnapshot compactState .pageDown
  expect (page.detailScroll == 5) "focused detail page did not match the visible body rows"
  expect ((press compactBounds longSnapshot last .previous).detailScroll + 1 == last.detailScroll &&
    (press compactBounds longSnapshot last .home).detailScroll == 0)
    "focused detail retained phantom scroll offsets"
  let enlarged := Loam.Tui.SelectedDay.normalizedForBounds bounds longSnapshot last
  expect (enlarged.actualTarget? == base.actualTarget? && enlarged.detailScroll <= last.detailScroll)
    "focused resize changed identity or failed to clamp scrolling"

def main : IO Unit := do
  let snapshot ← fixture
  let state := Loam.Tui.SelectedDay.initial "2026-09-07"
  expect ((Loam.Tui.SelectedDay.actualRecords snapshot state).length == 1)
    "Selected-day workspace did not reuse the shared Actual day answer"
  expect ((Loam.Tui.SelectedDay.scheduledRecords snapshot state).length == 1)
    "Selected-day workspace did not reuse the shared Scheduled day answer"

  let actualText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot state)
  expect (contains "Household Day Workspace" actualText)
    "Selected-day workspace heading disappeared"
  expect (contains "コンビニ" actualText && contains "Selected Actual" actualText)
    "Selected-day workspace did not keep Actual evidence and detail together"

  let correctionStep := Loam.Tui.SelectedDay.update snapshot state .correctActual
  expect (correctionStep.command == .correctActual)
    "Selected-day Actual selection stopped delegating Correction intent"
  let reversalStep := Loam.Tui.SelectedDay.update snapshot state .reverseActual
  expect (reversalStep.command == .reverseActual)
    "Selected-day Actual selection stopped delegating Reversal intent"
  let dateStep := Loam.Tui.SelectedDay.update snapshot state .correctDate
  expect (dateStep.command == .correctDate)
    "Selected-day Actual selection stopped delegating date-correction intent"
  let lociStep := Loam.Tui.SelectedDay.update snapshot state .manageLoci
  expect (lociStep.command == .manageLoci)
    "Selected-day Actual pane stopped delegating Manage Loci navigation"

  let scheduledState := (Loam.Tui.SelectedDay.update snapshot state .focusRight).state
  let scheduledText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot scheduledState)
  expect (contains "scheduled-day" scheduledText && contains "Selected Scheduled" scheduledText)
    "Selected-day workspace did not keep Scheduled evidence and detail together"
  let refusalMessage :=
    "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let refusedScheduledState := { scheduledState with notice := refusalMessage }
  let refusedScheduledText := widgetText
    (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot refusedScheduledState)
  expect (contains (compact refusalMessage) (compact refusedScheduledText))
    "Selected-day workspace did not render a Scheduled replacement refusal notice from its current state"
  let refusedCorrection := Loam.Tui.SelectedDay.update snapshot scheduledState .correctActual
  expect (refusedCorrection.command == .stay)
    "Scheduled pane emitted an Actual Correction intent"
  let refusedReversal := Loam.Tui.SelectedDay.update snapshot scheduledState .reverseActual
  expect (refusedReversal.command == .stay)
    "Scheduled pane emitted an Actual Reversal intent"
  let refusedDate := Loam.Tui.SelectedDay.update snapshot scheduledState .correctDate
  expect (refusedDate.command == .stay)
    "Scheduled pane emitted an Actual date-correction intent"
  let refusedLoci := Loam.Tui.SelectedDay.update snapshot scheduledState .manageLoci
  expect (refusedLoci.command == .stay)
    "Scheduled pane emitted Actual-side Manage Loci navigation"

  let movedSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { snapshot.actual with allRecords := [] } }
  let refreshed := Loam.Tui.SelectedDay.refreshed movedSnapshot state
  expect (refreshed.focusDate == "2026-09-07" && refreshed.actualRow == 0)
    "fresh reload moved the selected-day coordinate instead of only clamping local row state"

  let newStep := Loam.Tui.SelectedDay.update snapshot state .recordNew
  expect (newStep.command == .recordNew)
    "Selected-day workspace stopped delegating new Actual to the shared Record path"
  let backStep := Loam.Tui.SelectedDay.update snapshot state .back
  expect (backStep.command == .back)
    "Selected-day workspace back command changed"

  let unknown := Loam.Tui.SelectedDay.initial "2026-09-08"
  let unknownState := (Loam.Tui.SelectedDay.update snapshot unknown .focusRight).state
  let unknownText := widgetText (Loam.Tui.SelectedDay.view { width := 100, height := 30 } snapshot unknownState)
  expect (contains "Unknown: absence of an explicit due occurrence is not NotDue." unknownText)
    "Selected-day workspace collapsed Scheduled Unknown into NotDue"

  let unavailable : Loam.Tui.Main.Snapshot :=
    { snapshot with scheduled := .error "scheduled fixture unavailable" }
  let unavailableScheduledState :=
    (Loam.Tui.SelectedDay.update unavailable state .focusRight).state
  let unavailableText := widgetText
    (Loam.Tui.SelectedDay.view { width := 100, height := 30 } unavailable unavailableScheduledState)
  expect (contains "Scheduled [Unavailable]" unavailableText &&
    contains "[Unavailable] scheduled fixture unavailable" unavailableText)
    "Selected-day workspace collapsed unavailable Scheduled evidence into an empty pane"
  let unavailableCreate :=
    Loam.Tui.SelectedDay.update unavailable unavailableScheduledState .createScheduled
  expect (unavailableCreate.command == .stay)
    "Selected-day workspace emitted a Scheduled write intent while Scheduled evidence was unavailable"

  testFrames snapshot
  testPaging snapshot
  testWrappedDetails snapshot
  testReadStates snapshot
  testScheduledDetails snapshot
  testTransaction snapshot
  IO.println "TUI selected day: quiet frames, compact feedback, selection/paging, wrapped details and shared read/write delegation passed."
