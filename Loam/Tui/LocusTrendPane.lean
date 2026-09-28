import Loam.LocusTrendReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.LocusTrendPane

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Full-screen Locus Trend presentation

The Trend surface has two presentation levels:

* `overview`: configured adjacent household windows across long history;
* `detail`: one selected window at daily granularity.

Both keyboard and pointer selection update one presentation cursor. The renderer
owns only terminal geometry and never changes household authority or trend
semantics.
-/

inductive View where
  | overview
  | detail
  deriving Repr, DecidableEq

structure State where
  view : View := .overview
  overview : Option Loam.LocusTrendReview.OverviewSnapshot := none
  snapshot : Option Loam.LocusTrendReview.Snapshot := none
  selected : Nat := 0
  overviewSelected : Nat := 0
  deriving Repr, DecidableEq

def initial : State := {}

def clear (state : State) : State :=
  { state with
      view := .overview
      overview := none
      snapshot := none
      selected := 0
      overviewSelected := 0 }

def withOverview
    (state : State) (snapshot : Loam.LocusTrendReview.OverviewSnapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with
      view := .overview
      overview := some snapshot
      snapshot := none
      selected := selected
      overviewSelected := selected }

def withSnapshot
    (state : State) (snapshot : Loam.LocusTrendReview.Snapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with view := .detail, snapshot := some snapshot, selected := selected }

def backToOverview (state : State) : State :=
  { state with view := .overview, selected := state.overviewSelected }

def isOverview (state : State) : Bool :=
  state.view == .overview

private def pointCount (state : State) : Nat :=
  match state.view with
  | .overview => state.overview.map (·.points.length) |>.getD 0
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
    | .detail => { state with selected := next }

def selectedOverviewPoint?
    (state : State) : Option Loam.LocusTrendReview.OverviewPoint := do
  let snapshot ← state.overview
  snapshot.points[state.selected]?

def selectedPoint? (state : State) : Option Loam.LocusTrendReview.Point := do
  let snapshot ← state.snapshot
  snapshot.points[state.selected]?

/-- Fixed terminal column where chart data begins after the amount axis. -/
def plotLeft : Nat := 11

/-- Header rows before the first chart row in the full-screen Trend surface. -/
def plotTop : Nat := 7

def plotWidth (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - plotLeft)

def plotHeight (bounds : Bounds) : Nat :=
  if bounds.height > 11 then bounds.height - 11 else 3

private def xForIndex (width count index : Nat) : Nat :=
  if width <= 1 || count <= 1 then 0
  else min (width - 1) (index * (width - 1) / (count - 1))

private def nearestIndex (width count column : Nat) : Nat :=
  if width <= 1 || count <= 1 then 0
  else
    let x := min (width - 1) column
    min (count - 1)
      ((x * (count - 1) + (width - 1) / 2) / (width - 1))

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
      let next := nearestIndex (plotWidth bounds) count (column - plotLeft)
      match state.view with
      | .overview =>
          { state with selected := next, overviewSelected := next }
      | .detail => { state with selected := next }

def pointerInPlot (bounds : Bounds) (row : Nat) : Bool :=
  decide (plotTop <= row && row < plotTop + plotHeight bounds)

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signed (value : Int) : String :=
  if value > 0 then "+" ++ toString value else toString value

private def values (state : State) : List Int :=
  match state.view with
  | .overview =>
      state.overview.map (fun snapshot =>
        snapshot.points.map (·.dailyAverageQuanta)) |>.getD []
  | .detail =>
      state.snapshot.map (fun snapshot =>
        snapshot.points.map (·.daily.quanta)) |>.getD []

private def extrema (values : List Int) : Int × Int :=
  values.foldl
    (fun (low, high) value => (min low value, max high value))
    (0, 0)

private def interpolate (left right : Int) (numerator denominator : Nat) : Int :=
  if denominator = 0 then left
  else
    left +
      (right - left) * Int.ofNat numerator / Int.ofNat denominator

private def sampleAt (values : List Int) (width x : Nat) : Int :=
  let count := values.length
  if count = 0 then 0
  else if count = 1 || width <= 1 then values.head?.getD 0
  else if x + 1 >= width then values.getLast?.getD 0
  else
    let denominator := width - 1
    let scaled := x * (count - 1)
    let segment := scaled / denominator
    let remainder := scaled % denominator
    let left := values[segment]?.getD 0
    let right := values[segment + 1]?.getD left
    interpolate left right remainder denominator

private def rowForValue
    (height : Nat) (low high value : Int) : Nat :=
  if height <= 1 || high <= low then 0
  else
    let offset :=
      (value - low) * Int.ofNat (height - 1) / (high - low)
    (height - 1) - min (height - 1) offset.natAbs

private def valueForRow (height row : Nat) (low high : Int) : Int :=
  if height <= 1 || high <= low then high
  else
    high -
      (high - low) * Int.ofNat row / Int.ofNat (height - 1)

private def axisText (height row : Nat) (low high : Int) : String :=
  if row = 0 || row = height / 2 || row + 1 = height then
    Loam.Tui.Layout.padLeft 8 (toString (valueForRow height row low high)) ++ " ┤ "
  else
    "         │ "

private def chartRow
    (bounds : Bounds) (state : State)
    (row : Nat) : Widget :=
  let width := plotWidth bounds
  let height := plotHeight bounds
  let series := values state
  let (low, high) := extrema series
  let selectedX := xForIndex width series.length state.selected
  let plotSpans :=
    (List.range width).map fun x =>
      let value := sampleAt series width x
      let valueRow := rowForValue height low high value
      if x = selectedX then
        if row = valueRow then span "◆" .selected
        else span "│" .muted
      else if row = valueRow then
        span "•"
      else if valueForRow height row low high = 0 then
        span "─" .muted
      else
        span " "
  .row ([span (axisText height row low high)] ++ plotSpans)

private def overviewAxis
    (bounds : Bounds) (snapshot : Loam.LocusTrendReview.OverviewSnapshot) : Widget :=
  let count := snapshot.points.length
  let width := plotWidth bounds
  let chunk := if count = 0 then width else max 1 (width / count)
  let labels := snapshot.points.map fun point =>
    let endLabel :=
      if point.complete then point.endExclusive else point.throughExclusive
    let startShort := String.ofList (point.start.toList.drop 5)
    let endShort := String.ofList (endLabel.toList.drop 5)
    Loam.Tui.Layout.padRight chunk (startShort ++ "→" ++ endShort)
  .row ([span (String.ofList (List.replicate plotLeft ' '))] ++ labels.map span)

private def detailAxis
    (bounds : Bounds) (state : State)
    (snapshot : Loam.LocusTrendReview.Snapshot) : Widget :=
  let selected := (selectedPoint? state).map (·.date) |>.getD snapshot.start
  let last :=
    snapshot.points.getLast?.map (·.date) |>.getD snapshot.start
  let text := snapshot.start ++ "    " ++ selected ++ "    " ++ last
  .row
    [ span (String.ofList (List.replicate plotLeft ' '))
    , span (Loam.Tui.Layout.clip (plotWidth bounds) text) .muted
    ]

private def header (state : State) : List Widget :=
  match state.view with
  | .overview =>
      match state.overview, selectedOverviewPoint? state with
      | some snapshot, some point =>
          let observedEnd :=
            if point.complete then point.endExclusive else point.throughExclusive
          [ line "Reports / Locus Trend"
          , muted
              ("Long history by configured " ++ snapshot.source ++
                " boundaries through " ++ snapshot.observedAt ++ ".")
          , line
              ("Coordinate " ++ snapshot.coordinate.locus.token ++
                " / " ++ snapshot.coordinate.measure.token)
          , line
              ("Selected [" ++ point.start ++ ", " ++ observedEnd ++
                (if point.complete then ")" else ")  partial"))
          , line
              ("Average " ++ signed point.dailyAverageQuanta ++ "/day   total " ++
                signed point.total.quanta ++ " " ++ snapshot.coordinate.measure.token ++
                "   observed " ++ toString point.observedDays ++ " day(s)")
          , muted "Current admitted truth; configured boundaries are query coordinates, not retained cycle facts."
          , blank
          ]
      | _, _ =>
          [ line "Reports / Locus Trend"
          , muted "Long-history overview unavailable."
          , blank, blank, blank, blank, blank
          ]
  | .detail =>
      match state.snapshot, selectedPoint? state with
      | some snapshot, some point =>
          [ line "Reports / Locus Trend / Daily"
          , muted
              ("Daily detail [" ++ snapshot.start ++ ", " ++
                snapshot.endExclusive ++ ")")
          , line
              ("Coordinate " ++ snapshot.coordinate.locus.token ++
                " / " ++ snapshot.coordinate.measure.token)
          , line
              ("Selected " ++ point.date ++
                "   day " ++ signed point.daily.quanta ++ " " ++
                snapshot.coordinate.measure.token)
          , line
              ("Cumulative " ++ signed point.cumulative.quanta ++
                "   running avg " ++
                signed point.runningDailyAverageQuanta ++ "/day")
          , muted "Current admitted truth; corrected originals are excluded."
          , blank
          ]
      | _, _ =>
          [ line "Reports / Locus Trend / Daily"
          , muted "Daily detail unavailable."
          , blank, blank, blank, blank, blank
          ]

private def footer (state : State) : List Widget :=
  match state.view with
  | .overview =>
      [ muted "←/→ or h/l select cycle   Enter daily detail   mouse selects nearest cycle"
      , muted "q / Esc Reports menu"
      ]
  | .detail =>
      [ muted "←/→ or h/l select day   mouse selects nearest day"
      , muted "q / Esc long history"
      ]

/--
Render Trend as a dedicated full-screen chart instead of the ordinary Reports
scrolling body. The chart consumes every row left after its fixed context and
navigation lines.
-/
def viewFullScreen (bounds : Bounds) (state : State) (notice : String := "") : Widget :=
  let chart :=
    (List.range (plotHeight bounds)).map fun row =>
      chartRow bounds state row
  let axis :=
    match state.view with
    | .overview =>
        match state.overview with
        | some snapshot => overviewAxis bounds snapshot
        | none => muted ""
    | .detail =>
        match state.snapshot with
        | some snapshot => detailAxis bounds state snapshot
        | none => muted ""
  let all :=
    header state ++ chart ++ [axis] ++ footer state ++
      (if notice.isEmpty then [] else [line notice])
  .column (all.take bounds.height)

end Loam.Tui.LocusTrendPane
