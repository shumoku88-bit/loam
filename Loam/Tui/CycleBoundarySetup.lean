import Loam.Config.BoundaryPresetConfig
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.CycleBoundarySetup

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
A small editor for ONE explicitly named set of report/cycle boundaries.
The existing typed BoundaryPresetConfig decoder supplies the admission law.
No pension recurrence, fiscal-year rule, Event or Scheduled inference is added.
-/

inductive Phase where
  | editing
  | review
  deriving Repr, DecidableEq

structure State where
  name : String
  dates : String
  focus : Nat := 0
  phase : Phase := .editing
  notice : String := ""
  deriving Repr

abbrev Step := Loam.Tui.EditorSession.Step State Loam.BoundaryPresetConfig.Preset

def initial (selected : Option Loam.BoundaryPresetConfig.Preset) : State :=
  match selected with
  | some preset =>
      { name := preset.name, dates := String.intercalate ", " preset.boundaries }
  | none =>
      { name := "pension", dates := "" }

/-- Reuse the established TSV decoder for real dates and strict ordering. -/
def parse (state : State) : Except String Loam.BoundaryPresetConfig.Preset := do
  let days := (state.dates.splitOn ",").map (fun s => s.trimAscii.toString)
  if days.length > 32 then
    throw "Too many dates. Enter up to 32 explicit boundaries."
  let raw := state.name ++ "\t" ++ String.intercalate "\t" days ++ "\n"
  match Loam.BoundaryPresetConfig.decode? raw with
  | some [preset] => return preset
  | _ =>
      throw "Enter a token name and at least two REAL, strictly increasing YYYY-MM-DD dates, separated by commas."

private def editActive (state : State) (f : String → String) : State :=
  if state.focus == 0 then
    { state with name := f state.name, notice := "" }
  else
    { state with dates := f state.dates, notice := "" }

private def append (state : State) (piece : String) : State :=
  let clean := Loam.Tui.Terminal.singleLinePaste piece
  editActive state (fun old =>
    String.ofList ((old ++ clean).toList.take (if state.focus == 0 then 50 else 512)))

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.phase with
  | .editing =>
      match key with
      | .escape => { state, cancel := true }
      | .tab | .down => { state := { state with focus := (state.focus + 1) % 2 } }
      | .shiftTab | .up => { state := { state with focus := (state.focus + 1) % 2 } }
      | .backspace =>
          { state := editActive state Loam.Tui.Terminal.backspaceText }
      | .input char =>
          if char.toNat >= 32 && char.toNat != 127 then
            { state := append state (String.singleton char) }
          else
            { state }
      | .paste piece => { state := append state piece }
      | .enter =>
          if state.focus == 0 then
            { state := { state with focus := 1, notice := "" } }
          else
            match parse state with
            | .ok _ => { state := { state with phase := .review, notice := "" } }
            | .error message => { state := { state with notice := message } }
      | _ => { state }
  | .review =>
      match key with
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with phase := .editing, notice := "" } }
      | .enter =>
          match parse state with
          | .ok preset => { state, publish := some preset }
          | .error message =>
              { state := { state with phase := .editing, notice := message } }
      | _ => { state }

def withError (state : State) (message : String) : State :=
  { state with phase := .editing, notice := message }

private def line (width : Nat) (value : String) (style : Style := .normal) : Widget :=
  .row [span (Loam.Tui.Layout.ellipsize width value) style]

def view (bounds : Bounds) (state : State) : Widget := Id.run do
  let width := Loam.Tui.Layout.contentWidth bounds
  let rows : List Widget :=
    if state.phase == .review then
      [ line width "Daily Pace / Review explicit cycle boundaries"
      , line width ("Preset: " ++ state.name)
      , line width "Only this named preset will be replaced." .muted
      , line width "No dates are extrapolated or repeated." .muted
      , line width ("Boundaries: " ++ state.dates)
      , line width "Other named presets and ledger remain unchanged." .muted
      , line width "Enter save   Esc/e edit"
      , line width state.notice .muted ]
    else
      [ line width "Daily Pace / Cycle boundaries"
      , line width "Enter explicit dates, including today’s cycle." .muted
      , .row [span "Name: ", Loam.Tui.Layout.inputSpan (width - 6) (state.focus == 0) state.name]
      , .row [span "Dates: ", Loam.Tui.Layout.inputSpan (width - 7) (state.focus == 1) state.dates]
      , line width "Example: 2026-10-15, 2026-12-15" .muted
      , line width "Tab focus  Enter next/review  Esc cancel" .muted
      , line width state.notice .muted ]
  return .column (rows.take bounds.height)

end Loam.Tui.CycleBoundarySetup
