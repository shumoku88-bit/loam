import Loam.TransactionsFlowReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.TransactionsFlowPane

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Transactions Flow result-local presentation owner

This module owns only the presentation state that is meaningful after a
`TransactionsFlowReview.Snapshot` exists. Shared report-window coordinates,
query emission, stale-result invalidation policy, workspace scrolling, paging,
menu composition, and household semantics remain outside this module.
-/

structure State where
  snapshot : Option Loam.TransactionsFlowReview.Snapshot := none
  selectedIndex : Nat := 0
  detail : Bool := false


def initial : State := {}


def withSnapshot
    (state : State) (snapshot : Loam.TransactionsFlowReview.Snapshot) : State :=
  { state with snapshot := some snapshot, selectedIndex := 0, detail := false }


def clear (_state : State) : State := initial


private def coordinateLe
    (left right : Loam.Core.EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def rowLe
    (left right : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Bool :=
  if left.2.gross.quanta == right.2.gross.quanta then
    coordinateLe left.1 right.1
  else
    left.2.gross.quanta >= right.2.gross.quanta

/-- Active rows in presentation-salience order; never retained as state. -/
def rows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) :=
  (snapshot.rows.map fun coordinate =>
      (coordinate, Loam.TransactionsFlowReview.rowActivity snapshot coordinate))
    |>.filter (fun row => row.2.activeEvents > 0)
    |>.mergeSort rowLe

/-- Nonzero Event witnesses for one coordinate; never retained as state. -/
def contributions
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : Loam.Core.EffectCoordinate) :
    List (Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) :=
  snapshot.columns.filterMap fun column =>
    let quantity := Loam.Core.Event.quantityAt
      column.event coordinate.locus coordinate.measure
    if quantity.quanta = 0 then none else some (column, quantity)


def hasSnapshot (state : State) : Bool := state.snapshot.isSome


def activeRowsEmpty (state : State) : Bool :=
  match state.snapshot with
  | none => true
  | some snapshot => (rows snapshot).isEmpty


def moveSelection (state : State) (back : Bool) : State :=
  match state.snapshot with
  | none => state
  | some snapshot =>
      let count := (rows snapshot).length
      if count = 0 then
        { state with selectedIndex := 0 }
      else
        let maxIndex := count - 1
        let current := min state.selectedIndex maxIndex
        let next := if back then current - 1 else min maxIndex (current + 1)
        { state with selectedIndex := next }


def openDetail (state : State) : State :=
  if activeRowsEmpty state then state else { state with detail := true }


def closeDetail (state : State) : State :=
  { state with detail := false }


def selectedRow?
    (state : State) :
    Option (Loam.TransactionsFlowReview.Snapshot ×
      (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) := do
  let snapshot ← state.snapshot
  let row ← (rows snapshot)[state.selectedIndex]?
  some (snapshot, row)

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def signedQuanta (quantity : Loam.Core.Quantity) : String :=
  if quantity.quanta > 0 then "+" ++ toString quantity.quanta else toString quantity.quanta

private def padNum (columns : Nat) (text : String) : String :=
  let width := Loam.Tui.Layout.displayWidth text
  if width ≥ columns then Loam.Tui.Layout.clip columns text
  else Loam.Tui.Layout.padLeft columns text


def summaryPrefix
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (activeRows : List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) :
    List Widget :=
  [ line ("Window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
  , muted (toString activeRows.length ++ " active coordinate(s); zero cells omitted.")
  , muted "Rows ordered by gross quantity (presentation only)."
  , blank
  ]

structure TableLayout where
  coordWidth : Nat
  netWidth : Nat
  grossWidth : Nat
  posWidth : Nat
  negWidth : Nat
  evWidth? : Option Nat
  deriving Repr

private def defaultReportWidth : Nat := 72

private def tableLayoutForWidth (width : Nat) : TableLayout :=
  if width ≥ 70 then
    { coordWidth := min 26 (width - 46)
    , netWidth := 9
    , grossWidth := 9
    , posWidth := 9
    , negWidth := 9
    , evWidth? := some 8
    }
  else if width ≥ 51 then
    { coordWidth := width - 36
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 7
    , evWidth? := some (min 6 (width - (2 + (width - 36) + 28)))
    }
  else if width ≥ 44 then
    { coordWidth := width - 30
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 7
    , evWidth? := none
    }
  else
    { coordWidth := max 10 (width - 23)
    , netWidth := 7
    , grossWidth := 7
    , posWidth := 7
    , negWidth := 0
    , evWidth? := none
    }

private def TableLayout.totalWidth (layout : TableLayout) : Nat :=
  2 + layout.coordWidth + layout.netWidth + layout.grossWidth + layout.posWidth +
    (if layout.negWidth > 0 then layout.negWidth else 0) +
    (match layout.evWidth? with | some w => w | none => 0)

private def tableHeader (layout : TableLayout) : Widget :=
  let marker := "  "
  let coord := Loam.Tui.Layout.padRight layout.coordWidth "Coordinate"
  let net := padNum layout.netWidth "Net"
  let gross := padNum layout.grossWidth "Gross"
  let pos := padNum layout.posWidth "+In"
  let neg := if layout.negWidth > 0 then padNum layout.negWidth "-Out" else ""
  let ev := match layout.evWidth? with
    | some w => if w ≥ 6 then padNum w "Events" else padNum w "Ev"
    | none => ""
  muted (marker ++ coord ++ net ++ gross ++ pos ++ neg ++ ev)

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def tableRule (layout : TableLayout) : Widget :=
  muted (repeatChar layout.totalWidth '-')

private def rowLine
    (state : State) (layout : TableLayout) (index : Nat)
    (row : Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) : Widget :=
  let coordinate := row.1
  let activity := row.2
  let marker := if state.selectedIndex = index then "> " else "  "
  let coordToken := coordinate.locus.token ++ "/" ++ coordinate.measure.token
  let coord := Loam.Tui.Layout.padRight layout.coordWidth coordToken
  let net := padNum layout.netWidth (signedQuanta activity.net)
  let gross := padNum layout.grossWidth (toString activity.gross.quanta)
  let pos := padNum layout.posWidth (signedQuanta activity.positive)
  let neg := if layout.negWidth > 0 then padNum layout.negWidth (signedQuanta activity.negative) else ""
  let ev := match layout.evWidth? with
    | some w => padNum w (toString activity.activeEvents)
    | none => ""
  line (marker ++ coord ++ net ++ gross ++ pos ++ neg ++ ev)

private def rowLines
    (state : State) (layout : TableLayout) : Nat →
    List (Loam.Core.EffectCoordinate × Loam.TransactionsFlowReview.RowActivity) →
    List Widget
  | _, [] => []
  | index, row :: rest =>
      rowLine state layout index row :: rowLines state layout (index + 1) rest

/-- Transactions result body only; Reports owns the window editor and footer. -/
def summaryLines (state : State) (bounds : Option Bounds) : List Widget :=
  match state.snapshot with
  | none => [muted "No explicit Transactions Flow window has been run yet."]
  | some snapshot =>
      let activeRows := rows snapshot
      summaryPrefix snapshot activeRows ++
      if activeRows.isEmpty then
        [muted "No quantity activity appears in this window."]
      else
        let width := match bounds with
          | some b => Loam.Tui.Layout.contentWidth b
          | none => defaultReportWidth
        let layout := tableLayoutForWidth width
        tableHeader layout :: tableRule layout :: rowLines state layout 0 activeRows

private def contributionLine
    (coordinate : Loam.Core.EffectCoordinate)
    (entry : Loam.TransactionsFlowReview.Column × Loam.Core.Quantity) : Widget :=
  let column := entry.1
  let quantity := entry.2
  let description :=
    if column.description.isEmpty then
      "[" ++ column.event.id.token ++ "]"
    else
      column.description ++ "  [" ++ column.event.id.token ++ "]"
  line
    ("- " ++ column.date ++ "  " ++ signedQuanta quantity ++ " " ++
      coordinate.measure.token ++ "  " ++ description)

/-- Focused detail body only; Reports owns workspace scroll and navigation/footer. -/
def detailLines (state : State) : List Widget :=
  match selectedRow? state with
  | none => [muted "No selected Transactions Flow coordinate is available."]
  | some (snapshot, row) =>
      let coordinate := row.1
      let activity := row.2
      let witnesses := contributions snapshot coordinate
      [ line ("Focused coordinate: " ++ coordinate.locus.token ++ "/" ++ coordinate.measure.token)
      , line
          ("Net " ++ toString activity.net.quanta ++
            " | Gross " ++ toString activity.gross.quanta ++
            " | +In " ++ signedQuanta activity.positive ++
            " | -Out " ++ signedQuanta activity.negative)
      , muted (toString witnesses.length ++ " contributing Event(s); zero cells omitted.")
      , blank
      ] ++
      witnesses.map (contributionLine coordinate) ++
      [ blank
      , muted "Signs are exact quantity changes, not income/expense."
      ]

/-- Zero-based selected-row position inside `summaryLines`, when a row exists. -/
def selectedSummaryLine? (state : State) : Option Nat := do
  let snapshot ← state.snapshot
  let activeRows := rows snapshot
  if activeRows.isEmpty then none
  else
    let index := min state.selectedIndex (activeRows.length - 1)
    some ((summaryPrefix snapshot activeRows).length + 2 + index)

end Loam.Tui.TransactionsFlowPane
