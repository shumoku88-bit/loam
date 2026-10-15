import Loam.Review.DailyPaceChangeReview
import Loam.Tui.Chart
import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.Scroll

namespace Loam.Tui.DailyPaceTrend

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Daily Pace trend

Read-only presentation of entry-prepared retrospective current-truth daily
periods. CycleSpendingPaceReview still owns reconstruction and quanta/day; Chart
still owns interpolation and plotting. Period/day/focus/scroll state is local,
not a saved observation, query setting, or household publication.
-/

inductive GraphStyle where
  | connected
  | points
  deriving Repr, DecidableEq

def GraphStyle.next : GraphStyle → GraphStyle
  | .connected => .points
  | .points => .connected

def GraphStyle.label : GraphStyle → String
  | .connected => "line"
  | .points => "dots"

structure State where
  /-- `none` follows the most recent reconstructed day on first entry. -/
  selected : Option Nat := none
  period : Loam.DailyPacePeriods.Preset := .tenDays
  /-- Date anchor survives a refused period; index is only an in-period cursor. -/
  selectedDay : Option String := none
  detailFocused : Bool := false
  detailScroll : Nat := 0
  /-- Display preference only; independent of preset, accounting and provenance. -/
  graphStyle : GraphStyle := .connected
  deriving Repr, DecidableEq

inductive Step where
  | stay (state : State)
  | back

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def historyState (snapshot : Loam.Tui.Main.Snapshot) (state : State) :
    Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot) :=
  match snapshot.pacePeriods with
  | .loaded periods =>
      ((periods.find? fun period => period.preset == state.period).map (·.history)).getD
        (.failed "Daily Pace: period not prepared")
  | .failed message => .failed message
  | .unavailable => .unavailable
  | .notRequested => .notRequested

private def historyFor (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Loam.CycleSpendingPaceReview.Snapshot :=
  match historyState snapshot state with
  | .loaded history => history
  | _ => []

private def selectedIndex (history : List Loam.CycleSpendingPaceReview.Snapshot) (state : State) : Nat :=
  min (history.length - 1) (state.selected.getD (history.length - 1))


/-- An unavailable date remains a calendar slot; do not compress x-axis gaps. -/
private def partialSamples (snapshot : Loam.Tui.Main.Snapshot) (state : State) :
    List Loam.DailyPacePeriods.DaySample :=
  match snapshot.pacePeriods with
  | .loaded periods =>
      match periods.find? (fun period => period.preset == state.period) with
      | some period =>
          match period.history with
          | .loaded _ => []
          | _ => period.samples
      | none => []
  | _ => []


/-- Keep one calendar-aligned plot source regardless of historical completeness.
Older fully supported fixtures still provide only the legacy history list. -/
private def graphSamples (snapshot : Loam.Tui.Main.Snapshot) (state : State) :
    List Loam.DailyPacePeriods.DaySample :=
  match snapshot.pacePeriods with
  | .loaded periods =>
      match periods.find? (fun period => period.preset == state.period) with
      | some period =>
          if !period.samples.isEmpty then period.samples else
            match period.history with
            | .loaded history => history.map fun point =>
                {day := point.observedAt, answer := .ok point}
            | _ => []
      | none => []
  | _ => []

private def sampleIndex (samples : List Loam.DailyPacePeriods.DaySample) (state : State) : Nat :=
  min (samples.length - 1) (state.selected.getD (samples.length - 1))

private def sampleDate (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Option String :=
  let history := historyFor snapshot state
  if !history.isEmpty then
    (history[selectedIndex history state]?).map (·.observedAt)
  else
    let samples := partialSamples snapshot state
    (samples[sampleIndex samples state]?).map (·.day)

private def moveBy (state : State) (snapshot : Loam.Tui.Main.Snapshot) (back : Bool) (amount : Nat) : State :=
  let history := historyFor snapshot state
  if history.isEmpty then
    let samples := partialSamples snapshot state
    if samples.isEmpty then state else
      let current := sampleIndex samples state
      let next := if back then current - amount else min (samples.length - 1) (current + amount)
      {state with
        selected := some next
        selectedDay := (samples[next]?).map (·.day)
        detailScroll := if next == current then state.detailScroll else 0}
  else
    let current := selectedIndex history state
    let next := if back then current - amount else min (history.length - 1) (current + amount)
    {state with
      selected := some next
      selectedDay := (history[next]?).map (·.observedAt)
      detailScroll := if next == current then state.detailScroll else 0}

/-- Existing single-day navigation, over the shared read snapshot only. -/
def moveSelection (state : State) (snapshot : Loam.Tui.Main.Snapshot) (back : Bool) : State :=
  moveBy state snapshot back 1

private def grouped (quanta : Int) : String :=
  Loam.MeasurePresentation.groupDisplayedNumber (toString quanta)

private def paceText (point : Loam.CycleSpendingPaceReview.Snapshot) : String :=
  match point.dailyPaceQuanta? with
  | some quanta => grouped quanta ++ " " ++ point.measure.token ++ "/day"
  | none => "unavailable"

/-- The headline is independent of any historical display-window refusal. -/
private def currentText (snapshot : Loam.Tui.Main.Snapshot) : String :=
  match snapshot.paceCurrent with
  | .loaded point =>
      if point.observedAt == snapshot.actual.today then paceText point
      else "unavailable (stale)"
  | .failed _ => "unavailable (i: cause)"
  | .unavailable => "unavailable"
  | .notRequested => "not requested"

private def changeText (history : List Loam.CycleSpendingPaceReview.Snapshot) (state : State) : String :=
  let index := selectedIndex history state
  if index == 0 then "first point" else
    match history[index]?, history[index - 1]? with
    | some point, some previous =>
        if point.measure != previous.measure then "change unavailable (different Measures)" else
          match point.dailyPaceQuanta?, previous.dailyPaceQuanta? with
          | some current, some prior =>
              let delta := current - prior
              "change " ++ (if delta > 0 then "+" else "") ++ grouped delta ++ " " ++ point.measure.token ++ "/day"
          | _, _ => "change unavailable"
    | _, _ => "previous day unavailable"

private def fitValue (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then text
  else if width ≥ 11 then "see details" else if width > 0 then "…" else ""

private def fitText (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then Loam.Tui.Layout.padRight width text
  else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

private def wrapped (width : Nat) (text : String) (style : Style := .normal) : List Widget :=
  (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun part => .row [span " ", span part style]

/-- Explanation uses the Review algebra, not a TUI-specific financial formula. -/
private def movementDetail (width : Nat)
    (history : List Loam.CycleSpendingPaceReview.Snapshot) (state : State) :
    List Widget :=
  let index := selectedIndex history state
  if index == 0 then [] else
    match history[index - 1]?, history[index]? with
    | some previous, some current =>
        match Loam.DailyPaceChangeReview.compare previous current with
        | .error _ =>
            wrapped width "Day-to-day breakdown unavailable (not adjacent within one cycle)." .muted
        | .ok explanation =>
            let signed (n : Int) := (if n > 0 then "+" else "") ++ grouped n
            wrapped width ("Time passage: " ++ signed explanation.timePassageEffect ++
              " " ++ current.measure.token ++ "/day") .muted ++
            wrapped width ("Free money effect: " ++ signed explanation.freeMoneyEffect ++
              " " ++ current.measure.token ++ "/day") .muted ++
            wrapped width ("Pool balance delta: " ++ signed explanation.poolBalanceChange ++
              " " ++ current.measure.token) .muted ++
            wrapped width ("Scheduled protection release: " ++ signed explanation.protectionRelease ++
              " " ++ current.measure.token) .muted ++
            wrapped width ("Free-through-end delta: " ++ signed explanation.freeThroughEndChange ++
              " " ++ current.measure.token) .muted
    | _, _ => []

private def disclosure (width : Nat) : List Widget :=
  wrapped width "Reconstructed current truth." .muted ++
  wrapped width "no separate daily snapshot is kept." .muted

private def currentDetailLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) : List Widget :=
  match snapshot.paceCurrent with
  | .loaded point =>
      if point.observedAt != snapshot.actual.today then
        wrapped width "Today unavailable: stale current observation" .muted
      else
        wrapped width ("Today: " ++ paceText point) ++
        wrapped width ("Free through cycle end: " ++ grouped point.availableThroughEnd.quanta ++
          " " ++ point.measure.token) ++
        wrapped width ("Protected Scheduled: " ++ grouped point.automaticDeductions.quanta) .muted ++
        wrapped width ("Selected pool: " ++ grouped point.eligiblePool.quanta) .muted ++
        wrapped width ("Remaining days: " ++ toString point.remainingDays) .muted ++
        wrapped width ("Cycle end (exclusive): " ++ point.endExclusive) .muted
  | .failed message =>
      wrapped width "Today unavailable (not zero):" .muted ++ wrapped width message .muted
  | .unavailable => wrapped width "Today unavailable (not zero)" .muted
  | .notRequested => wrapped width "Today not requested" .muted

private def statusLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  match historyState snapshot state with
  | .notRequested => wrapped width "history not requested" .muted
  | .unavailable => wrapped width "history unavailable" .muted
  | .failed message => wrapped width "history unavailable" .muted ++ wrapped width message .muted
  | .loaded _ => wrapped width "no reconstructed Daily Pace points" .muted

/-- Chart's nice-step search is bounded at 24 powers; do not expand enormous tick lists. -/
private def chartValues (history : List Loam.CycleSpendingPaceReview.Snapshot) : Except String (List Int) := do
  let values := history.filterMap (·.dailyPaceQuanta?)
  if values.length != history.length then throw "Chart unavailable: a reconstructed daily pace is missing"
  if !(history.all fun point => point.measure == (history.head?.map (·.measure)).getD point.measure) then
    throw "Chart unavailable: different Measures; review each day separately"
  if !(values.all fun value => value.natAbs ≤ 10 ^ 24) then
    throw "Chart unavailable: values exceed bounded axis; full values in details"
  return values

/-- Partial history has truthful day slots and precise failure causes. -/
private def partialDetailLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot)
    (state : State) (samples : List Loam.DailyPacePeriods.DaySample) : List Widget :=
  let selected := samples[sampleIndex samples state]?
  let known := (samples.filter fun day => day.answer.isOk).length
  let header := wrapped width s!"Supported: {known}/{samples.length} days" .muted
  match selected with
  | none => currentDetailLines width snapshot ++ statusLines width snapshot state ++ disclosure width
  | some sample =>
      let origin := if sample.source == .current then "current admitted truth"
        else "reconstructed from current knowledge, not as-known history"
      let body := match sample.answer with
        | .error message =>
            wrapped width ("Selected " ++ sample.day ++ ": unavailable, not zero") ++
            wrapped width message .muted
        | .ok point =>
            wrapped width ("Selected " ++ sample.day ++ ": " ++ paceText point) ++
            wrapped width ("Origin: " ++ origin) .muted ++
            wrapped width ("Cycle end (exclusive): " ++ point.endExclusive) .muted ++
            wrapped width ("Remaining days: " ++ toString point.remainingDays) .muted ++
            wrapped width ("Pool: " ++ grouped point.eligiblePool.quanta ++ " " ++ point.measure.token) .muted ++
            wrapped width ("Scheduled deductions: " ++ grouped point.automaticDeductions.quanta) .muted ++
            wrapped width ("Available: " ++ grouped point.availableThroughEnd.quanta) .muted
      header ++ body ++ disclosure width

private def fullDetailLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let history := historyFor snapshot state
  let rangeLines := match snapshot.pacePeriods with
    | .loaded periods => match periods.find? (fun period => period.preset == state.period) with
      | some period => wrapped width ("Period: " ++ period.preset.label) .muted ++
          (match period.range with
           | .ok range => wrapped width ("Display: " ++ range.start ++ " through " ++ range.through) .muted
           | .error message => wrapped width message .muted)
      | none => []
    | _ => []
  rangeLines ++ match history[selectedIndex history state]? with
  | none => currentDetailLines width snapshot ++ statusLines width snapshot state ++ disclosure width
  | some point =>
      wrapped width ("Selected " ++ point.observedAt) ++
      wrapped width ("Pace: " ++ paceText point ++
        (if point.observedAt == snapshot.actual.today then "  current" else "")) ++
      wrapped width (changeText history state) .muted ++
      wrapped width ("Cycle end (exclusive): " ++ point.endExclusive) .muted ++
      wrapped width ("Remaining days: " ++ toString point.remainingDays) .muted ++
      wrapped width ("Pool: " ++ grouped point.eligiblePool.quanta ++ " " ++ point.measure.token) .muted ++
      wrapped width ("Scheduled deductions: " ++ grouped point.automaticDeductions.quanta) .muted ++
      wrapped width ("Available: " ++ grouped point.availableThroughEnd.quanta ++ " / remaining days") .muted ++
      (match history.head?, history.getLast? with
       | some first, some last =>
           wrapped width ("From: " ++ first.observedAt) .muted ++
           wrapped width ("Through: " ++ last.observedAt) .muted
       | _, _ => []) ++
      (match chartValues history with
       | .error message => wrapped width message .muted
       | .ok _ => []) ++ disclosure width ++
      movementDetail width history state

private def detailLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let samples := partialSamples snapshot state
  if samples.isEmpty then fullDetailLines width snapshot state
  else partialDetailLines width snapshot state samples

private def footer (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let feedback := match historyState snapshot state with
    | .failed _ =>
        if (partialSamples snapshot state).isEmpty then
          muted " History unavailable; i for full cause."
        else muted " History partial; unknown dates kept as gaps."
    | _ => blank
  let navigation := if state.detailFocused then
      [("j/k", "scroll"), ("v", "view"), ("i/q", "trend"), ("h/l", "day")]
    else if Loam.Tui.Layout.contentWidth bounds ≥ 79 then
      [("h/l", "day"), ("v", "view"), ("i/Enter", "details"), ("q", "back")]
    else [("h/l", "day"), ("v", "view"), ("i", "info"), ("q", "back")]
  let rows := [feedback, Loam.Tui.Layout.shortcutRow navigation " ",
    Loam.Tui.Layout.shortcutRow [("1-5", "period"), ("C-u/d", "page"), ("Home/End", "ends")] " "]
  let capacity := bounds.height - 1
  if rows.length ≤ capacity then rows else if capacity == 0 then [] else
    rows.take (capacity - 1) ++ [muted " … more help; enlarge terminal"]

private structure Geometry where
  width : Nat
  trendWidth : Nat
  trendHeight : Nat
  historyWidth : Nat
  historyHeight : Nat
  detailWidth : Nat
  detailHeight : Nat
  contextRows : Nat
  wide : Bool
  detailOnly : Bool

private def geometry (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Geometry :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let bodyRows := Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds snapshot state).length
  let contextRows := if bodyRows ≥ 5 then 2 else if bodyRows ≥ 4 then 1 else 0
  let panelHeight := bodyRows - contextRows
  let wide := width ≥ 79 && panelHeight ≥ 15
  let lowerHeight := if panelHeight ≥ 15 then max 7 (panelHeight / 2) else 0
  let detailWidth := if wide then min 60 (max 30 (width * 40 / 100)) else width
  let detailHeight := if wide then lowerHeight else if lowerHeight ≥ 12 then 6 else 0
  let historyHeight := if wide then lowerHeight else lowerHeight - detailHeight
  let detailOnly := state.detailFocused && detailHeight == 0
  { width, detailWidth, contextRows, wide, detailOnly
    trendWidth := width
    trendHeight := if detailOnly then 0 else panelHeight - lowerHeight
    historyWidth := if wide then width - 1 - detailWidth else width
    historyHeight := if detailOnly then 0 else historyHeight
    detailHeight := if detailOnly then panelHeight else detailHeight }

private def detailLimit (g : Geometry) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Nat :=
  if g.detailHeight < 3 then 0 else
    Loam.Tui.Scroll.maxOffset (detailLines (g.detailWidth - 2) snapshot state).length (g.detailHeight - 2)

/-- Clamp ephemeral cursor/offsets to this snapshot and live tty, not household facts. -/
def normalizedForBounds (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : State :=
  let history := historyFor snapshot state
  let samples := partialSamples snapshot state
  let state :=
    if !history.isEmpty then
      {state with
        selected := state.selected.map fun index => min index (history.length - 1)
        selectedDay := (history[selectedIndex history state]?).map (·.observedAt)}
    else if !samples.isEmpty then
      {state with
        selected := state.selected.map fun index => min index (samples.length - 1)
        selectedDay := (samples[sampleIndex samples state]?).map (·.day)}
    else state
  {state with detailScroll := min state.detailScroll (detailLimit (geometry bounds snapshot state) snapshot state)}

/-- Visible data rows only: summary, plot, date axis, gap and heading are not page rows. -/
def historyCapacityForBounds (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Nat :=
  (geometry bounds snapshot state).historyHeight - 4

/-- Qualify a common axis without treating missing days as numerical zero. -/
private def qualifiedChartValues (samples : List Loam.DailyPacePeriods.DaySample) :
    Except String (List (Option Int) × List Int) := do
  let known := samples.filterMap fun sample =>
    match sample.answer with
    | .ok point => point.dailyPaceQuanta?.map fun value => (value, point.measure)
    | .error _ => none
  if known.isEmpty then throw "No qualified points in this range"
  let measure := (known.head?).map Prod.snd
  if !(known.all fun entry => some entry.2 == measure) then
    throw "Chart unavailable: different Measures; review each day separately"
  let numbers := known.map Prod.fst
  if !(numbers.all fun value => value.natAbs ≤ 10 ^ 24) then
    throw "Chart unavailable: values exceed bounded axis; full values in details"
  let values := samples.map fun sample =>
    match sample.answer with
    | .ok point => point.dailyPaceQuanta?
    | .error _ => none
  return (values, numbers)

/-- Adjacent valid days may connect only within the same cycle, never over an
unknown day, calendar hole or reset. Neither source changes financial facts. -/
private def qualifiedJoins (samples : List Loam.DailyPacePeriods.DaySample) : List Bool :=
  (samples.zip (samples.drop 1)).map fun (before, after) =>
    match before.answer, after.answer with
    | .ok left, .ok right =>
        left.dailyPaceQuanta?.isSome && right.dailyPaceQuanta?.isSome &&
        left.measure == right.measure &&
        left.endExclusive == right.endExclusive &&
        Loam.ActualDate.shiftDays? before.day 1 == some after.day
    | _, _ => false

private def qualifiedAxisWidth (width : Nat) (numbers : List Int) : Nat :=
  let desired := (Loam.Tui.Chart.scaleFor numbers 4).ticks.foldl
    (fun n tick => max n (Loam.Tui.Layout.displayWidth (grouped tick))) 3
  min desired (max 3 (width / 4))

private def qualifiedChartRows (width height : Nat)
    (samples : List Loam.DailyPacePeriods.DaySample) (state : State) : List Widget :=
  if height == 0 || width < 8 then [] else
    match qualifiedChartValues samples with
    | .error message =>
        let rows := (wrapped width message .muted).take height
        rows ++ List.replicate (height - rows.length) blank
    | .ok (values, numbers) =>
        let scale := Loam.Tui.Chart.scaleFor numbers 4
        let axis := qualifiedAxisWidth width numbers
        let plotWidth := max 1 (width - axis - 3)
        let gridRows := scale.ticks.map fun tick =>
          Loam.Tui.Chart.rowForValue height scale.range tick
        let rendered := Loam.Tui.Chart.renderQualifiedInRange .braille
          plotWidth height values (qualifiedJoins samples) (sampleIndex samples state)
          scale.range (state.graphStyle == .connected) gridRows
        (List.range height).map fun row =>
          let label := match scale.ticks.find? (fun tick =>
              Loam.Tui.Chart.rowForValue height scale.range tick == row) with
            | some tick => Loam.Tui.Layout.padLeft axis
                (if Loam.Tui.Layout.displayWidth (grouped tick) ≤ axis then grouped tick else "…") ++ " ┤ "
            | none => Loam.Tui.Layout.padRight axis "" ++ " │ "
          .row ([span label .muted] ++
            match rendered[row]? with
            | some (.row spans) => spans
            | _ => [])

private def qualifiedDateAxis (width : Nat)
    (samples : List Loam.DailyPacePeriods.DaySample) : Widget :=
  match samples.head?, samples.getLast? with
  | some first, some last =>
      let axis := match qualifiedChartValues samples with
        | .ok (_, numbers) => qualifiedAxisWidth width numbers
        | .error _ => 3
      let left := axis + 3
      let plotWidth := width - left
      if plotWidth ≥ 21 then muted (Loam.Tui.Layout.padRight left "" ++
        Loam.Tui.Layout.padRight (plotWidth - 10) first.day ++ last.day)
      else muted (fitText width (first.day ++ " ... " ++ last.day))
  | _, _ => blank

private def partialSummary (width : Nat)
    (samples : List Loam.DailyPacePeriods.DaySample) (state : State) : List Widget :=
  let known := (samples.filter fun day => day.answer.isOk).length
  let date := (samples[sampleIndex samples state]?).map (·.day) |>.getD "unknown"
  let status := match (samples[sampleIndex samples state]?).map (·.answer) with
    | some (.ok point) => paceText point
    | some (.error _) => "unavailable (not zero)"
    | none => "unavailable"
  [line (" Selected " ++ date ++ "   " ++ fitValue (width - min width 24) status),
   muted s!" {known}/{samples.length} supported days • {state.graphStyle.label}; unknown days stay gaps"]

private def summaryRows (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let history := historyFor snapshot state
  match history[selectedIndex history state]? with
  | none => []
  | some point =>
      let label := " Selected " ++ point.observedAt ++ "   "
      let marker := if point.observedAt == snapshot.actual.today && width ≥ 38 then "  current" else ""
      [line (label ++ fitValue (width - Loam.Tui.Layout.displayWidth (label ++ marker)) (paceText point) ++ marker),
       muted (" " ++ fitValue (width - 1) (changeText history state))]

private def partialHistoryRows (width capacity : Nat)
    (samples : List Loam.DailyPacePeriods.DaySample) (state : State) : List Widget :=
  if capacity == 0 then [] else
    let index := sampleIndex samples state
    let start := Loam.Tui.Layout.trailingWindowStart index capacity
    let dateWidth := min 12 (width - 3)
    let valueWidth := width - 3 - dateWidth
    [blank, muted ("   " ++ fitText dateWidth "Day" ++
      Loam.Tui.Layout.padLeft valueWidth "Value / status")] ++
    (samples.drop start |>.take capacity |>.zipIdx).map fun (sample, offset) =>
      let selected := start + offset == index
      let marker := if selected then " > " else "   "
      let value := match sample.answer with
        | .ok point => paceText point
        | .error _ => "unknown"
      .row [span (marker ++ fitText dateWidth sample.day ++
        Loam.Tui.Layout.padLeft valueWidth (fitValue valueWidth value))
        (if selected then .selected else .normal)]

private def historyRows (width capacity : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let daySamples := partialSamples snapshot state
  if !daySamples.isEmpty then partialHistoryRows width capacity daySamples state
  else if capacity == 0 then [] else
    let history := historyFor snapshot state
    let index := selectedIndex history state
    let start := Loam.Tui.Layout.trailingWindowStart index capacity
    let currentWidth := if width ≥ 39 then 9 else 0
    let dateWidth := min 12 (width - 3)
    let valueWidth := width - 3 - dateWidth - currentWidth
    [blank, muted ("   " ++ fitText dateWidth "Day" ++ Loam.Tui.Layout.padLeft valueWidth "Quanta/day")] ++
    (history.drop start |>.take capacity |>.zipIdx).map fun (point, offset) =>
      let selected := start + offset == index
      let marker := if selected then (if state.detailFocused then " * " else " > ") else "   "
      .row [span (marker ++ fitText dateWidth point.observedAt ++
        Loam.Tui.Layout.padLeft valueWidth (fitValue valueWidth (paceText point)) ++
        (if currentWidth > 0 && point.observedAt == snapshot.actual.today then "  current" else ""))
        (if selected && !state.detailFocused then .selected else .normal)]

private def withoutSelection (widget : Widget) : Widget :=
  .column (widget.lines.map fun cells => .row (cells.map fun cell =>
    Cell.toSpan { cell with style := if cell.style == .selected then .normal else cell.style }))

private def trendPanel (bounds : Bounds) (g : Geometry) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Widget :=
  let history := historyFor snapshot state
  let daySamples := partialSamples snapshot state
  let plotted := graphSamples snapshot state
  let width := g.trendWidth - 2
  let inner := g.trendHeight - 2
  let height := if inner ≥ 6 then inner - 3 else 0
  let capacity := historyCapacityForBounds bounds snapshot state
  let body := if !plotted.isEmpty then
      (if !daySamples.isEmpty then partialSummary width daySamples state
        else summaryRows width snapshot state) ++
      qualifiedChartRows width height plotted state ++
      (if height > 0 then [qualifiedDateAxis width plotted] else [])
    else
      let raw := statusLines width snapshot state ++
        [line (" Today: " ++ currentText snapshot)] ++ disclosure width
      if raw.length ≤ inner then raw else raw.take (inner - 1) ++ [muted " more in details (i)"]
  let index := if daySamples.isEmpty then selectedIndex history state else sampleIndex daySamples state
  let count := if daySamples.isEmpty then history.length else daySamples.length
  let start := Loam.Tui.Layout.trailingWindowStart index (max 1 capacity)
  let position := if count == 0 then "i for details" else s!"{index + 1}/{count}" ++
    (if capacity == 0 then " • list hidden" else
      (if start > 0 then " ↑" else "") ++ (if start + capacity < count then " ↓" else ""))
  Loam.Tui.Layout.framedPanel g.trendWidth g.trendHeight
    ("Trend" ++ (if state.detailFocused then "" else " [active]") ++
      (if g.trendWidth ≥ 38 then " • " ++ state.graphStyle.label else ""))
    (if state.detailFocused then withoutSelection (.column body) else .column body)
    (!state.detailFocused) (some position)

private def detailPanel (g : Geometry) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Widget :=
  let raw := detailLines (g.detailWidth - 2) snapshot state
  let visible := g.detailHeight - 2
  let offset := Loam.Tui.Scroll.clamp raw.length visible state.detailScroll
  let position := s!"{if visible == 0 then 0 else offset + 1}-{min (offset + visible) raw.length}/{raw.length}" ++
    (if offset > 0 then " ↑" else "") ++ (if offset + visible < raw.length then " ↓" else "")
  Loam.Tui.Layout.framedPanel g.detailWidth g.detailHeight
    ("Selected day" ++ (if state.detailFocused then " [active]" else ""))
    (.column ((raw.drop offset).take visible)) state.detailFocused (some position)

private def historyPanel (g : Geometry) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Widget :=
  let history := historyFor snapshot state
  let daySamples := partialSamples snapshot state
  let index := if daySamples.isEmpty then selectedIndex history state else sampleIndex daySamples state
  let count := if daySamples.isEmpty then history.length else daySamples.length
  Loam.Tui.Layout.framedPanel g.historyWidth g.historyHeight "History"
    (.column (historyRows (g.historyWidth - 2) (g.historyHeight - 4) snapshot state))
    (!state.detailFocused) (some s!"{if count == 0 then 0 else index + 1}/{count}")

/-- Keep the selected day when included, otherwise clamp to the nearest endpoint.
Refused periods keep the anchor for a later successful choice. -/
def selectPeriod (snapshot : Loam.Tui.Main.Snapshot) (state : State)
    (period : Loam.DailyPacePeriods.Preset) : State :=
  let date := (sampleDate snapshot state).or state.selectedDay
  let next := {state with period}
  let history := historyFor snapshot next
  let samples := partialSamples snapshot next
  let index := match date with
    | none => none
    | some day =>
        if !history.isEmpty then
          some (min (history.length - 1) (history.takeWhile fun point => decide (point.observedAt < day)).length)
        else if !samples.isEmpty then
          some (min (samples.length - 1) (samples.takeWhile fun sample => decide (sample.day < day)).length)
        else state.selected
  {next with selected := index, selectedDay := date, detailScroll := 0}

/-- Read-only navigation; no reload, setting change or second pace calculation. -/
def update (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (rawState : State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1) : Step :=
  let state := normalizedForBounds bounds snapshot rawState
  let g := geometry bounds snapshot state
  match key with
  | .input 'v' | .input 'V' =>
      .stay {state with graphStyle := state.graphStyle.next}
  | .input '1' | .input '2' | .input '3' | .input '4' | .input '5' =>
      let period := if key == .input '1' then Loam.DailyPacePeriods.Preset.tenDays
        else if key == .input '2' then .thirtyDays else if key == .input '3' then .month
        else if key == .input '4' then .cycle else .previousCycle
      .stay (normalizedForBounds bounds snapshot (selectPeriod snapshot state period))
  | .escape | .input 'q' | .input 'Q' =>
      if state.detailFocused then .stay (normalizedForBounds bounds snapshot {state with detailFocused := false}) else .back
  | .enter | .tab | .shiftTab | .input 'i' | .input 'I' =>
      .stay (normalizedForBounds bounds snapshot {state with detailFocused := !state.detailFocused})
  | .left | .right | .input 'h' | .input 'H' | .input 'l' | .input 'L' =>
      .stay (normalizedForBounds bounds snapshot (moveBy state snapshot
        (key == .left || key == .input 'h' || key == .input 'H') (max 1 repeatCount)))
  | .up | .down | .input 'j' | .input 'J' | .input 'k' | .input 'K' |
    .pageUp | .pageDown | .ctrl 'u' | .ctrl 'd' | .home | .«end» =>
      let forward := key == .down || key == .input 'j' || key == .input 'J' || key == .pageDown || key == .ctrl 'd'
      let page := key == .pageUp || key == .pageDown || key == .ctrl 'u' || key == .ctrl 'd'
      let next := if state.detailFocused then
          let content := (detailLines (g.detailWidth - 2) snapshot state).length
          let visible := g.detailHeight - 2
          let amount := if page then max 1 visible else max 1 repeatCount
          {state with detailScroll := if key == .home then 0 else if key == .«end» then detailLimit g snapshot state
            else if forward then Loam.Tui.Scroll.forward content visible state.detailScroll amount
            else Loam.Tui.Scroll.backward content visible state.detailScroll amount}
        else
          let history := historyFor snapshot state
          let amount := if page then max 1 (historyCapacityForBounds bounds snapshot state) else max 1 repeatCount
          if key == .home || key == .«end» then
            if history.isEmpty then
              let samples := partialSamples snapshot state
              if samples.isEmpty then state else
                let index := if key == .home then 0 else samples.length - 1
                {state with selected := some index, selectedDay := (samples[index]?).map (·.day), detailScroll := 0}
            else
              let index := if key == .home then 0 else history.length - 1
              {state with selected := some index, selectedDay := (history[index]?).map (·.observedAt), detailScroll := 0}
          else moveBy state snapshot (!forward) amount
      .stay (normalizedForBounds bounds snapshot next)
  | _ => .stay state

private def widgetRows (widget : Widget) : List Widget :=
  widget.lines.map fun cells => .row (cells.map Cell.toSpan)

/-- Quiet bounded panes over the existing retrospective current-truth snapshot. -/
def view (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (rawState : State := {}) : Widget :=
  let state := normalizedForBounds bounds snapshot rawState
  let g := geometry bounds snapshot state
  let choices := Loam.DailyPacePeriods.presets.zipIdx |>.map fun (period, index) =>
    let label := if g.width < 70 && period == .previousCycle then "Prev" else period.label
    toString (index + 1) ++ ":" ++ label ++ (if period == state.period then "*" else "")
  let context := if g.contextRows == 1 then
      [line (" Daily: " ++ currentText snapshot)]
    else
      [line (" Daily Pace / Trend • " ++ state.period.label ++ "   [w] what-if"),
       muted (" Today: " ++ currentText snapshot ++
         (if g.width ≥ 85 then "   " ++ String.intercalate " " choices else "   [1-5] period"))]
  let lower := if g.wide then Loam.Tui.Layout.sideBySide g.historyHeight g.historyWidth g.detailWidth
      (historyPanel g snapshot state) (detailPanel g snapshot state) " "
    else widgetRows (historyPanel g snapshot state) ++
      (if g.detailHeight == 0 then [] else widgetRows (detailPanel g snapshot state))
  let panels := if g.detailOnly then widgetRows (detailPanel g snapshot state)
    else widgetRows (trendPanel bounds g snapshot state) ++ lower
  .column ((Loam.Tui.Layout.fitWithFooter bounds (context.take g.contextRows ++ panels) (footer bounds snapshot state)).map fun row =>
    .row ((Loam.Tui.Layout.clipCells g.width row.lines.flatten).map Cell.toSpan))

end Loam.Tui.DailyPaceTrend
