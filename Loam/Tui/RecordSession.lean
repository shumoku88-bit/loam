import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Record
import Loam.Tui.UnresolvedActivation
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.RecordSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Record terminal session

`Record` owns presentation state, validation, and local transition logic.
This module owns the terminal/effect shell for one Record editor session:
read one key at a time, redraw the editor, and delegate the single durable
publication intent to `HouseholdCommand.record`.

It owns no household authority. The caller remains responsible for loading
the selected world before the session and reloading canonical evidence after
a successful publication.
-/

/-- Run one Record editor session and return its human-facing completion notice. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Record.update world known state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Record cancelled."
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enable? root with
    | .error message =>
        let next := {
          step.state with
          mode := Loam.Tui.Record.Mode.editing
          notice := "Unresolved recording was not enabled: " ++ message }
        let nextFrame := compileWidget (Loam.Tui.Record.view known next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root world known next nextFrame
    | .ok enabled =>
        let base := Loam.Tui.Record.withCatalog
          { step.state with mode := Loam.Tui.Record.Mode.editing } enabled.catalog
        let next :=
          match Loam.Tui.Record.fillUnresolvedRemainder? enabled.world base with
          | .ok filled =>
              { filled with
                notice := "Unresolved recording enabled; remainder filled." }
          | .error message =>
              { base with
                notice := "Unresolved recording enabled. " ++ message }
        let nextFrame := compileWidget (Loam.Tui.Record.view enabled.known next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root enabled.world enabled.known next nextFrame
  else
    match step.publish with
    | some intent =>
        let result ←
          match intent with
          | .movement draft =>
              Loam.HouseholdCommand.record root draft
          | .movementWithOriginalAmount draft original =>
              Loam.HouseholdCommand.recordWithOriginalAmount root {
                movement := draft
                originalMeasure := original.measure
                originalQuantity := original.quantity
              }
        match result with
        | .ok eventId => return "Recorded " ++ eventId.token ++ "."
        | .error message =>
            let next := { step.state with mode := Loam.Tui.Record.Mode.editing, notice := message }
            let nextFrame := compileWidget (Loam.Tui.Record.view known next)
            Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
            run bounds root world known next nextFrame
    | none =>
        let nextFrame := compileWidget (Loam.Tui.Record.view known step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root world known step.state nextFrame

end Loam.Tui.RecordSession
