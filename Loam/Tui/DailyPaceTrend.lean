import Loam.Tui.Chart
import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.DailyPaceTrend

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Daily Pace trend

Read-only graph and day selection for Home's already-derived retrospective
current-truth series. The domain-free `Loam.Tui.Chart` renderer is shared with
Reports / Trend; Daily Pace never reimplements series or Scheduled arithmetic.
-/

structure State where
  /-- `none` follows the most recent reconstructed day on first entry. -/
  selected : Option Nat := none
  deriving Repr, DecidableEq

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def selectedIndex (history : List Loam.CycleSpendingPaceReview.Snapshot)
    (state : State) : Nat :=
  min (history.length - 1) (state.selected.getD (history.length - 1))

/-- Move the local chart cursor without changing the household or query. -/
def moveSelection (state : State) (snapshot : Loam.Tui.Main.Snapshot)
    (back : Bool) : State :=
  match snapshot.paceHistory with
  | .loaded history =>
      if history.isEmpty then state
      else
        let current := selectedIndex history state
        let next := if back then current - 1 else min (history.length - 1) (current + 1)
        { selected := some next }
  | _ => state

private def paceLine
    (today : String)
    (snapshot : Loam.CycleSpendingPaceReview.Snapshot) : Widget :=
  let value :=
    match snapshot.dailyPaceQuanta? with
    | some quanta => toString quanta ++ " " ++ snapshot.measure.token ++ "/day"
    | none => "unavailable"
  let marker := if snapshot.observedAt == today then "  current" else ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 12 snapshot.observedAt ++
      Loam.Tui.Layout.padLeft 16 value ++ marker)

private def selectedLine
    (history : List Loam.CycleSpendingPaceReview.Snapshot)
    (state : State) : Widget :=
  let index := selectedIndex history state
  match history[index]? with
  | none => muted "  No selected reconstructed day"
  | some point =>
      let value := match point.dailyPaceQuanta? with
        | some quanta => toString quanta ++ " " ++ point.measure.token ++ "/day"
        | none => "unavailable"
      let change :=
        if index == 0 then "first point"
        else
          match history[index - 1]? with
          | none => "previous day unavailable"
          | some previous =>
              match point.dailyPaceQuanta?, previous.dailyPaceQuanta? with
              | some current, some prior =>
                  let delta := current - prior
                  "change " ++ (if delta > 0 then "+" else "") ++
                    toString delta ++ " " ++ point.measure.token ++ "/day"
              | _, _ => "change unavailable"
      line ("  Selected " ++ point.observedAt ++ "   " ++ value ++ "   (" ++ change ++ ")")

private def plotLeft : Nat := 11

private def plotWidth (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - plotLeft)

private def plotHeight
    (bounds : Bounds)
    (history : List Loam.CycleSpendingPaceReview.Snapshot) : Nat :=
  min 12 (max 3 (bounds.height - (history.length + 10)))

private def axisText (height row : Nat) (scale : Loam.Tui.Chart.Scale) : String :=
  match scale.ticks.find? (fun tick =>
      Loam.Tui.Chart.rowForValue height scale.range tick == row) with
  | some tick => Loam.Tui.Layout.padLeft 8 (toString tick) ++ " ┤ "
  | none => "         │ "

private def chartRows
    (bounds : Bounds)
    (history : List Loam.CycleSpendingPaceReview.Snapshot)
    (state : State) : List Widget :=
  let values := history.filterMap (·.dailyPaceQuanta?)
  if values.length != history.length then
    [muted "  Chart unavailable: a reconstructed daily pace is missing"]
  else
    let width := plotWidth bounds
    let height := plotHeight bounds history
    let scale := Loam.Tui.Chart.scaleFor values 4
    let gridRows := scale.ticks.map fun tick =>
      Loam.Tui.Chart.rowForValue height scale.range tick
    let rendered := Loam.Tui.Chart.renderInRange
      .braille width height values (selectedIndex history state) scale.range [] gridRows
    (List.range height).map fun row =>
      let axis := span (axisText height row scale)
      match rendered[row]? with
      | some (Widget.row spans) => Widget.row (axis :: spans)
      | _ => Widget.row [axis]

private def dateAxis
    (bounds : Bounds)
    (history : List Loam.CycleSpendingPaceReview.Snapshot) : Widget :=
  match history.head?, history.getLast? with
  | some first, some last =>
      let width := plotWidth bounds
      .row [span (String.ofList (List.replicate plotLeft ' ')),
        span (Loam.Tui.Layout.padRight (width - 10) first.observedAt ++ last.observedAt) .muted]
  | _, _ => blank

/-- Draw a selectable graph using the same Chart foundation as Reports / Trend. -/
def view (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot)
    (state : State := {}) : Widget :=
  let body :=
    [ line "Daily Pace / Trend"
    , muted "Reconstructed current-truth daily pace, not a saved daily observation"
    , blank
    ] ++
    (match snapshot.paceHistory with
     | .notRequested =>
         [muted "  history not requested"]
     | .unavailable =>
         [muted "  history unavailable"]
     | .failed message =>
         [ line "  history unavailable"
         , muted ("  " ++ Loam.Tui.Layout.clip
             (Loam.Tui.Layout.contentWidth bounds - 2) message)
         ]
     | .loaded history =>
         if history.isEmpty then
           [muted "  no reconstructed Daily Pace points"]
         else
           [selectedLine history state] ++ chartRows bounds history state ++
             [dateAxis bounds history, blank] ++
             history.map (paceLine snapshot.actual.today)) ++
    [ blank
    , muted "Calculated from your current records each time; no separate daily snapshot is kept."
    ]
  let footer := [muted "←/→ or h/l select day   q / Esc home"]
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

end Loam.Tui.DailyPaceTrend
