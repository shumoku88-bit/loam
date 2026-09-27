import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.SettlementAction
import Loam.Tui.Terminal

namespace Loam.Tui.SettlementActionSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Run one friendly settlement action editor.

The session owns terminal effects only. The editor emits a small human-intent
draft; HouseholdCommand delegates identity allocation, canonical re-read,
append-only translation, admission, and atomic publication to the shared
SettlementActionPublisher.
-/
partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.SettlementAction.State)
    (frame : CompiledWidget) : IO String := do
  let step :=
    Loam.Tui.SettlementAction.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    return "Settlement action cancelled."

  match step.publish with
  | some (.correctAmount draft) =>
      match ← Loam.HouseholdCommand.correctSettlementAmount root draft with
      | .ok _ =>
          return "Settlement amount updated."
      | .error message =>
          let next := Loam.Tui.SettlementAction.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.SettlementAction.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root next nextFrame

  | some (.retract draft) =>
      match ← Loam.HouseholdCommand.retractSettlement root draft with
      | .ok () =>
          return "Settlement record marked as erroneous."
      | .error message =>
          let next := Loam.Tui.SettlementAction.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.SettlementAction.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root next nextFrame

  | some (.reduceWithoutPayment draft) =>
      match ← Loam.HouseholdCommand.reduceSettlementWithoutPayment root draft with
      | .ok _ =>
          return "Remaining amount reduced by " ++
            toString draft.quantity.quanta ++ " without payment."
      | .error message =>
          let next := Loam.Tui.SettlementAction.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.SettlementAction.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root next nextFrame

  | none =>
      let nextFrame := compileWidget (Loam.Tui.SettlementAction.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root step.state nextFrame

end Loam.Tui.SettlementActionSession
