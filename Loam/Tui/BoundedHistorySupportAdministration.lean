import Loam.Tui.EditorSession
import Loam.ActualDate
import Loam.BoundedHistorySupportPublisher
import Loam.BoundedHistorySupportReview
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.BoundedHistorySupportAdministration

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Layout
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Bounded history support administration

This presentation surface edits one explicit household certification:

> every real quantity change for this coordinate from the start of this day
> onward is represented by dated Actual evidence.

The UI does not infer the certification from matching balances and does not
manufacture balancing Events. Publication is delegated to the shared household
command/publisher boundary, which rechecks CurrentQuantityAnchor and Actual.
-/

inductive Phase where
  | editing
  | preview
  deriving Repr, DecidableEq

structure State where
  rows : List Loam.BoundedHistorySupportReview.Row
  cursor : Nat := 0
  startDay : String := ""
  phase : Phase := .editing
  notice : String := ""
  deriving Repr

abbrev Step :=
  Loam.Tui.EditorSession.Step State Loam.BoundedHistorySupportPublisher.Draft

private def rowStart (row : Loam.BoundedHistorySupportReview.Row) : String :=
  row.startDay.getD ""

private def selectedRow? (state : State) : Option Loam.BoundedHistorySupportReview.Row :=
  state.rows[state.cursor]?

def initial (snapshot : Loam.BoundedHistorySupportReview.Snapshot) : State :=
  match snapshot.rows with
  | [] => { rows := [] }
  | first :: _ => { rows := snapshot.rows, startDay := rowStart first }

private def selectedExistingStart? (state : State) : Option String := do
  let row ← selectedRow? state
  row.startDay

private def validation?
    (state : State) : Except String Loam.BoundedHistorySupportPublisher.Draft := do
  let some row := selectedRow? state
    | throw "No exact current quantity coordinate is available for history support."
  if state.startDay.isEmpty then
    if row.startDay.isSome then
      return { coordinate := row.coordinate, startDay := none }
    else
      throw "Enter the first complete YYYY-MM-DD day before preview."
  if !row.hasExactCurrentAnchor then
    throw "This coordinate has no exact CurrentQuantityAnchor; remove stale support or observe current quantity first."
  if !Loam.ActualDate.validIsoDate state.startDay then
    throw "History start must be a real YYYY-MM-DD calendar day."
  return { coordinate := row.coordinate, startDay := some state.startDay }

def draft? (state : State) : Option Loam.BoundedHistorySupportPublisher.Draft :=
  match validation? state with
  | .ok draft => some draft
  | .error _ => none

private def selectIndex (state : State) (index : Nat) : State :=
  match state.rows[index]? with
  | none => state
  | some row =>
      { state with cursor := index, startDay := rowStart row, notice := "" }

private def moveUp (state : State) : State :=
  if state.cursor = 0 then state else selectIndex state (state.cursor - 1)

private def moveDown (state : State) : State :=
  if state.cursor + 1 < state.rows.length then selectIndex state (state.cursor + 1)
  else state

private def editableChar (char : Char) : Bool :=
  char.isDigit || char = '-'

def update (state : State) (key : Key) : Step :=
  match state.phase with
  | .editing =>
      match key with
      | .escape => { state := state, cancel := true }
      | .up => { state := moveUp state }
      | .down => { state := moveDown state }
      | .backspace =>
          { state := { state with startDay := Loam.Tui.Terminal.backspaceText state.startDay, notice := "" } }
      | .input char =>
          if editableChar char then
            { state := { state with startDay := state.startDay.push char, notice := "" } }
          else
            { state := state }
      | .enter =>
          match validation? state with
          | .ok _ => { state := { state with phase := .preview, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | _ => { state := state }
  | .preview =>
      match key with
      | .enter =>
          match validation? state with
          | .ok draft => { state := state, publish := some draft }
          | .error message =>
              { state := { state with phase := .editing, notice := message } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with phase := .editing, notice := "" } }
      | _ => { state := state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := line ""

private def coordinateText (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

private def supportText (row : Loam.BoundedHistorySupportReview.Row) : String :=
  match row.startDay with
  | some day => day
  | none => "(not certified)"

private def visibleRows (bounds : Bounds) (state : State) :
    List (Nat × Loam.BoundedHistorySupportReview.Row) :=
  let maxVisible := if bounds.height > 16 then min 10 (bounds.height - 14) else 4
  let selected := if state.rows.isEmpty then 0 else min state.cursor (state.rows.length - 1)
  let start := Loam.Tui.Layout.trailingWindowStart selected maxVisible
  (state.rows.drop start |>.take maxVisible).zipIdx.map fun (row, index) =>
    (start + index, row)

private def candidateRows (bounds : Bounds) (state : State) : List Widget :=
  if state.rows.isEmpty then
    [muted "   (no current anchor or retained history-support coordinate)"]
  else
    (visibleRows bounds state).map fun (index, row) =>
      let selected := index = state.cursor
      let anchor := if row.hasExactCurrentAnchor then "anchor exact" else "anchor missing"
      .row [
        span
          ((if selected then "▶  " else "   ") ++
            padRight 32 (coordinateText row.coordinate) ++
            padRight 18 (supportText row) ++ anchor)
          (if selected then .selected else .normal)
      ]

private def previewMeaning
    (state : State)
    (draft : Loam.BoundedHistorySupportPublisher.Draft) : List Widget :=
  match draft.startDay with
  | none =>
      [ line ("Coordinate: " ++ coordinateText draft.coordinate)
      , line ("Remove complete-since claim: " ++
          (selectedExistingStart? state).getD "(none)")
      , blank
      , muted "Historical readers will no longer use bounded support for this coordinate."
      ]
  | some day =>
      [ line ("Coordinate: " ++ coordinateText draft.coordinate)
      , line ("Complete from start-of-day: " ++ day)
      , blank
      , muted "Certify only if every real quantity change from this day onward is in dated Actual."
      , muted "A matching current balance alone does not prove this claim."
      ]

def view (bounds : Bounds) (state : State) : Widget :=
  match state.phase with
  | .editing =>
      .column <|
        [ line "History Support / Complete Since"
        , muted "Explicit household certification; never inferred from endpoint equality"
        , blank
        , muted ("   " ++ padRight 32 "Coordinate" ++ padRight 18 "Complete since" ++ "Current support")
        ] ++ candidateRows bounds state ++
        [ blank
        , line ("Start day: " ++ (if state.startDay.isEmpty then "_" else state.startDay))
        , muted "YYYY-MM-DD means complete from the start of that calendar day."
        , muted "For an existing claim, erase the date and press Enter to remove it."
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ choose coordinate   type date   Backspace edit   Enter preview   Esc back"
        ]
  | .preview =>
      match validation? state with
      | .error message =>
          .column [
            line "History Support / Preview",
            line message,
            muted "Esc return"
          ]
      | .ok draft =>
          .column <|
            [ line "History Support / Preview"
            , muted "No Actual movement or current quantity will be changed by this publication."
            , blank
            ] ++ previewMeaning state draft ++
            [ blank
            , muted "The publisher re-checks CurrentQuantityAnchor and all relevant current Actual dates."
            , if state.notice.isEmpty then blank else line state.notice
            , muted "Enter publish   e/E or Esc edit"
            ]

end Loam.Tui.BoundedHistorySupportAdministration
