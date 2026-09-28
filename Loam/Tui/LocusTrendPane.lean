import Loam.LocusTrendReview
import Loam.Tui.Chart
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.LocusTrendPane

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Full-screen Locus Trend presentation

The Trend surface has three presentation levels:

* `overview`: configured adjacent household windows across long history;
* `history`: one calendar point per day from the first configured boundary;
* `detail`: one selected cycle at daily granularity.

Both keyboard and pointer selection update one presentation cursor. The renderer
owns only terminal geometry and never changes household authority or trend
semantics.
-/

inductive View where
  | overview
  | history
  | detail
  deriving Repr, DecidableEq

structure State where
  view : View := .overview
  overview : Option Loam.LocusTrendReview.OverviewSnapshot := none
  history : Option Loam.LocusTrendReview.Snapshot := none
  snapshot : Option Loam.LocusTrendReview.Snapshot := none
  selected : Nat := 0
  overviewSelected : Nat := 0
  historySelected : Nat := 0
  renderer : Loam.Tui.Chart.Renderer := .braille
  deriving Repr, DecidableEq

def initial : State := {}

def clear (state : State) : State :=
  { state with
      view := .overview
      overview := none
      history := none
      snapshot := none
      selected := 0
      overviewSelected := 0
      historySelected := 0 }

def withOverview
    (state : State) (snapshot : Loam.LocusTrendReview.OverviewSnapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with
      view := .overview
      overview := some snapshot
      snapshot := none
      selected := selected
      overviewSelected := selected }

def withHistory
    (state : State) (snapshot : Loam.LocusTrendReview.Snapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with
      view := .history
      history := some snapshot
      selected := selected
      historySelected := selected }

def withSnapshot
    (state : State) (snapshot : Loam.LocusTrendReview.Snapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with view := .detail, snapshot := some snapshot, selected := selected }

def backToOverview (state : State) : State :=
  { state with view := .overview, selected := state.overviewSelected }

def isOverview (state : State) : Bool :=
  state.view == .overview

def isHistory (state : State) : Bool :=
  state.view == .history

def backToHistory (state : State) : State :=
  { state with view := .history, selected := state.historySelected }

def cycleRenderer (state : State) : State :=
  { state with renderer := state.renderer.next }


private def pointCount (state : State) : Nat :=
  match state.view with
  | .overview => state.overview.map (·.points.length) |>.getD 0
  | .history => state.history.map (·.points.length) |>.getD 0
  | .detail => state.snapshot.map (·.points.length) |>.getD 0

def moveSelection (state : State) (back : Bool) : State :=
  let count := pointCount state
  if count = 0 then
    { state with selected := 0 }
  else
    let last := count - 1
    let current := min state.selected last
    let next := if back then current - 1 else min last (current + 1)
    match state.view with
    | .overview =>
        { state with selected := next, overviewSelected := next }
    | .history =>
        { state with selected := next, historySelected := next }
    | .detail => { state with selected := next }

def selectedOverviewPoint?
    (state : State) : Option Loam.LocusTrendReview.OverviewPoint := do
  let snapshot ← state.overview
  snapshot.points[state.selected]?

def selectedHistoryPoint? (state : State) : Option Loam.LocusTrendReview.Point := do
  let snapshot ← state.history
  snapshot.points[state.selected]?

def selectedPoint? (state : State) : Option Loam.LocusTrendReview.Point := do
  let snapshot ← state.snapshot
  snapshot.points[state.selected]?

private def selectedDailyPoint? (state : State) : Option Loam.LocusTrendReview.Point :=
  match state.view with
  | .history => selectedHistoryPoint? state
  | .detail => selectedPoint? state
  | .overview => none

/-- Fixed terminal column where chart data begins after the amount axis. -/
def plotLeft : Nat := 11

/-- Fixed compact header rows before the full-screen chart body. -/
def plotTop : Nat := 5

def plotWidth (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - plotLeft)

private def navigationTokens (state : State) : List String :=
  match state.view with
  | .overview =>
      ["←/→ select cycle", "Enter cycle daily", "d all-days", "mouse hover select",
        "r renderer", "q/Esc reports"]
  | .history =>
      ["←/→ select day", "d cycle overview", "mouse hover select",
        "r renderer", "q/Esc overview"]
  | .detail =>
      ["←/→ select day", "d all-days", "mouse hover select",
        "r renderer", "q/Esc overview"]

private def navigationLineCount (bounds : Bounds) (state : State) : Nat :=
  (Loam.Tui.Layout.flowTokens
      (Loam.Tui.Layout.contentWidth bounds) "   "
      (navigationTokens state)).length

/--
Give the chart all remaining rows after the fixed five-line header, two axis
rows, and the *actual wrapped* navigation footer.

This keeps back navigation visible when a narrow terminal wraps one more footer
line after new Trend actions are added.
-/
def plotHeight (bounds : Bounds) (state : State) : Nat :=
  let fixedRows := plotTop + 2 + navigationLineCount bounds state
  if bounds.height > fixedRows then bounds.height - fixedRows else 1

/--
Select the chart point nearest one physical pointer column.

The caller checks the pointer row against the visible chart rectangle. This
keeps the geometry reusable for click and later pointer-motion tracking.
-/
def selectColumn (bounds : Bounds) (state : State) (column : Nat) : State :=
  if column < plotLeft then state
  else
    let count := pointCount state
    if count = 0 then state
    else
      let next := Loam.Tui.Chart.nearestIndex
        (plotWidth bounds) count (column - plotLeft)
      match state.view with
      | .overview =>
          { state with selected := next, overviewSelected := next }
      | .history =>
          { state with selected := next, historySelected := next }
      | .detail => { state with selected := next }

def pointerInPlot (bounds : Bounds) (state : State) (row : Nat) : Bool :=
  decide (plotTop <= row && row < plotTop + plotHeight bounds state)

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

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

private def groupedInt (value : Int) : String :=
  if value < 0 then "-" ++ groupedNat (-value).natAbs
  else groupedNat value.natAbs

private def measureToken (state : State) : String :=
  match state.view with
  | .overview =>
      state.overview.map (·.coordinate.measure.token) |>.getD ""
  | .history =>
      state.history.map (·.coordinate.measure.token) |>.getD ""
  | .detail =>
      state.snapshot.map (·.coordinate.measure.token) |>.getD ""

private def amountText (state : State) (value : Int) : String :=
  let token := measureToken state
  if token == "jpy" then
    if value < 0 then "-¥" ++ groupedNat (-value).natAbs
    else "¥" ++ groupedNat value.natAbs
  else
    groupedInt value ++ (if token.isEmpty then "" else " " ++ token)

private def spaces (count : Nat) : String :=
  String.ofList (List.replicate count ' ')

private def centered (width : Nat) (text : String) : String :=
  let clipped := Loam.Tui.Layout.clip width text
  let remaining := width - Loam.Tui.Layout.displayWidth clipped
  let left := remaining / 2
  spaces left ++ clipped ++ spaces (remaining - left)

private def monthLabel : String → String
  | "01" => "Jan"
  | "02" => "Feb"
  | "03" => "Mar"
  | "04" => "Apr"
  | "05" => "May"
  | "06" => "Jun"
  | "07" => "Jul"
  | "08" => "Aug"
  | "09" => "Sep"
  | "10" => "Oct"
  | "11" => "Nov"
  | "12" => "Dec"
  | value => value

private def shortDate (date : String) : String :=
  match date.splitOn "-" with
  | [_, month, day] =>
      monthLabel month ++ " " ++
        (day.toNat?.map toString |>.getD day)
  | _ => date

private def longDate (date : String) : String :=
  match date.splitOn "-" with
  | [year, month, day] =>
      monthLabel month ++ " " ++
        (day.toNat?.map toString |>.getD day) ++ ", " ++ year
  | _ => date

private def values (state : State) : List Int :=
  match state.view with
  | .overview =>
      state.overview.map (fun snapshot =>
        snapshot.points.map (·.dailyAverageQuanta)) |>.getD []
  | .history =>
      state.history.map (fun snapshot =>
        snapshot.points.map (·.daily.quanta)) |>.getD []
  | .detail =>
      state.snapshot.map (fun snapshot =>
        snapshot.points.map (·.daily.quanta)) |>.getD []

private def chartScale (state : State) : Loam.Tui.Chart.Scale :=
  Loam.Tui.Chart.scaleFor (values state)
    (if state.view = .overview then 3 else 4)

private def tickForRow?
    (height row : Nat) (scale : Loam.Tui.Chart.Scale) : Option Int :=
  scale.ticks.find? fun tick =>
    Loam.Tui.Chart.rowForValue height scale.range tick = row

private def axisText
    (state : State) (height row : Nat)
    (scale : Loam.Tui.Chart.Scale) : String :=
  match tickForRow? height row scale with
  | some tick =>
      Loam.Tui.Layout.padLeft 8 (amountText state tick) ++ " ┤ "
  | none => "         │ "

private def observedMarkers (state : State) : List Loam.Tui.Chart.Marker :=
  match state.view with
  | .overview =>
      state.overview.map (fun snapshot =>
        snapshot.points.zipIdx.map fun (point, index) =>
          {
            index := index
            kind := if point.complete then
              Loam.Tui.Chart.MarkerKind.observed
            else
              Loam.Tui.Chart.MarkerKind.incomplete
          }) |>.getD []
  | .history | .detail => []

private def chartRows
    (bounds : Bounds) (state : State) : List Widget :=
  let width := plotWidth bounds
  let height := plotHeight bounds state
  let series := values state
  let scale := chartScale state
  let gridRows :=
    scale.ticks.map fun tick =>
      Loam.Tui.Chart.rowForValue height scale.range tick
  let rendered :=
    Loam.Tui.Chart.renderInRange
      state.renderer width height series state.selected
      scale.range (observedMarkers state) gridRows
  (List.range height).map fun row =>
    match rendered[row]? with
    | some widget =>
        match widget with
        | Widget.row spans =>
            Widget.row ([span (axisText state height row scale)] ++ spans)
        | Widget.column _ =>
            Widget.row [span (axisText state height row scale)]
    | none =>
        Widget.row [span (axisText state height row scale)]


private def overviewAxisRows
    (bounds : Bounds) (state : State)
    (snapshot : Loam.LocusTrendReview.OverviewSnapshot) : List Widget :=
  let count := snapshot.points.length
  let width := plotWidth bounds
  let chunk := if count = 0 then width else max 1 (width / count)
  let dateLabels := snapshot.points.map fun point =>
    let endLabel :=
      if point.complete then point.endExclusive else snapshot.observedAt
    centered chunk (shortDate point.start ++ " → " ++ shortDate endLabel)
  let valueLabels := snapshot.points.map fun point =>
    let marker := if point.complete then "● " else "◇ "
    let partialSuffix := if point.complete then "" else " partial"
    centered chunk
      (marker ++ amountText state point.dailyAverageQuanta ++ "/day" ++ partialSuffix)
  [ .row ([span (spaces plotLeft)] ++ dateLabels.map fun text => span text .muted)
  , .row ([span (spaces plotLeft)] ++ valueLabels.map span)
  ]


private def dailyAxis
    (bounds : Bounds) (state : State)
    (snapshot : Loam.LocusTrendReview.Snapshot) : Widget :=
  let selected := (selectedDailyPoint? state).map (·.date) |>.getD snapshot.start
  let last :=
    snapshot.points.getLast?.map (·.date) |>.getD snapshot.start
  let width := plotWidth bounds
  let third := max 1 (width / 3)
  .row
    [ span (spaces plotLeft)
    , span (Loam.Tui.Layout.padRight third (shortDate snapshot.start)) .muted
    , span (centered third (shortDate selected)) .selected
    , span
        (Loam.Tui.Layout.padLeft
          (width - min width (third * 2)) (shortDate last)) .muted
    ]

private def header (state : State) : List Widget :=
  match state.view with
  | .overview =>
      match state.overview, selectedOverviewPoint? state with
      | some snapshot, some point =>
          let endLabel :=
            if point.complete then point.endExclusive else snapshot.observedAt
          let status := if point.complete then "● complete" else "◇ current partial"
          [ line
              ("Locus Trend   " ++ snapshot.coordinate.locus.token ++
                " / " ++ snapshot.coordinate.measure.token)
          , muted
              (snapshot.source ++ " cycles   ·   through " ++
                longDate snapshot.observedAt ++ "   ·   " ++ state.renderer.label)
          , line
              ("Selected   " ++ shortDate point.start ++ " → " ++
                shortDate endLabel ++ "   " ++ status)
          , line
              (amountText state point.dailyAverageQuanta ++ "/day   ·   " ++
                amountText state point.total.quanta ++ " total   ·   " ++
                toString point.observedDays ++ " days")
          , muted "● completed cycle   ◇ current partial   ·   line connects observed cycle values"
          ]
      | _, _ =>
          [ line "Locus Trend"
          , muted "Long-history overview unavailable."
          , blank, blank, blank
          ]
  | .history =>
      match state.history, selectedHistoryPoint? state with
      | some snapshot, some point =>
          let last :=
            snapshot.points.getLast?.map (·.date) |>.getD snapshot.start
          [ line
              ("Locus Trend / Daily History   " ++ snapshot.coordinate.locus.token ++
                " / " ++ snapshot.coordinate.measure.token)
          , muted
              (shortDate snapshot.start ++ " → " ++ shortDate last ++
                "   ·   " ++ state.renderer.label)
          , line
              ("Selected   " ++ shortDate point.date ++
                "   ·   " ++ amountText state point.daily.quanta)
          , line
              ("Since " ++ shortDate snapshot.start ++ "   ·   " ++
                amountText state point.cumulative.quanta ++
                " cumulative   ·   " ++
                amountText state point.runningDailyAverageQuanta ++ "/day avg")
          , muted "One point per calendar day   ·   zero-quantity days retained"
          ]
      | _, _ =>
          [ line "Locus Trend / Daily History"
          , muted "Long daily history unavailable."
          , blank, blank, blank
          ]
  | .detail =>
      match state.snapshot, selectedPoint? state with
      | some snapshot, some point =>
          [ line
              ("Locus Trend / Daily   " ++ snapshot.coordinate.locus.token ++
                " / " ++ snapshot.coordinate.measure.token)
          , muted
              (shortDate snapshot.start ++ " → " ++ shortDate snapshot.endExclusive ++
                "   ·   " ++ state.renderer.label)
          , line
              ("Selected   " ++ shortDate point.date ++
                "   ·   " ++ amountText state point.daily.quanta)
          , line
              ("Cumulative " ++ amountText state point.cumulative.quanta ++
                "   ·   running avg " ++
                amountText state point.runningDailyAverageQuanta ++ "/day")
          , muted "Current admitted truth   ·   corrected originals excluded"
          ]
      | _, _ =>
          [ line "Locus Trend / Daily"
          , muted "Daily detail unavailable."
          , blank, blank, blank
          ]

private def footer (bounds : Bounds) (state : State) : List Widget :=
  (Loam.Tui.Layout.flowTokens
      (Loam.Tui.Layout.contentWidth bounds) "   "
      (navigationTokens state)).map muted

/--
Render Trend as a dedicated full-screen chart instead of the ordinary Reports
scrolling body. The chart consumes every row left after its fixed context and
navigation lines.
-/
def viewFullScreen (bounds : Bounds) (state : State) (notice : String := "") : Widget :=
  let chart := chartRows bounds state
  let axisRows :=
    match state.view with
    | .overview =>
        match state.overview with
        | some snapshot => overviewAxisRows bounds state snapshot
        | none => [muted "", muted ""]
    | .history =>
        match state.history with
        | some snapshot => [dailyAxis bounds state snapshot, muted ""]
        | none => [muted "", muted ""]
    | .detail =>
        match state.snapshot with
        | some snapshot => [dailyAxis bounds state snapshot, muted ""]
        | none => [muted "", muted ""]
  let all :=
    header state ++ chart ++ axisRows ++ footer bounds state ++
      (if notice.isEmpty then [] else [line notice])
  .column (all.take bounds.height)

end Loam.Tui.LocusTrendPane
