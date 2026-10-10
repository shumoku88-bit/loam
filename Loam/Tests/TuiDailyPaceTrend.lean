import Loam.Tui.DailyPaceTrend

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))

private def contains (needle haystack : String) : Bool := (haystack.splitOn needle).length > 1

private def compact (value : String) : String :=
  String.ofList (value.toList.filter fun char => char != ' ' && char != '\n' && char != '│')

private def point (day : String) (quanta : Int) (measure : String := "jpy") : Loam.CycleSpendingPaceReview.Snapshot := {
  measure := ⟨measure⟩
  observedAt := day
  endExclusive := "2026-11-01"
  remainingDays := 1
  eligiblePool := Quantity.ofQuanta quanta
  automaticDeductions := Quantity.ofQuanta 0
  availableThroughEnd := Quantity.ofQuanta quanta
}

private def snapshot (history : Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot)) : Loam.Tui.Main.Snapshot := {
  actual := {today := "2026-10-30", allRecords := []}
  scheduled := .error "synthetic fixture"
  paceHistory := history
}

private def press (bounds : Bounds) (world : Loam.Tui.Main.Snapshot) (state : Loam.Tui.DailyPaceTrend.State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1) : IO Loam.Tui.DailyPaceTrend.State :=
  match Loam.Tui.DailyPaceTrend.update bounds world state key repeatCount with
  | .stay next => pure next
  | .back => throw (IO.userError "unexpected parent back")

private def details (view : Widget) : List String :=
  let lines := view.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  ((lines.dropWhile fun row => !contains "╭ Selected day" row).drop 1).takeWhile fun row => !contains "╰" row

private def readDetails (bounds : Bounds) (world : Loam.Tui.Main.Snapshot)
    (initial : Loam.Tui.DailyPaceTrend.State := {}) : IO String := do
  let mut state ← press bounds world {initial with detailFocused := false} .enter
  let mut seen := String.intercalate "\n" (details (Loam.Tui.DailyPaceTrend.view bounds world state))
  for _ in List.range 500 do
    let next ← press bounds world state .down
    if state.detailScroll == next.detailScroll then break
    state := next
    seen := seen ++ "\n" ++ (details (Loam.Tui.DailyPaceTrend.view bounds world state)).getLast!
  pure (compact seen)

private def testGeometryAndMovement : IO Unit := do
  let history := (List.range 30).map fun i =>
    point ("2026-10-" ++ (if i < 9 then "0" else "") ++ toString (i + 1)) (100 + Int.ofNat i * 10)
  let world := snapshot (.loaded history)
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24},
      {width := 119, height := 20}, {width := 120, height := 30}, {width := 150, height := 45}] do
    let view := Loam.Tui.DailyPaceTrend.view bounds world
    expect (view.lines.length == bounds.height - 1 && view.lines.all fun cells =>
      Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
      "Daily Pace exceeded usable tty geometry"
    expect (contains "╭ Trend [active]" (text view) && contains "Selected 2026-10-30" (text view) &&
      contains "390 jpy/day  current" (text view)) "latest point, current marker or quiet frame missing"
    expect (contains "[q] back" (String.ofList ((view.lines[bounds.height - 3]!).map Cell.glyph)) &&
      contains "[Home/End] ends" (String.ofList ((view.lines[bounds.height - 2]!).map Cell.glyph)))
      "Daily Pace navigation left its fixed bottom rows"
    expect (!contains "====" (text view) && view.lines.flatten.all fun cell =>
      cell.style == .normal || cell.style == .muted || cell.style == .series1 || cell.style == .selected)
      "Daily Pace introduced decorative colors/heavy rules"
    expect (view.lines.flatten.any fun cell => decide (0x2800 ≤ cell.glyph.toNat && cell.glyph.toNat ≤ 0x28ff))
      "Daily Pace lost the shared Braille plot"
    let top ← press bounds world {} .home
    expect (top.selected == some 0 && contains "Selected 2026-10-01" (text (Loam.Tui.DailyPaceTrend.view bounds world top)))
      "Daily Pace Home failed to select/reveal first day"
    let capacity := Loam.Tui.DailyPaceTrend.historyCapacityForBounds bounds world top
    let paged ← press bounds world top (.ctrl 'd')
    expect (paged.selected == some (min 29 (max 1 capacity))) "Daily Pace page counted non-data rows"
    let batched ← press bounds world top .right 100
    expect (batched.selected == some 29) "Daily Pace repeat escaped the series"
    let old ← press bounds world batched (.input 'h')
    expect (old.selected == some 28) "existing Daily Pace h key changed meaning"
    let last ← press bounds world old .«end»
    expect (last.selected == some 29) "Daily Pace End failed"
    if capacity > 0 then
      expect (contains "> 2026-10-30" (text (Loam.Tui.DailyPaceTrend.view bounds world last)))
        "selected history row remained below the viewport"
    else expect (contains "list hidden" (text view)) "compact hidden history list lacked an indicator"
    let info ← press bounds world last .tab
    expect (info.detailFocused && info.selected == some 29) "Detail toggle changed selected day"
    let infoView := Loam.Tui.DailyPaceTrend.view bounds world info
    expect (contains "╭ Selected day [active]" (text infoView) &&
      !infoView.lines.flatten.any fun cell => cell.style == .selected) "inactive chart/list kept selected background"
    let day ← press bounds world info .left
    expect (day.detailFocused && day.selected == some 28 && day.detailScroll == 0)
      "Detail day navigation failed to reset the offset"
    let back ← press bounds world day .escape
    expect (!back.detailFocused && back.selected == some 28) "Detail back lost the day or left workspace"
    expect (match Loam.Tui.DailyPaceTrend.update bounds world back (.input 'q') with | .back => true | _ => false)
      "Trend back failed to return to Home"
    let resized := Loam.Tui.DailyPaceTrend.normalizedForBounds bounds
      (snapshot (.loaded (history.take 2))) last
    expect (resized.selected == some 1) "snapshot refresh left an invalid day cursor"
    expect (contains "380 jpy/day" (text (Loam.Tui.DailyPaceTrend.view bounds world day)))
      "day navigation displayed a quantity belonging to another reconstructed point"

private def testReadStates : IO Unit := do
  let cause := "原因: " ++ String.ofList (List.replicate 80 '界') ++ "-failure-tail"
  let bounds : Bounds := {width := 48, height := 14}
  for (history, label) in [(Loam.Presentation.ReadState.notRequested, "history not requested"),
      (.unavailable, "history unavailable"), (.failed cause, "history unavailable"),
      (.loaded [], "no reconstructed Daily Pace points")] do
    let world := snapshot history
    expect (contains label (text (Loam.Tui.DailyPaceTrend.view bounds world))) "optional pace read state collapsed"
    let full ← readDetails bounds world
    expect (contains (compact label) full && contains "noseparatedailysnapshotiskept." full)
      "read-state Detail lost provenance/status"
    if let .failed _ := history then
      expect (contains (compact cause) full) "pace failed-read Detail clipped Japanese/unbroken cause"
    let moved ← press bounds world {} .«end»
    expect (moved.selected.isNone) "missing pace history became a fabricated day or value"

private def testQuantities : IO Unit := do
  let huge : Int := -12345678901234567890123456789012345678901234567890123456789012345678901234567890
  let measure := "measure-" ++ String.ofList (List.replicate 60 '界') ++ "-unit-tail"
  let world := snapshot (.loaded [point "2026-10-29" 0 measure, point "2026-10-30" huge measure])
  let bounds : Bounds := {width := 48, height := 14}
  let view := Loam.Tui.DailyPaceTrend.view bounds world
  expect (contains "see details" (text view) && contains "Chart unavailable:" (text view))
    "oversized pace silently emitted partial digits or attempted enormous tick allocation"
  let full ← readDetails bounds world
  let formatted := Loam.MeasurePresentation.groupDisplayedNumber (toString huge)
  expect (contains formatted full && contains measure full && contains "change" full)
    "pace Detail lost full signed integer quanta, delta or Measure"
  let focused ← press bounds world {} .enter
  let bottom ← press bounds world focused .«end»
  let up ← press bounds world bottom .up
  expect (up.detailScroll + 1 == bottom.detailScroll) "Detail bottom was not a bounded offset"
  let resized := Loam.Tui.DailyPaceTrend.normalizedForBounds {width := 150, height := 45} world bottom
  expect (resized.detailScroll ≤ bottom.detailScroll && resized.detailFocused) "pace resize lost focus or left invalid scroll"
  let bounded := snapshot (.loaded [point "2026-10-30" (10 ^ 24)])
  let boundedText := text (Loam.Tui.DailyPaceTrend.view bounds bounded)
  expect (!contains "Chart unavailable" boundedText && contains "…" boundedText)
    "bounded large axes failed to plot or silently clipped tick digits"
  let zero := snapshot (.loaded [point "2026-10-30" 0])
  expect (contains "0 jpy/day  current" (text (Loam.Tui.DailyPaceTrend.view bounds zero))) "known zero pace disappeared"
  let missing := snapshot (.loaded [{point "2026-10-30" 42 with remainingDays := 0}])
  expect (contains "unavailable" (text (Loam.Tui.DailyPaceTrend.view bounds missing)) &&
    !contains "0 jpy/day" (text (Loam.Tui.DailyPaceTrend.view bounds missing))) "missing daily pace became zero"
  let mixed := snapshot (.loaded [point "2026-10-29" 100 "jpy", point "2026-10-30" 200 "usd"])
  let mixedText ← readDetails bounds mixed
  expect (contains "changeunavailable(differentMeasures)" mixedText &&
    contains "Chartunavailable:differentMeasures" mixedText && !contains "+100usd/day" mixedText)
    "mixed-Measure plot or delta invented an aggregate"
  let usd := snapshot (.loaded [point "2026-10-29" 1000 "usd", point "2026-10-30" 1250 "usd"])
  let usdText := text (Loam.Tui.DailyPaceTrend.view {width := 150, height := 45} usd)
  expect (contains "1,250 usd/day" usdText && contains "change +250 usd/day" usdText && !contains "jpy/day" usdText)
    "pace UI changed Measure or applied an optional money scale"

private def testTiny : IO Unit := do
  for bounds in [{width := 12, height := 5}, {width := 24, height := 8}, {width := 48, height := 14}] do
    for history in [Loam.Presentation.ReadState.loaded [], .loaded [point "2026-10-30" 100], .failed "read failed"] do
      for focused in [false, true] do
        let world := snapshot history
        let state : Loam.Tui.DailyPaceTrend.State := {detailFocused := focused}
        let view := Loam.Tui.DailyPaceTrend.view bounds world state
        expect (view.lines.length ≤ bounds.height - 1 && view.lines.all fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
          "tiny Daily Pace frame escaped bounds"
        let bottom ← press bounds world state .«end»
        expect ((← press bounds world bottom .«end») == bottom) "pace scroll exceeded true endpoint"

def main : IO Unit := do
  testGeometryAndMovement
  testReadStates
  testQuantities
  testTiny
  IO.println "Daily Pace TUI: quiet bounded chart/history, selection/Detail, read states and exact quanta/Measure passed."
