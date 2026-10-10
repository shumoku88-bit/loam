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

structure State where
  /-- `none` follows the most recent reconstructed day on first entry. -/
  selected : Option Nat := none
  period : Loam.DailyPacePeriods.Preset := .tenDays
  /-- Date anchor survives a refused period; index is only an in-period cursor. -/
  selectedDay : Option String := none
  detailFocused : Bool := false
  detailScroll : Nat := 0
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

private def moveBy (state : State) (snapshot : Loam.Tui.Main.Snapshot) (back : Bool) (amount : Nat) : State :=
  let history := historyFor snapshot state
  if history.isEmpty then state else
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

private def disclosure (width : Nat) : List Widget :=
  wrapped width "Reconstructed current truth." .muted ++
  wrapped width "no separate daily snapshot is kept." .muted

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

private def detailLines (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
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
  | none => statusLines width snapshot state ++ disclosure width
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
       | .ok _ => []) ++ disclosure width

private def footer (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let feedback := match historyState snapshot state with
    | .failed _ => muted " History unavailable; i for full cause."
    | _ => blank
  let navigation := if state.detailFocused then
      [("j/k", "scroll"), ("i/q", "trend"), ("h/l", "day")]
    else if Loam.Tui.Layout.contentWidth bounds ≥ 79 then
      [("h/l", "day"), ("i/Enter", "details"), ("q", "back")]
    else [("h/l", "day"), ("i/Enter", "info"), ("q", "back")]
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
  let state := if history.isEmpty then state else
    {state with
      selected := state.selected.map fun index => min index (history.length - 1)
      selectedDay := (history[selectedIndex history state]?).map (·.observedAt)}
  {state with detailScroll := min state.detailScroll (detailLimit (geometry bounds snapshot state) snapshot state)}

/-- Visible data rows only: summary, plot, date axis, gap and heading are not page rows. -/
def historyCapacityForBounds (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Nat :=
  (geometry bounds snapshot state).historyHeight - 4

private def axisWidth (width : Nat) (history : List Loam.CycleSpendingPaceReview.Snapshot) : Nat :=
  let desired := match chartValues history with
    | .error _ => 3
    | .ok values => (Loam.Tui.Chart.scaleFor values 4).ticks.foldl
        (fun n tick => max n (Loam.Tui.Layout.displayWidth (grouped tick))) 3
  min desired (max 3 (width / 4))

private def chartRows (width height : Nat) (history : List Loam.CycleSpendingPaceReview.Snapshot)
    (state : State) : List Widget :=
  if height == 0 || width < 8 then [] else
    match chartValues history with
    | .error message =>
        let rows := (wrapped width message .muted).take height
        rows ++ List.replicate (height - rows.length) blank
    | .ok values =>
        let scale := Loam.Tui.Chart.scaleFor values 4
        let axis := axisWidth width history
        let plotWidth := max 1 (width - axis - 3)
        let gridRows := scale.ticks.map fun tick => Loam.Tui.Chart.rowForValue height scale.range tick
        let rendered := Loam.Tui.Chart.renderInRange .braille plotWidth height values
          (selectedIndex history state) scale.range [] gridRows
        (List.range height).map fun row =>
          let label := match scale.ticks.find? (fun tick => Loam.Tui.Chart.rowForValue height scale.range tick == row) with
            | some tick => Loam.Tui.Layout.padLeft axis
                (if Loam.Tui.Layout.displayWidth (grouped tick) ≤ axis then grouped tick else "…") ++ " ┤ "
            | none => Loam.Tui.Layout.padRight axis "" ++ " │ "
          .row ([span label .muted] ++
            match rendered[row]? with
            | some (.row spans) => spans
            | _ => [])

private def dateAxis (width : Nat) (history : List Loam.CycleSpendingPaceReview.Snapshot) : Widget :=
  match history.head?, history.getLast? with
  | some first, some last =>
      let left := axisWidth width history + 3
      let plotWidth := width - left
      if plotWidth ≥ 21 then muted (Loam.Tui.Layout.padRight left "" ++
        Loam.Tui.Layout.padRight (plotWidth - 10) first.observedAt ++ last.observedAt)
      else muted (fitText width "range in details")
  | _, _ => blank

private def summaryRows (width : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  let history := historyFor snapshot state
  match history[selectedIndex history state]? with
  | none => []
  | some point =>
      let label := " Selected " ++ point.observedAt ++ "   "
      let marker := if point.observedAt == snapshot.actual.today && width ≥ 38 then "  current" else ""
      [line (label ++ fitValue (width - Loam.Tui.Layout.displayWidth (label ++ marker)) (paceText point) ++ marker),
       muted (" " ++ fitValue (width - 1) (changeText history state))]

private def historyRows (width capacity : Nat) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : List Widget :=
  if capacity == 0 then [] else
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
    span (String.singleton cell.glyph) (if cell.style == .selected then .normal else cell.style)))

private def trendPanel (bounds : Bounds) (g : Geometry) (snapshot : Loam.Tui.Main.Snapshot) (state : State) : Widget :=
  let history := historyFor snapshot state
  let width := g.trendWidth - 2
  let inner := g.trendHeight - 2
  let height := if inner ≥ 6 then inner - 3 else 0
  let capacity := historyCapacityForBounds bounds snapshot state
  let body := if history.isEmpty then
      let raw := statusLines width snapshot state ++ disclosure width
      if raw.length ≤ inner then raw else raw.take (inner - 1) ++ [muted " more in details (i)"]
    else summaryRows width snapshot state ++ chartRows width height history state ++
      (if height > 0 then [dateAxis width history] else [])
  let index := selectedIndex history state
  let start := Loam.Tui.Layout.trailingWindowStart index (max 1 capacity)
  let position := if history.isEmpty then "i for details" else s!"{index + 1}/{history.length}" ++
    (if capacity == 0 then " • list hidden" else
      (if start > 0 then " ↑" else "") ++ (if start + capacity < history.length then " ↓" else ""))
  Loam.Tui.Layout.framedPanel g.trendWidth g.trendHeight
    ("Trend" ++ (if state.detailFocused then "" else " [active]"))
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
  let index := selectedIndex history state
  Loam.Tui.Layout.framedPanel g.historyWidth g.historyHeight "History"
    (.column (historyRows (g.historyWidth - 2) (g.historyHeight - 4) snapshot state))
    (!state.detailFocused) (some s!"{if history.isEmpty then 0 else index + 1}/{history.length}")

/-- Keep the selected day when included, otherwise clamp to the nearest endpoint.
Refused periods keep the anchor for a later successful choice. -/
def selectPeriod (snapshot : Loam.Tui.Main.Snapshot) (state : State)
    (period : Loam.DailyPacePeriods.Preset) : State :=
  let old := historyFor snapshot state
  let date := ((old[selectedIndex old state]?).map (·.observedAt)).or state.selectedDay
  let next := {state with period}
  let history := historyFor snapshot next
  let index := match date with
    | none => none
    | some day =>
        if history.isEmpty then state.selected else
          some (min (history.length - 1) (history.takeWhile fun point => decide (point.observedAt < day)).length)
  {next with selected := index, selectedDay := date, detailScroll := 0}

/-- Read-only navigation; no reload, setting change or second pace calculation. -/
def update (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (rawState : State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1) : Step :=
  let state := normalizedForBounds bounds snapshot rawState
  let g := geometry bounds snapshot state
  match key with
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
            if history.isEmpty then state else
              let index := if key == .home then 0 else history.length - 1
              {state with selected := some index, selectedDay := (history[index]?).map (·.observedAt), detailScroll := 0}
          else moveBy state snapshot (!forward) amount
      .stay (normalizedForBounds bounds snapshot next)
  | _ => .stay state

private def widgetRows (widget : Widget) : List Widget :=
  widget.lines.map fun cells => .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

/-- Quiet bounded panes over the existing retrospective current-truth snapshot. -/
def view (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) (rawState : State := {}) : Widget :=
  let state := normalizedForBounds bounds snapshot rawState
  let g := geometry bounds snapshot state
  let choices := Loam.DailyPacePeriods.presets.zipIdx |>.map fun (period, index) =>
    let label := if g.width < 70 && period == .previousCycle then "Prev" else period.label
    toString (index + 1) ++ ":" ++ label ++ (if period == state.period then "*" else "")
  let context := [line (" Daily Pace / Trend • " ++ state.period.label),
    muted (" " ++ String.intercalate " " choices)]
  let lower := if g.wide then Loam.Tui.Layout.sideBySide g.historyHeight g.historyWidth g.detailWidth
      (historyPanel g snapshot state) (detailPanel g snapshot state) " "
    else widgetRows (historyPanel g snapshot state) ++
      (if g.detailHeight == 0 then [] else widgetRows (detailPanel g snapshot state))
  let panels := if g.detailOnly then widgetRows (detailPanel g snapshot state)
    else widgetRows (trendPanel bounds g snapshot state) ++ lower
  .column ((Loam.Tui.Layout.fitWithFooter bounds (context.take g.contextRows ++ panels) (footer bounds snapshot state)).map fun row =>
    .row ((Loam.Tui.Layout.clipCells g.width row.lines.flatten).map fun cell => span (String.singleton cell.glyph) cell.style))

end Loam.Tui.DailyPaceTrend
