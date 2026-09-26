import Loam.BoundaryPresetConfig
import Loam.Tui.Calendar
import Loam.Tui.CyclicIndex
import Loam.Tui.ReportWindow

namespace Loam.Tui.ReportComparison

set_option autoImplicit false

/-!
# Two explicit report windows

This is replaceable presentation/query state only. Automatic sources derive two
adjacent explicit windows from Calendar Month or named boundary presets. Manual
editing switches the state to Custom. Report semantics, evidence, comparison
arithmetic and persistence remain elsewhere.
-/

structure State where
  leftStart : String := ""
  leftEndExclusive : String := ""
  rightStart : String := ""
  rightEndExclusive : String := ""
  focus : Fin 5 := ⟨4, by decide⟩
  calendarAnchor : String := ""
  presets : List Loam.BoundaryPresetConfig.Preset := []
  source : Loam.Tui.ReportWindow.Source := .calendarMonth
  deriving Repr, DecidableEq

structure Result where
  state : State
  notice : String := ""
  deriving Repr, DecidableEq

private def presetAt? :
    List Loam.BoundaryPresetConfig.Preset → Nat → Option Loam.BoundaryPresetConfig.Preset
  | [], _ => none
  | preset :: _, 0 => some preset
  | _ :: rest, index + 1 => presetAt? rest index

private def previousBoundary? (target : String) : List String → Option String
  | [] | [_] => none
  | first :: second :: rest =>
      if second == target then some first
      else previousBoundary? target (second :: rest)

private def followingBoundary? (target : String) : List String → Option String
  | [] | [_] => none
  | first :: second :: rest =>
      if first == target then some second
      else followingBoundary? target (second :: rest)

private def pairAroundWindow?
    (boundaries : List String) (start endExclusive : String) :
    Option (String × String × String × String) :=
  match previousBoundary? start boundaries with
  | some previous =>
      some (previous, start, start, endExclusive)
  | none =>
      match followingBoundary? endExclusive boundaries with
      | some following =>
          some (start, endExclusive, endExclusive, following)
      | none => none

private def calendarPairForDate?
    (selectedDate : String) : Option (String × String × String × String) := do
  let (currentStart, currentEnd) ←
    Loam.Tui.Calendar.calendarMonthWindowForDate? selectedDate
  let (previousStart, previousEnd) ←
    Loam.Tui.Calendar.shiftCalendarMonthWindow? currentStart currentEnd false
  some (previousStart, previousEnd, currentStart, currentEnd)

private def presetPairForDate?
    (preset : Loam.BoundaryPresetConfig.Preset) (selectedDate : String) :
    Option (String × String × String × String) := do
  let (start, endExclusive) ←
    Loam.BoundaryPresetConfig.windowForDate? preset selectedDate
  pairAroundWindow? preset.boundaries start endExclusive

private def withPair
    (state : State) (source : Loam.Tui.ReportWindow.Source)
    (pair : String × String × String × String) : State :=
  let (leftStart, leftEndExclusive, rightStart, rightEndExclusive) := pair
  { state with
      leftStart := leftStart
      leftEndExclusive := leftEndExclusive
      rightStart := rightStart
      rightEndExclusive := rightEndExclusive
      focus := ⟨4, by decide⟩
      source := source }

/-- Human-readable source label only; it never enters a report query. -/
def sourceLabel (state : State) : String :=
  match state.source with
  | .calendarMonth => "Calendar Month"
  | .custom => "Custom"
  | .preset index =>
      match presetAt? state.presets index with
      | some preset => preset.name
      | none => "Unavailable preset"

/--
Seed a comparison from the single-period report source.

Calendar Month and qualified named presets prefer previous/current adjacency.
If a named preset cannot justify two adjacent windows, comparison falls back to
Custom instead of inventing a boundary.
-/
def fromWindow (window : Loam.Tui.ReportWindow.State) : State :=
  let base : State := {
    leftStart := window.form.start
    leftEndExclusive := window.form.endExclusive
    rightStart := window.form.start
    rightEndExclusive := window.form.endExclusive
    focus := ⟨4, by decide⟩
    calendarAnchor := window.calendarAnchor
    presets := window.presets
    source := window.source
  }
  match window.source with
  | .calendarMonth =>
      match calendarPairForDate? window.calendarAnchor with
      | some pair => withPair base .calendarMonth pair
      | none => { base with source := .custom }
  | .preset index =>
      match presetAt? window.presets index with
      | some preset =>
          match presetPairForDate? preset window.calendarAnchor with
          | some pair => withPair base (.preset index) pair
          | none => { base with source := .custom }
      | none => { base with source := .custom }
  | .custom => base

/-- Move among Left Start/End, Right Start/End, and Run. -/
def moveFocus (state : State) (back : Bool) : State :=
  let next :=
    if back then Loam.Tui.CyclicIndex.backward 5 state.focus.val
    else Loam.Tui.CyclicIndex.forward 5 state.focus.val
  { state with focus := ⟨next, by
      dsimp [next]
      split
      · exact Loam.Tui.CyclicIndex.backward_lt 5 state.focus.val (by decide)
      · exact Loam.Tui.CyclicIndex.forward_lt 5 state.focus.val (by decide)⟩ }

/-- Start manual editing while preserving the currently visible coordinates. -/
def beginCustomEditing (state : State) : State :=
  { state with source := .custom, focus := ⟨0, by decide⟩ }

/-- Edit only the active date coordinate. Any edit makes the source Custom. -/
def editActive (state : State) (edit : String → String) : State :=
  match state.focus.val with
  | 0 => { state with leftStart := edit state.leftStart, source := .custom }
  | 1 => { state with leftEndExclusive := edit state.leftEndExclusive, source := .custom }
  | 2 => { state with rightStart := edit state.rightStart, source := .custom }
  | 3 => { state with rightEndExclusive := edit state.rightEndExclusive, source := .custom }
  | _ => state

private def selectSource
    (state : State) (source : Loam.Tui.ReportWindow.Source) : Result :=
  match source with
  | .calendarMonth =>
      match calendarPairForDate? state.calendarAnchor with
      | some pair => { state := withPair state .calendarMonth pair }
      | none =>
          { state := { state with source := .calendarMonth }
            notice := "Calendar-month comparison unavailable for the selected Home date." }
  | .preset index =>
      match presetAt? state.presets index with
      | none =>
          { state := { state with source := .preset index }
            notice := "Selected comparison preset is unavailable." }
      | some preset =>
          match presetPairForDate? preset state.calendarAnchor with
          | some pair => { state := withPair state (.preset index) pair }
          | none =>
              { state := {
                  state with
                  source := .preset index
                  leftStart := ""
                  leftEndExclusive := ""
                  rightStart := ""
                  rightEndExclusive := ""
                  focus := ⟨0, by decide⟩
                }
                notice :=
                  "Preset " ++ preset.name ++
                  " does not contain two adjacent windows around the selected Home date." }
  | .custom => { state := beginCustomEditing state }

/-- Cycle among Calendar Month and loaded named presets. Custom is reached by editing. -/
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
  if next = 0 then selectSource state .calendarMonth
  else selectSource state (.preset (next - 1))

private def shiftPresetPair?
    (preset : Loam.BoundaryPresetConfig.Preset)
    (state : State) (forward : Bool) :
    Option (String × String × String × String) :=
  if forward then do
    let following ← followingBoundary? state.rightEndExclusive preset.boundaries
    some
      (state.rightStart, state.rightEndExclusive,
       state.rightEndExclusive, following)
  else do
    let previous ← previousBoundary? state.leftStart preset.boundaries
    some
      (previous, state.leftStart,
       state.leftStart, state.leftEndExclusive)

/-- Shift the whole adjacent comparison pair by one source window. -/
def shiftPair (state : State) (forward : Bool) : Result :=
  match state.source with
  | .calendarMonth =>
      match
          Loam.Tui.Calendar.shiftCalendarMonthWindow?
            state.leftStart state.leftEndExclusive forward,
          Loam.Tui.Calendar.shiftCalendarMonthWindow?
            state.rightStart state.rightEndExclusive forward with
      | some (leftStart, leftEndExclusive), some (rightStart, rightEndExclusive) =>
          { state := {
              state with
              leftStart := leftStart
              leftEndExclusive := leftEndExclusive
              rightStart := rightStart
              rightEndExclusive := rightEndExclusive
            } }
      | _, _ =>
          { state
            notice := "Calendar-month comparison pair cannot be shifted from these coordinates." }
  | .preset index =>
      match presetAt? state.presets index with
      | none =>
          { state, notice := "Selected comparison preset is unavailable." }
      | some preset =>
          match shiftPresetPair? preset state forward with
          | some pair => { state := withPair state (.preset index) pair }
          | none =>
              { state
                notice :=
                  "Preset " ++ preset.name ++
                  " has no further explicit adjacent comparison pair in that direction." }
  | .custom =>
      { state
        notice := "Arrow keys shift automatic comparison sources only; press [ / ] or edit dates." }

end Loam.Tui.ReportComparison
