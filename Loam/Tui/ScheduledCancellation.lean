import Loam.ScheduledTerminalPublisher
import Loam.Tui.Main
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledCancellation

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected Scheduled cancellation confirmation

Cancellation has no editable household payload. This module therefore keeps only
presentation evidence needed to confirm the visible target. The durable intent is
just the Scheduled identity; `ScheduledTerminalPublisher` re-reads lifecycle and
Movement evidence before publication.
-/
structure State where
  target : Loam.Core.ScheduledId
  scheduledOn : String
  expected : List String
  -- 0 = Cancel Scheduled, 1 = Keep. Protective default is Keep.
  choice : Fin 2 := ⟨1, by omega⟩

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ScheduledTerminalPublisher.CancellationDraft := none

private def expectedLines (record : Loam.Tui.Main.ScheduledRecord) : List String :=
  record.movement.changes.map fun change =>
    change.coordinate.token ++ "  " ++ toString change.quantity.quanta ++ " " ++ record.measure.token

/-- Capture display-only context for one selected Scheduled identity. -/
def initial (record : Loam.Tui.Main.ScheduledRecord) : State :=
  { target := record.id
    scheduledOn := record.scheduledOn
    expected := expectedLines record }

/-- Confirmation owns no lifecycle semantics and emits at most one target-only intent. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | .tab | .shiftTab | .left | .right =>
      { state := { state with choice := ⟨(state.choice.val + 1) % 2, Nat.mod_lt _ (by omega)⟩ } }
  | .enter =>
      if state.choice.val = 0 then
        { state, publish := some { scheduled := state.target } }
      else
        { state, cancel := true }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]

/-- Consequential retirement gets one explicit, default-safe confirmation boundary. -/
def view (state : State) : Widget :=
  .column <|
    [ line "Scheduled / Cancel"
    , line ("Target: " ++ state.target.token)
    , line ("Due: " ++ state.scheduledOn)
    , line "Expected effects:"
    ] ++
    state.expected.map (fun text => line ("  " ++ text)) ++
    [ line "Cancellation retains explicit retirement evidence; it does not delete the Scheduled occurrence."
    , .row ((["Cancel Scheduled", "Keep"].zipIdx).map fun (label, index) =>
        span ("[" ++ label ++ "] ")
          (if state.choice.val = index then .selected else .normal))
    , line "Tab / arrows select   Enter confirm   Esc keep"
    ]

end Loam.Tui.ScheduledCancellation
