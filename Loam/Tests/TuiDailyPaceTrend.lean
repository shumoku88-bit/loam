import Loam.Tui.DailyPaceTrend
import Loam.Tui.DailyPaceWhatIf

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

private def snapshot (history : Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot)) :
    Loam.Tui.Main.Snapshot :=
  let current : Loam.Presentation.ReadState Loam.CycleSpendingPaceReview.Snapshot :=
    match history with
    | .loaded points => match points.getLast? with
      | some point => .loaded point
      | none => .unavailable
    | .failed message => .failed message
    | .unavailable => .unavailable
    | .notRequested => .notRequested
  { actual := {today := "2026-10-30", allRecords := []}
    scheduled := .error "synthetic fixture"
    paceCurrent := current
    pacePeriods := .loaded (Loam.DailyPacePeriods.presets.map fun preset =>
      {preset, range := .error "synthetic display fixture", history}) }

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

/-- Explain slope without inventing an Event's cause or double-spending a bill. -/
private def testChangeDecomposition : IO Unit := do
  let prior : Loam.CycleSpendingPaceReview.Snapshot := {
    measure := ⟨"jpy"⟩
    observedAt := "2026-10-29"
    endExclusive := "2026-11-08"
    remainingDays := 10
    eligiblePool := Quantity.ofQuanta 10000
    automaticDeductions := Quantity.ofQuanta 3000
    availableThroughEnd := Quantity.ofQuanta 7000
  }
  let settled : Loam.CycleSpendingPaceReview.Snapshot := {
    prior with
      observedAt := "2026-10-30"
      remainingDays := 9
      eligiblePool := Quantity.ofQuanta 9800
      automaticDeductions := Quantity.ofQuanta 2800
  }
  let paid ← match Loam.DailyPaceChangeReview.compare prior settled with
    | .ok value => pure value
    | .error message => throw (IO.userError message)
  expect (paid.previousPace == 700 && paid.currentPace == 777 &&
      paid.changePerDay == 77 && paid.timePassageEffect == 77 &&
      paid.freeMoneyEffect == 0 && paid.poolBalanceChange == -200 &&
      paid.protectionRelease == 200 && paid.freeThroughEndChange == 0)
    "settling a protected bill caused duplicate discretionary spending"

  let spent : Loam.CycleSpendingPaceReview.Snapshot := {
    settled with
      eligiblePool := Quantity.ofQuanta 9100
      automaticDeductions := Quantity.ofQuanta 3000
      availableThroughEnd := Quantity.ofQuanta 6100
  }
  let purchase ← match Loam.DailyPaceChangeReview.compare prior spent with
    | .ok value => pure value
    | .error message => throw (IO.userError message)
  expect (purchase.currentPace == 677 && purchase.changePerDay == -23 &&
      purchase.timePassageEffect == 77 && purchase.freeMoneyEffect == -100 &&
      purchase.poolBalanceChange == -900 && purchase.protectionRelease == 0)
    "a discretionary purchase was not separated from passing time"

  let funded : Loam.CycleSpendingPaceReview.Snapshot := {
    spent with
      eligiblePool := Quantity.ofQuanta 11800
      availableThroughEnd := Quantity.ofQuanta 8800
  }
  let credited ← match Loam.DailyPaceChangeReview.compare prior funded with
    | .ok value => pure value
    | .error message => throw (IO.userError message)
  expect (credited.currentPace == 977 && credited.changePerDay == 277 &&
      credited.timePassageEffect == 77 && credited.freeMoneyEffect == 200)
    "incoming funds were confused with the day-count effect"

  let invalidMeasure := {settled with measure := ⟨"usd"⟩}
  let invalidCycle := {settled with endExclusive := "2026-12-15"}
  let nonadjacent := {settled with observedAt := "2026-11-02"}
  let incorrect := {settled with availableThroughEnd := Quantity.ofQuanta 0}
  expect (!(Loam.DailyPaceChangeReview.compare prior invalidMeasure).isOk &&
      !(Loam.DailyPaceChangeReview.compare prior invalidCycle).isOk &&
      !(Loam.DailyPaceChangeReview.compare prior nonadjacent).isOk &&
      !(Loam.DailyPaceChangeReview.compare prior incorrect).isOk)
    "Daily Pace delta admitted incompatible measures/cycles/days/quantities"

  let details ← readDetails {width := 120, height := 40}
    (snapshot (.loaded [prior, settled]))
  expect (contains "Timepassage:+77jpy/day" details &&
      contains "Freemoneyeffect:0jpy/day" details &&
      contains "Poolbalancedelta:-200jpy" details &&
      contains "Scheduledprotectionrelease:+200jpy" details)
    "Daily Pace details did not explain slope using shared Review evidence"

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

private def testPeriods : IO Unit := do
  let configured : List Loam.BoundaryPresetConfig.Preset := [{name := "explicit", boundaries :=
    ["2026-08-21", "2026-09-21", "2026-10-21", "2026-11-21"]}]
  let periods ← Loam.DailyPacePeriods.presets.mapM fun preset => do
    let range ← match Loam.DailyPacePeriods.resolve preset "2026-10-30" configured with
      | .ok range => pure range | .error message => throw (IO.userError message)
    let days ← match range.dates with
      | .ok days => pure days | .error message => throw (IO.userError message)
    pure ({preset, range := .ok range, history := .loaded (days.map fun day => point day 123)} : Loam.DailyPacePeriods.Period)
  let world := {snapshot .notRequested with pacePeriods := .loaded periods}
  let bounds : Bounds := {width := 160, height := 48}
  let mut state ← press bounds world {} .home
  expect (state.selectedDay == some "2026-10-21") "default 10d was not inclusive"
  for (key, preset) in [(.input '1', Loam.DailyPacePeriods.Preset.tenDays), (.input '2', .thirtyDays),
      (.input '3', .month), (.input '4', .cycle), (.input '5', .previousCycle)] do
    state ← press bounds world state key
    expect (state.period == preset) "period key selected wrong preset"
    expect (state.selectedDay == some (if preset == .previousCycle then "2026-10-20" else "2026-10-21"))
      "range change unnecessarily reset selection or did not clamp"
    let rendered := text (Loam.Tui.DailyPaceTrend.view bounds world state)
    expect (contains ("Selected " ++ state.selectedDay.getD "missing") rendered && contains preset.label rendered)
      "chart/detail period and selected day diverged"
  state ← press bounds world state (.input '4')
  expect (state.selectedDay == some "2026-10-21") "out-of-range selection did not clamp to start"
  state ← press bounds world state (.input '2')
  state ← press bounds world state .home
  expect (state.selectedDay == some "2026-10-01") "30d earliest day wrong"
  state ← press bounds world state (.input '3')
  expect (state.selectedDay == some "2026-10-01") "month was confused with cycle"
  let view := Loam.Tui.DailyPaceTrend.view bounds world state
  let rows := view.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  let trend := (rows.findIdx? (contains "╭ Trend")).getD 999
  let history := (rows.findIdx? (contains "╭ History")).getD 0
  let detail := (rows.findIdx? (contains "╭ Selected day")).getD 0
  expect (trend < history && history == detail && Loam.Tui.Layout.displayWidth rows[trend]! == 159)
    "wide layout did not give chart full width above History/Detail"
  for tty in [{width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 40}, bounds] do
    let resized := Loam.Tui.DailyPaceTrend.normalizedForBounds tty world state
    expect (resized.selectedDay == state.selectedDay && resized.period == state.period) "resize reset period/day"
  let unavailable := {world with pacePeriods := .loaded (periods.map fun period =>
    if period.preset == .cycle then {period with history := .failed "explicit refusal"} else period)}
  let failed ← press bounds unavailable state (.input '4')
  let restored ← press bounds unavailable failed (.input '3')
  expect (restored.selectedDay == state.selectedDay) "refused period destroyed the selected date anchor"
  let longHistory := (List.range 1500).filterMap fun index =>
    (Loam.ActualDate.shiftDays? "2022-01-01" (Int.ofNat index)).map fun day => point day (Int.ofNat index)
  let longWorld := snapshot (.loaded longHistory)
  let mut cursor ← press bounds longWorld {} .home
  for _ in List.range 100 do cursor ← press bounds longWorld cursor .down
  expect (cursor.selected == some 100) "continuous input dropped day movements"
  cursor ← press bounds longWorld cursor .up 75
  expect (cursor.selected == some 25) "rapid reversal left scroll tail or lost events"

/-- Cycle rollover may invalidate every history period while today's money remains known. -/
private def testDayWiseUnknownGaps : IO Unit := do
  let today := point "2026-10-15" 123
  let entries : List Loam.DailyPacePeriods.DaySample := [
    {day := "2026-10-13", answer := .ok (point "2026-10-13" 100)},
    {day := "2026-10-14", answer :=
      .error "2026-10-14: Scheduled was replaced without a learned-time coordinate"},
    {day := "2026-10-15", answer := .ok today, source := .current}
  ]
  let world : Loam.Tui.Main.Snapshot := {
    actual := {today := "2026-10-15", allRecords := []}
    scheduled := .error "synthetic lifecycle"
    paceCurrent := .loaded today
    pacePeriods := .loaded (Loam.DailyPacePeriods.presets.map fun preset =>
      {preset
       range := .ok {start := "2026-10-13", through := "2026-10-15"}
       history := .failed "2026-10-14: Scheduled replacement has unknown time"
       samples := entries})
  }
  for bounds in [({width := 48, height := 14} : Bounds),
      {width := 80, height := 24}, {width := 120, height := 40}] do
    let drawn := text (Loam.Tui.DailyPaceTrend.view bounds world)
    expect (contains "123 jpy/day" drawn && contains "2/3 supported days" drawn)
      "a missing past day erased a qualified present-day Daily Pace point"
    expect (contains "points only" drawn)
      "sparse history connected unknown days instead of using isolated points"
    let initial : Loam.Tui.DailyPaceTrend.State := {}
    let prior ← press bounds world initial .left
    expect (prior.selected == some 1 && prior.selectedDay == some "2026-10-14")
      "unknown day did not remain independently selectable"
    let refused ← readDetails bounds world prior
    expect (contains "unavailable,notzero" refused &&
      contains "learned-timecoordinate" refused)
      ("missing day lost its exact refusal cause: " ++ refused)
    let first ← press bounds world prior .home
    expect (first.selectedDay == some "2026-10-13")
      "partial History Home compressed away qualified earlier days"
    let back ← press bounds world first .«end»
    expect (back.selectedDay == some "2026-10-15")
      "partial History End did not reach today's admitted point"
    let status ← readDetails bounds world back
    expect (contains "currentadmittedtruth" status)
      "current day was mislabeled as an as-known historical observation"
    expect (match Loam.Tui.DailyPaceTrend.update bounds world back (.input 'q') with
      | .back => true | _ => false)
      "partial History lost q-return navigation"

private def testIndependentCurrent : IO Unit := do
  let basePoint := point "2026-10-15" 24000
  let point1 : Loam.CycleSpendingPaceReview.Snapshot :=
    {basePoint with endExclusive := "2026-12-15"}
  let point2 : Loam.CycleSpendingPaceReview.Snapshot :=
    {point1 with remainingDays := 61}
  let point3 : Loam.CycleSpendingPaceReview.Snapshot :=
    {point2 with eligiblePool := Quantity.ofQuanta 30000}
  let pointNow : Loam.CycleSpendingPaceReview.Snapshot :=
    {point3 with automaticDeductions := Quantity.ofQuanta 6000}
  let refusal := "2026-10-14: Scheduled was replaced without a learned-time coordinate"
  let world : Loam.Tui.Main.Snapshot := {
    actual := {today := "2026-10-15", allRecords := []}
    scheduled := .error "synthetic lifecycle"
    paceCurrent := .loaded pointNow
    pacePeriods := .loaded (Loam.DailyPacePeriods.presets.map fun preset =>
      {preset, range := .error "synthetic range", history := .failed refusal}) }
  let accepted ← match Loam.Tui.DailyPaceWhatIf.current? world with
    | .ok point => pure point
    | .error message => throw (IO.userError ("valid today refused: " ++ message))
  expect (accepted.availableThroughEnd.quanta == 24000 &&
      accepted.automaticDeductions.quanta == 6000 &&
      accepted.remainingDays == 61 && accepted.dailyPaceQuanta? == some 393)
    "rollover current did not preserve the independently admitted JPY/day answer"
  let projected ← match Loam.Tui.DailyPaceWhatIf.project? accepted "610" with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  expect (projected.currentPerDay == 393 && projected.projectedPerDay == 383)
    "rollover what-if still depended on the refused historical window"
  for bounds in [({width := 32, height := 9} : Bounds),
      {width := 48, height := 14}, {width := 80, height := 24},
      {width := 120, height := 40}] do
    let view := Loam.Tui.DailyPaceTrend.view bounds world
    expect (contains "393 jpy/day" (text view))
      "valid today amount disappeared when every historical range was refused"
    let full ← readDetails bounds world
    expect (contains "Free through cycle end:" full || contains "Freethroughcycleend:" full)
      "rollover detail lost independent free-to-spend explanation"
    expect (contains "replacedwithoutalearned-timecoordinate" full)
      "rollover details hid the precise historical refusal"
  let compactView := text (Loam.Tui.DailyPaceTrend.view
    {width := 24, height := 8} world)
  expect (contains "Daily:" compactView && contains "393 jpy/day" compactView)
    "compact Daily Pace lost its recognizable title or independent today allowance"
  let refused := {world with paceCurrent := .failed "current balance is not admitted"}
  expect (!(Loam.Tui.DailyPaceWhatIf.current? refused).isOk)
    "what-if fabricated a current point when only the past is available"
  expect (contains "unavailable" (text (Loam.Tui.DailyPaceTrend.view
      {width := 80, height := 24} refused)))
    "current failure was silently presented as a numeric zero"

private def testWhatIf : IO Unit := do
  let pointNow : Loam.CycleSpendingPaceReview.Snapshot := {
    point "2026-10-30" 24000 with remainingDays := 20 }
  let world := snapshot (.loaded [pointNow])
  let current ← match Loam.Tui.DailyPaceWhatIf.current? world with
    | .ok point => pure point
    | .error message => throw (IO.userError message)
  let result ← match Loam.Tui.DailyPaceWhatIf.project? current "8000" with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  expect (result.currentPerDay == 1200 && result.projectedPerDay == 800 &&
      result.changePerDay == -400 && result.availableAfter == 16000)
    "what-if did not subtract an unrecorded JPY outflow from the admitted available pool"
  let overdraw ← match Loam.Tui.DailyPaceWhatIf.project? current "30000" with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  expect (overdraw.availableAfter == -6000 && overdraw.projectedPerDay == -300)
    "overdrawn what-if was silently clamped to zero"
  expect (!(Loam.Tui.DailyPaceWhatIf.project? current "").isOk &&
      !(Loam.Tui.DailyPaceWhatIf.project? current "-20").isOk &&
      !(Loam.Tui.DailyPaceWhatIf.project? current "1.5").isOk &&
      !(Loam.Tui.DailyPaceWhatIf.project? current "1234567890123456789").isOk)
    "invalid, negative, decimal or unbounded hypothetical amounts were accepted"
  let editor ← match Loam.Tui.DailyPaceWhatIf.update {} (.paste "8000") with
    | .stay state => pure state
    | .back => throw (IO.userError "paste unexpectedly closed what-if")
  expect (editor.amount == "8000") "what-if did not accept exact paste"
  let rejected ← match Loam.Tui.DailyPaceWhatIf.update editor (.paste "-30") with
    | .stay state => pure state
    | .back => throw (IO.userError "invalid paste unexpectedly closed what-if")
  expect (rejected.amount == editor.amount && !rejected.notice.isEmpty)
    "invalid paste changed the hypothetical amount"
  let deleted ← match Loam.Tui.DailyPaceWhatIf.update editor .backspace with
    | .stay state => pure state
    | .back => throw (IO.userError "backspace unexpectedly closed what-if")
  expect (deleted.amount == "800") "what-if backspace lost local input"
  expect (match Loam.Tui.DailyPaceWhatIf.update editor .enter with
      | .stay next => next == editor
      | .back => false)
    "Enter must never publish or close the what-if"
  expect (match Loam.Tui.DailyPaceWhatIf.update editor .escape with
      | .back => true | _ => false)
    "Esc did not close the what-if"
  let stale := {world with actual := {world.actual with today := "2026-10-31"}}
  expect (!(Loam.Tui.DailyPaceWhatIf.current? stale).isOk &&
      !(Loam.Tui.DailyPaceWhatIf.current? (snapshot (.failed "refused"))).isOk)
    "missing today or failed current projection was interpreted as available"
  let usd := snapshot (.loaded [point "2026-10-30" 1000 "usd"])
  expect (!(Loam.Tui.DailyPaceWhatIf.current? usd).isOk)
    "JPY what-if silently accepted foreign-currency input"
  for bounds in [{width := 120, height := 40},
      {width := 48, height := 14}, {width := 24, height := 8}] do
    let view := Loam.Tui.DailyPaceWhatIf.viewForBounds bounds world editor
    expect (view.lines.length ≤ bounds.height - 1 &&
      view.lines.all fun row =>
        Loam.Tui.Layout.displayWidth (String.ofList (row.map Cell.glyph)) ≤ bounds.width - 1)
      "what-if floating/compact view escaped visible terminal geometry"
    expect (contains "Daily Pace / What if" (text view))
      "what-if lost its screen title on resize"
  for bounds in [({width := 32, height := 9} : Bounds), {width := 48, height := 14},
      {width := 80, height := 24}, {width := 120, height := 40}] do
    for amount in ["", "123456789012345678"] do
      let input := {editor with amount}
      let widget := Loam.Tui.DailyPaceWhatIf.viewForBounds bounds world input
      let markers := widget.lines.flatten.filter (·.caret)
      expect (markers.length == 1 && markers.all (fun cell => cell.glyph == ' '))
        "What-if amount lost its safe insertion blank during resize"
      expect (widget.lines.any fun cells => cells.any (·.caret) &&
        contains "Purchase (JPY):" (String.ofList (cells.map Cell.glyph)))
        "What-if caret escaped its amount field"
      expect (match Loam.Tui.DailyPaceWhatIf.update input .enter with
        | .stay retained => retained.amount == amount | .back => false)
        "What-if resized field changed bytes on Enter"
    expect (!(Loam.Tui.DailyPaceTrend.view bounds world {}).lines.flatten.any (·.caret))
      "Daily Pace navigation displayed a text caret"
  let visible := text (Loam.Tui.DailyPaceWhatIf.viewForBounds
    {width := 120, height := 40} world editor)
  expect (contains "800 jpy/day" visible &&
      contains "-400 jpy/day" visible && contains "16,000 jpy" visible &&
      contains "No writes" visible && contains "Not already Scheduled" visible)
    "what-if modal lost projection, safeguard or nonpublication disclosure"

 def main : IO Unit := do
  testDayWiseUnknownGaps
  testChangeDecomposition
  testIndependentCurrent
  testWhatIf
  testPeriods
  testGeometryAndMovement
  testReadStates
  testQuantities
  testTiny
  IO.println "Daily Pace TUI: quiet bounded chart/history, selection/Detail, read states and exact quanta/Measure passed."
