import Loam.LocusTrendCompareReview
import Loam.Tui.Chart
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.LocusTrendComparePane

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Full-screen multi-Locus Trend Compare

Presentation-only comparison of several exact Locus/Measure series over the same
configured historical windows.

Pointer and keyboard navigation select one time window shared by every series.
Series identity is expressed by both a standard ANSI style and a marker glyph so
the chart does not rely on color alone.
-/

structure State where
  snapshot : Option Loam.LocusTrendCompareReview.Snapshot := none
  selected : Nat := 0
  /-- Presentation-only first point in the Day viewport. Cycle/Month always use zero. -/
  viewportStart : Nat := 0
  granularity : Loam.LocusTrendCompareReview.Granularity := .cycle
  renderer : Loam.Tui.Chart.Renderer := .braille
  deriving Repr, DecidableEq

def initial : State := {}

/-- One calendar-month-ish inspection window without inventing aggregation semantics. -/
def dayViewportSize : Nat := 31

def clear (state : State) : State :=
  { state with snapshot := none, selected := 0, viewportStart := 0 }

private def maxDayViewportStart (count : Nat) : Nat :=
  count - min dayViewportSize count

private def viewportStartFor
    (granularity : Loam.LocusTrendCompareReview.Granularity)
    (count selected currentStart : Nat) : Nat :=
  if granularity != .day || count == 0 then
    0
  else
    let size := min dayViewportSize count
    let maxStart := maxDayViewportStart count
    let start := min currentStart maxStart
    if selected < start then
      selected
    else if start + size <= selected then
      min maxStart (selected + 1 - size)
    else
      start

private def selectedAnchor? (state : State) : Option String := do
  let snapshot ← state.snapshot
  let point ← snapshot.selectedWindow? state.selected
  pure point.start

private def indexContainingFrom?
    (anchor : String) :
    List Loam.LocusTrendReview.OverviewPoint → Nat → Option Nat
  | [], _ => none
  | point :: rest, index =>
      if decide (point.start <= anchor && anchor < point.throughExclusive) then
        some index
      else
        indexContainingFrom? anchor rest (index + 1)

def withSnapshot
    (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : State :=
  let fallback := if snapshot.pointCount = 0 then 0 else snapshot.pointCount - 1
  let selected :=
    match selectedAnchor? state, snapshot.series.head? with
    | some anchor, some first =>
        (indexContainingFrom? anchor first.points 0).getD fallback
    | _, _ => fallback
  let viewportStart :=
    viewportStartFor
      snapshot.granularity snapshot.pointCount selected state.viewportStart
  {
    state with
      snapshot := some snapshot
      selected := selected
      viewportStart := viewportStart
      granularity := snapshot.granularity
  }

def changeGranularity (state : State) (finer : Bool) : State :=
  let granularity :=
    if finer then state.granularity.finer else state.granularity.coarser
  { state with
      granularity := granularity
      viewportStart := if granularity == .day then state.viewportStart else 0 }

def moveSelection (state : State) (back : Bool) : State :=
  match state.snapshot with
  | none => state
  | some snapshot =>
      let count := snapshot.pointCount
      if count = 0 then { state with selected := 0 }
      else
        let last := count - 1
        let current := min state.selected last
        let next := if back then current - 1 else min last (current + 1)
        let viewportStart :=
          viewportStartFor state.granularity count next state.viewportStart
        { state with selected := next, viewportStart := viewportStart }

def cycleRenderer (state : State) : State :=
  { state with renderer := state.renderer.next }

def plotLeft : Nat := 11

def plotWidth (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - plotLeft)

private def pointCount (state : State) : Nat :=
  state.snapshot.map (·.pointCount) |>.getD 0

def visibleStart (state : State) : Nat :=
  if state.granularity == .day then
    min state.viewportStart (maxDayViewportStart (pointCount state))
  else
    0

def visibleCount (state : State) : Nat :=
  let count := pointCount state
  if state.granularity == .day then min dayViewportSize count else count

private def visiblePoints
    (state : State)
    (points : List Loam.LocusTrendReview.OverviewPoint) :
    List Loam.LocusTrendReview.OverviewPoint :=
  (points.drop (visibleStart state)).take (visibleCount state)

private def localSelected (state : State) : Nat :=
  state.selected - visibleStart state

def selectColumn (bounds : Bounds) (state : State) (column : Nat) : State :=
  if column < plotLeft then state
  else
    let count := visibleCount state
    if count = 0 then state
    else
      let localIndex :=
        Loam.Tui.Chart.nearestIndex
          (plotWidth bounds) count (column - plotLeft)
      { state with selected := visibleStart state + localIndex }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def seriesStyle (index : Nat) : Style :=
  match index % 3 with
  | 0 => .series1
  | 1 => .series2
  | _ => .series3

private def seriesMarker (index : Nat) : Char :=
  match index % 3 with
  | 0 => '●'
  | 1 => '◆'
  | _ => '▲'

private def commaEveryThreeFromRight : List Char → Nat → List Char
  | [], _ => []
  | char :: rest, count =>
      if count = 3 then
        ',' :: char :: commaEveryThreeFromRight rest 1
      else
        char :: commaEveryThreeFromRight rest (count + 1)

private def groupedNat (value : Nat) : String :=
  let reversed :=
    commaEveryThreeFromRight (toString value).toList.reverse 0
  String.ofList reversed.reverse

private def amountText (value : Int) : String :=
  if value < 0 then "-¥" ++ groupedNat (-value).natAbs
  else "¥" ++ groupedNat value.natAbs

private def monthLabel : String → String
  | "01" => "Jan" | "02" => "Feb" | "03" => "Mar" | "04" => "Apr"
  | "05" => "May" | "06" => "Jun" | "07" => "Jul" | "08" => "Aug"
  | "09" => "Sep" | "10" => "Oct" | "11" => "Nov" | "12" => "Dec"
  | value => value

private def shortDate (date : String) : String :=
  match date.splitOn "-" with
  | [_, month, day] =>
      monthLabel month ++ " " ++
        (day.toNat?.map toString |>.getD day)
  | _ => date

private def longDate (date : String) : String :=
  match date.splitOn "-" with
  | [year, _, _] =>
      shortDate date ++ ", " ++ year
  | _ => date

private def spaces (count : Nat) : String :=
  String.ofList (List.replicate count ' ')

private def centered (width : Nat) (text : String) : String :=
  let clipped := Loam.Tui.Layout.clip width text
  let remaining := width - Loam.Tui.Layout.displayWidth clipped
  let left := remaining / 2
  spaces left ++ clipped ++ spaces (remaining - left)

private def selectedWindow?
    (state : State) : Option Loam.LocusTrendReview.OverviewPoint := do
  let snapshot ← state.snapshot
  snapshot.selectedWindow? state.selected

private def selectedSeriesRows (state : State) : List Widget :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.zipIdx.map fun (series, index) =>
        let value := series.valueAt? state.selected |>.getD 0
        let suffix := if snapshot.granularity == .day then "" else "/day"
        .row
          [ span (String.ofList [seriesMarker index] ++ " " ++ series.spec.label ++ "  ")
              (seriesStyle index)
          , span (amountText value ++ suffix)
          ]

private def isCurrentPartial
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : Bool :=
  !point.complete && snapshot.observedAt < point.throughExclusive

private def periodStatus
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : String :=
  if point.complete then "complete"
  else if isCurrentPartial snapshot point then "current partial"
  else "partial coverage"

private def heading :
    Loam.LocusTrendCompareReview.Granularity → String
  | .cycle => "Trend Compare   cycle average / day"
  | .month => "Trend Compare   month average / day"
  | .day => "Trend Compare   daily amount"

private def sourceLine
    (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : String :=
  match snapshot.granularity with
  | .cycle =>
      snapshot.source ++ " cycles through " ++ longDate snapshot.observedAt
  | .month =>
      "Calendar months from " ++ snapshot.source ++ " history through " ++
        longDate snapshot.observedAt
  | .day =>
      "Calendar days from " ++ snapshot.source ++ " history through " ++
        longDate snapshot.observedAt ++
        "   ·   " ++ toString (visibleCount state) ++ "-day viewport"

private def selectedLine
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : String :=
  match snapshot.granularity with
  | .day =>
      "Selected   " ++ longDate point.start ++
        (if isCurrentPartial snapshot point then "   ·   current day" else "")
  | _ =>
      let endLabel :=
        if isCurrentPartial snapshot point then snapshot.observedAt
        else point.endExclusive
      "Selected   " ++ shortDate point.start ++ " → " ++
        shortDate endLabel ++ "   ·   " ++ periodStatus snapshot point

private def header (state : State) : List Widget :=
  match state.snapshot, selectedWindow? state with
  | some snapshot, some point =>
      [ line (heading snapshot.granularity)
      , muted
          (sourceLine state snapshot ++
            "   ·   jpy   ·   " ++ state.renderer.label ++
            "   ·   " ++ snapshot.granularity.label)
      , line (selectedLine snapshot point)
      ] ++ selectedSeriesRows state ++
      [ muted "Exact Locus series; no alias, description, or historical reclassification is inferred." ]
  | _, _ =>
      [ line ("Trend Compare   " ++ state.granularity.label)
      , muted "Multi-series history unavailable."
      ]

private def allValues (state : State) : List Int :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.flatMap fun series =>
        (visiblePoints state series.points).map (·.dailyAverageQuanta)

private def plotSeries (state : State) : List Loam.Tui.Chart.PlotSeries :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.zipIdx.map fun (series, index) =>
        {
          values := (visiblePoints state series.points).map (·.dailyAverageQuanta)
          style := seriesStyle index
          marker := seriesMarker index
        }

private def chartScale (state : State) : Loam.Tui.Chart.Scale :=
  Loam.Tui.Chart.scaleFor (allValues state) 4

private def tickForRow?
    (height row : Nat) (scale : Loam.Tui.Chart.Scale) : Option Int :=
  scale.ticks.find? fun tick =>
    Loam.Tui.Chart.rowForValue height scale.range tick = row

private def axisText
    (height row : Nat) (scale : Loam.Tui.Chart.Scale) : String :=
  match tickForRow? height row scale with
  | some tick =>
      Loam.Tui.Layout.padLeft 8 (amountText tick) ++ " ┤ "
  | none => "         │ "

private def footerTokens : List String :=
  ["←/→ or wheel select period", "mouse click/drag scrub", "[ / ] granularity",
   "r renderer", "q/Esc Reports"]

private def footer (bounds : Bounds) : List Widget :=
  (Loam.Tui.Layout.flowTokens
      (Loam.Tui.Layout.contentWidth bounds) "   " footerTokens).map muted

private def headerLineCount (state : State) : Nat :=
  (header state).length

private def axisLineCount : Nat := 1

def plotTop (state : State) : Nat :=
  headerLineCount state

def plotHeight (bounds : Bounds) (state : State) : Nat :=
  let fixedRows := headerLineCount state + axisLineCount + (footer bounds).length
  if bounds.height > fixedRows then bounds.height - fixedRows else 1

def pointerInPlot (bounds : Bounds) (state : State) (row : Nat) : Bool :=
  decide (plotTop state <= row && row < plotTop state + plotHeight bounds state)

private def chartRows (bounds : Bounds) (state : State) : List Widget :=
  let width := plotWidth bounds
  let height := plotHeight bounds state
  let scale := chartScale state
  let gridRows :=
    scale.ticks.map fun tick =>
      Loam.Tui.Chart.rowForValue height scale.range tick
  let rendered :=
    Loam.Tui.Chart.renderManyInRange
      state.renderer width height (plotSeries state) (localSelected state)
      scale.range gridRows
  (List.range height).map fun row =>
    match rendered[row]? with
    | some widget =>
        match widget with
        | Widget.row spans =>
            Widget.row ([span (axisText height row scale)] ++ spans)
        | Widget.column _ => Widget.row [span (axisText height row scale)]
    | none => Widget.row [span (axisText height row scale)]

private def compactAxisRow
    (bounds : Bounds)
    (first : Loam.LocusTrendReview.OverviewPoint)
    (last : Loam.LocusTrendReview.OverviewPoint) : Widget :=
  let width := plotWidth bounds
  let text := shortDate first.start ++ "   …   " ++ shortDate last.start
  .row [span (spaces plotLeft), span (centered width text) .muted]

private def axisRow
    (bounds : Bounds) (state : State) : Widget :=
  match state.snapshot with
  | none => muted ""
  | some snapshot =>
      match snapshot.series.head? with
      | none => muted ""
      | some first =>
          let width := plotWidth bounds
          let points := visiblePoints state first.points
          let count := points.length
          match points.head?, points.getLast? with
          | some firstPoint, some lastPoint =>
              if snapshot.granularity == .day ||
                  (count > 0 && width / count < 8) then
                compactAxisRow bounds firstPoint lastPoint
              else
                let chunk := if count = 0 then width else max 1 (width / count)
                let labels := first.points.map fun point =>
                  let endLabel :=
                    if isCurrentPartial snapshot point then snapshot.observedAt
                    else point.endExclusive
                  centered chunk (shortDate point.start ++ " → " ++ shortDate endLabel)
                .row ([span (spaces plotLeft)] ++ labels.map fun text => span text .muted)
          | _, _ => muted ""

/-- Render the comparison as a dedicated full-screen chart. -/
def viewFullScreen
    (bounds : Bounds) (state : State) (notice : String := "") : Widget :=
  let rows :=
    header state ++ chartRows bounds state ++ [axisRow bounds state] ++
      footer bounds ++ (if notice.isEmpty then [] else [line notice])
  .column (rows.take bounds.height)

end Loam.Tui.LocusTrendComparePane
