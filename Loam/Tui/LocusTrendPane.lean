import Loam.LocusTrendReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.LocusTrendPane

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Locus Trend presentation pane

Owns only cursor selection and compact terminal rendering for one already-derived
`LocusTrendReview.Snapshot`.

The selected point is presentation state. Keyboard and pointer input both reduce
to the same point-selection operation, so adding pointer-motion tracking later
does not create a second trend semantics.
-/

structure State where
  snapshot : Option Loam.LocusTrendReview.Snapshot := none
  selected : Nat := 0
  deriving Repr, DecidableEq

def initial : State := {}

def clear (state : State) : State :=
  { state with snapshot := none, selected := 0 }

def withSnapshot
    (state : State) (snapshot : Loam.LocusTrendReview.Snapshot) : State :=
  let selected := if snapshot.points.isEmpty then 0 else snapshot.points.length - 1
  { state with snapshot := some snapshot, selected := selected }

def moveSelection (state : State) (back : Bool) : State :=
  match state.snapshot with
  | none => state
  | some snapshot =>
      if snapshot.points.isEmpty then
        { state with selected := 0 }
      else
        let last := snapshot.points.length - 1
        let current := min state.selected last
        let next :=
          if back then current - 1 else min last (current + 1)
        { state with selected := next }

def selectedPoint? (state : State) : Option Loam.LocusTrendReview.Point := do
  let snapshot ← state.snapshot
  snapshot.points[state.selected]?

/-- Left edge of the one-cell-per-visible-day sparkline in terminal columns. -/
def plotLeft : Nat := 2

def plotCapacity (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - (plotLeft + 2))

def visiblePoints
    (bounds : Bounds) (state : State) :
    List (Nat × Loam.LocusTrendReview.Point) :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      Loam.Tui.Layout.centeredListWindow
        snapshot.points state.selected (plotCapacity bounds)

/--
Select the visible day nearest the pointer column.

The row is intentionally owned by the enclosing Reports surface. This function
only translates horizontal chart geometry into the same selected-point state
used by keyboard navigation.
-/
def selectColumn (bounds : Bounds) (state : State) (column : Nat) : State :=
  if column < plotLeft then state
  else
    let visible := visiblePoints bounds state
    let offset := column - plotLeft
    match visible[offset]? with
    | some (index, _) => { state with selected := index }
    | none => state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signed (value : Int) : String :=
  if value > 0 then "+" ++ toString value else toString value

private def positiveGlyph (amount maxAmount : Nat) : Char :=
  if maxAmount = 0 then '·'
  else
    let level := min 7 ((amount * 8 - 1) / maxAmount)
    match level with
    | 0 => '▁'
    | 1 => '▂'
    | 2 => '▃'
    | 3 => '▄'
    | 4 => '▅'
    | 5 => '▆'
    | 6 => '▇'
    | _ => '█'

private def glyphFor (maximum : Nat) (quanta : Int) : Char :=
  if quanta = 0 then '·'
  else if quanta < 0 then 'v'
  else positiveGlyph quanta.natAbs maximum

private def maximumPositive
    (visible : List (Nat × Loam.LocusTrendReview.Point)) : Nat :=
  visible.foldl
    (fun current entry =>
      max current (max 0 entry.2.daily.quanta).natAbs)
    0

private def plotRow (bounds : Bounds) (state : State) : Widget :=
  let visible := visiblePoints bounds state
  let maximum := maximumPositive visible
  .row <|
    [span (String.ofList (List.replicate plotLeft ' '))] ++
    visible.map fun (index, point) =>
      span (toString (glyphFor maximum point.daily.quanta))
        (if index == state.selected then .selected else .normal)

private def visibleDateLine (bounds : Bounds) (state : State) : Widget :=
  let visible := visiblePoints bounds state
  match visible.head?, visible.getLast? with
  | some (_, first), some (_, last) =>
      muted
        ("  " ++ first.date ++
          (if first.date == last.date then "" else " … " ++ last.date))
  | _, _ => muted "  no visible day"

def lines (bounds : Bounds) (state : State) : List Widget :=
  match state.snapshot with
  | none =>
      [ muted "No Locus Trend has been loaded yet."
      , muted "Press Enter to run the current explicit window."
      ]
  | some snapshot =>
      let selected := selectedPoint? state
      let selectedLines :=
        match selected with
        | none => [muted "No selected day."]
        | some point =>
            [ line
                ("Selected " ++ point.date ++
                  "  day " ++ signed point.daily.quanta ++ " " ++
                  snapshot.coordinate.measure.token)
            , line
                ("Cumulative " ++ signed point.cumulative.quanta ++
                  "  running avg " ++
                  signed point.runningDailyAverageQuanta ++ "/day")
            ]
      [ line
          ("Coordinate " ++ snapshot.coordinate.locus.token ++
            " / " ++ snapshot.coordinate.measure.token)
      , line
          ("Total " ++ signed snapshot.total.quanta ++ " " ++
            snapshot.coordinate.measure.token)
      ] ++
      selectedLines ++
      [ muted
          ("Undated matching current records: " ++
            toString snapshot.undatedMatchingCurrentRecords)
      , muted "Current admitted truth; corrected originals are excluded."
      , blank
      , plotRow bounds state
      , visibleDateLine bounds state
      ]

end Loam.Tui.LocusTrendPane
