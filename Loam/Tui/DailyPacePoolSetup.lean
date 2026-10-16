import Loam.Core.Event
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.DailyPacePoolSetup

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
Choose an explicit, currently supported, single-Measure pool for Daily Pace.
This is query configuration only. It does not assign AccountingRoles, create
account balances, infer pool membership from names, or modify canonical data.
-/

inductive Phase where
  | choose
  | review
  deriving Repr, DecidableEq

structure State where
  measure : MeasureId
  candidates : List EffectCoordinate
  chosen : List EffectCoordinate
  cursor : Nat := 0
  phase : Phase := .choose
  notice : String := ""
  deriving Repr

abbrev Step := Loam.Tui.EditorSession.Step State (List EffectCoordinate)

def initial (measure : MeasureId) (candidates chosen : List EffectCoordinate) : State :=
  { measure, candidates, chosen }

private def selected (state : State) (item : EffectCoordinate) : Bool :=
  state.chosen.contains item

private def toggle (state : State) : State :=
  match state.candidates[state.cursor]? with
  | none => state
  | some coordinate =>
      if selected state coordinate then
        { state with chosen := state.chosen.filter (· != coordinate), notice := "" }
      else
        { state with chosen := state.chosen ++ [coordinate], notice := "" }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.phase with
  | .choose =>
      match key with
      | .escape | .input 'q' | .input 'Q' =>
          { state, cancel := true }
      | .up | .input 'k' =>
          { state := { state with cursor := state.cursor - 1 } }
      | .down | .input 'j' =>
          { state := { state with cursor := min (state.candidates.length - 1) (state.cursor + 1) } }
      | .input ' ' =>
          { state := toggle state }
      | .enter =>
          if state.chosen.isEmpty then
            { state := { state with notice := "Select at least one known-current balance." } }
          else
            { state := { state with phase := .review, notice := "" } }
      | _ => { state }
  | .review =>
      match key with
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with phase := .choose, notice := "" } }
      | .enter => { state, publish := some state.chosen }
      | _ => { state }

def withError (state : State) (message : String) : State :=
  { state with phase := .choose, notice := message }

private def oneLine (width : Nat) (value : String) (style : Style := .normal) : Widget :=
  .row [span (Loam.Tui.Layout.ellipsize width value) style]

private def coordinateText (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

def view (bounds : Bounds) (state : State) : Widget := Id.run do
  let width := Loam.Tui.Layout.contentWidth bounds
  let mut rows : List Widget := [
    oneLine width ("Daily Pace / Spendable pool (" ++ state.measure.token ++ ")"),
    oneLine width "Only observed exact balances can be selected." .muted
  ]
  if state.phase == .review then
    rows := rows ++ [
      oneLine width "Review: these balances fund ordinary spending.",
      oneLine width ("Selected: " ++ toString state.chosen.length),
      oneLine width "The configuration does NOT change balances or history." .muted
    ]
    for coordinate in state.chosen.take (bounds.height - 8) do
      rows := rows ++ [oneLine width ("  " ++ coordinateText coordinate)]
    rows := rows ++ [
      oneLine width "Enter: save pool   Esc/e: edit" .selected,
      oneLine width state.notice .muted
    ]
  else
    let available := bounds.height - 6
    let offset := if state.cursor < available then 0 else state.cursor + 1 - available
    let visible := (state.candidates.zipIdx.drop offset).take available
    if state.candidates.isEmpty then
      rows := rows ++ [oneLine width "No exact balances. Observe amounts first." .muted]
    for (coordinate, index) in visible do
      let cursorMark := if state.cursor == index then "> " else "  "
      let mark := if selected state coordinate then "[x] " else "[ ] "
      rows := rows ++ [
        oneLine width (cursorMark ++ mark ++ coordinateText coordinate)
          (if state.cursor == index then .selected else .normal)
      ]
    rows := rows ++ [
      oneLine width ("Chosen: " ++ toString state.chosen.length) .muted,
      oneLine width "j/k select  Space toggle  Enter review" .muted,
      oneLine width "Esc cancel; no write until confirmed." .muted,
      oneLine width state.notice .muted
    ]
  return .column (rows.take bounds.height)

end Loam.Tui.DailyPacePoolSetup
