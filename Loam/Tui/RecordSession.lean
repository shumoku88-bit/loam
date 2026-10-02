import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Layout
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

structure FloatingGeometry where
  top : Nat
  left : Nat
  width : Nat
  height : Nat
  deriving Repr, DecidableEq, BEq

/--
Use a centered Record panel only when enough terminal room remains around the
complete bounded editor. Smaller terminals keep the historical full-screen
surface instead of hiding controls.
-/
def floatingGeometry? (bounds : Bounds) : Option FloatingGeometry :=
  let available := Loam.Tui.Layout.contentWidth bounds
  if available < 78 ∨ bounds.height < 35 then
    none
  else
    let width := min 88 (available - 4)
    let height := 33
    some {
      top := (bounds.height - height) / 2
      left := (available - width) / 2
      width := width
      height := height
    }

private inductive Surface where
  | full
  | floating (geometry : FloatingGeometry)

private def frameFor
    (surface : Surface) (known : List String)
    (state : Loam.Tui.Record.State) : CompiledWidget :=
  match surface with
  | .full =>
      compileWidget (Loam.Tui.Record.view known state)
  | .floating geometry =>
      compileWidget <|
        Loam.Tui.Layout.framedPanel geometry.width geometry.height
          "Record movement" (Loam.Tui.Record.view known state)

private def redraw
    (bounds : Bounds) (surface : Surface)
    (old new : CompiledWidget) : IO Unit :=
  match surface with
  | .full =>
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 old new
  | .floating geometry =>
      Loam.Tui.Terminal.emitDirtyRegion
        bounds geometry.top geometry.left geometry.width old new

private partial def runWithSurface
    (bounds : Bounds) (surface : Surface)
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Record.update world known state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Record cancelled."
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enableEditor? root step.state with
    | .error message =>
        let next := Loam.Tui.UnresolvedActivation.withEnableError step.state message
        let nextFrame := frameFor surface known next
        redraw bounds surface frame nextFrame
        runWithSurface bounds surface root world known next nextFrame
    | .ok enabled =>
        let nextFrame := frameFor surface enabled.known enabled.editor
        redraw bounds surface frame nextFrame
        runWithSurface bounds surface root enabled.world enabled.known enabled.editor nextFrame
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
            let next := {
              step.state with
              mode := Loam.Tui.Record.Mode.editing
              notice := message
            }
            let nextFrame := frameFor surface known next
            redraw bounds surface frame nextFrame
            runWithSurface bounds surface root world known next nextFrame
    | none =>
        let nextFrame := frameFor surface known step.state
        redraw bounds surface frame nextFrame
        runWithSurface bounds surface root world known step.state nextFrame

/-- Run one Record editor session and return its human-facing completion notice. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO String :=
  runWithSurface bounds .full root world known state frame

/--
Open Record over the currently visible surface when the terminal is large enough.
Otherwise retain the historical full-screen editor. The caller still redraws its
fresh destination after Record completes.
-/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (background : CompiledWidget) : IO String := do
  match floatingGeometry? bounds with
  | none =>
      let frame := frameFor .full known state
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 background frame
      runWithSurface bounds .full root world known state frame
  | some geometry =>
      let surface := Surface.floating geometry
      let frame := frameFor surface known state
      let blank := compileWidget (.row [])
      Loam.Tui.Terminal.emitDirtyRegion
        bounds geometry.top geometry.left geometry.width blank frame
      runWithSurface bounds surface root world known state frame

end Loam.Tui.RecordSession
