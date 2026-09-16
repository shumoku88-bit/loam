import Loam.BoundaryPresetConfig
import Loam.Tui.Calendar

namespace Loam.Tui.ReportWindow

set_option autoImplicit false

/-!
# Reports explicit-window presentation state

This module owns only the replaceable presentation/query coordinates shared by
Stock-Flow, Transactions Flow, Income & Expense, and Budget Window. It does not
own report answers, household authority, result invalidation, or Liquidity's
independent completeness-assumption horizon.
-/

inductive Source where
  | calendarMonth
  | preset (index : Nat)
  | custom
  deriving Repr, DecidableEq

structure Form where
  start : String := ""
  endExclusive : String := ""
  focus : Fin 3 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

structure State where
  form : Form := {}
  calendarAnchor : String := ""
  presets : List Loam.BoundaryPresetConfig.Preset := []
  source : Source := .calendarMonth
  deriving Repr, DecidableEq

/-- One window transition plus presentation-only explanatory text. -/
structure Result where
  state : State
  notice : String := ""
  deriving Repr, DecidableEq

private def presetAt? :
    List Loam.BoundaryPresetConfig.Preset → Nat → Option Loam.BoundaryPresetConfig.Preset
  | [], _ => none
  | preset :: _, 0 => some preset
  | _ :: rest, index + 1 => presetAt? rest index

/-- Human-readable label only; this value never enters a report query. -/
def sourceLabel (state : State) : String :=
  match state.source with
  | .calendarMonth => "Calendar Month"
  | .custom => "Custom"
  | .preset index =>
      match presetAt? state.presets index with
      | some preset => preset.name
      | none => "Unavailable preset"

/-- Seed the explicit-window editor from the Home selected day and named presets. -/
def initialForDateWithPresets
    (selectedDate : String)
    (presets : List Loam.BoundaryPresetConfig.Preset) : Result :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? selectedDate with
  | some (start, endExclusive) =>
      { state := {
          form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
          calendarAnchor := selectedDate
          presets := presets
          source := .calendarMonth
        } }
  | none =>
      { state := {
          calendarAnchor := selectedDate
          presets := presets
          source := .calendarMonth
        }
        notice := "Calendar-month prefill unavailable; enter explicit report coordinates." }

/-- Move among Start, End, and Run without changing query coordinates. -/
def moveFocus (state : State) (back : Bool) : State :=
  let next := if back then (state.form.focus.val + 2) % 3 else (state.form.focus.val + 1) % 3
  { state with form := { state.form with focus := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by decide)⟩ } }

/-- Edit the active coordinate. Editing Start or End makes the source explicitly Custom. -/
def editActive (state : State) (edit : String → String) : State :=
  if state.form.focus.val = 0 then
    { state with
        form := { state.form with start := edit state.form.start }
        source := .custom }
  else if state.form.focus.val = 1 then
    { state with
        form := { state.form with endExclusive := edit state.form.endExclusive }
        source := .custom }
  else
    state

private def setCalendarCoordinates
    (state : State) (start endExclusive : String) : State :=
  { state with
      form := { state.form with start := start, endExclusive := endExclusive }
      source := .calendarMonth }

/-- Restore the calendar month containing the Home selected day and focus Run. -/
def resetCalendarMonth (state : State) : Result :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? state.calendarAnchor with
  | some (start, endExclusive) =>
      { state := {
          (setCalendarCoordinates state start endExclusive) with
          form := { state.form with
            start := start
            endExclusive := endExclusive
            focus := ⟨2, by decide⟩ }
        } }
  | none =>
      { state := state
        notice := "Calendar-month reset unavailable; enter an explicit window." }

private def selectPreset (state : State) (index : Nat) : Result :=
  match presetAt? state.presets index with
  | none =>
      { state := {
          state with
          form := { start := "", endExclusive := "", focus := ⟨0, by decide⟩ }
          source := .preset index
        }
        notice := "Selected report preset is unavailable." }
  | some preset =>
      match Loam.BoundaryPresetConfig.windowForDate? preset state.calendarAnchor with
      | some (start, endExclusive) =>
          { state := {
              state with
              form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
              source := .preset index
            } }
      | none =>
          { state := {
              state with
              form := { start := "", endExclusive := "", focus := ⟨0, by decide⟩ }
              source := .preset index
            }
            notice :=
              "Preset " ++ preset.name ++
              " has no explicit adjacent boundary window for " ++ state.calendarAnchor ++ "." }

/-- Cycle only among Calendar Month and loaded named presets. Custom is reached by editing. -/
def cycleSource (state : State) (forward : Bool) : Result :=
  let count := state.presets.length + 1
  let current :=
    match state.source with
    | .calendarMonth => 0
    | .preset index => index + 1
    | .custom => 0
  let next :=
    if forward then
      (current + 1) % count
    else
      (current + count - 1) % count
  if next = 0 then resetCalendarMonth state else selectPreset state (next - 1)

/-- Shift only while Calendar Month is the selected presentation source. -/
def shiftCalendarMonth (state : State) (forward : Bool) : Result :=
  match state.source with
  | .calendarMonth =>
      match Loam.Tui.Calendar.shiftCalendarMonthWindow?
          state.form.start state.form.endExclusive forward with
      | some (start, endExclusive) =>
          { state := setCalendarCoordinates state start endExclusive }
      | none =>
          { state := state
            notice := "Calendar-month coordinates are unavailable; press m to restore them." }
  | _ =>
      { state := state
        notice := "Arrow keys shift Calendar Month only; press m or [ / ] to choose a source." }

end Loam.Tui.ReportWindow
