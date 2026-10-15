import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
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

/-- Reload after a publication attempt, including activation's independent policy write. -/
structure Result where
  notice : String
  requiresReload : Bool := false

abbrev FloatingGeometry := Loam.Tui.ModalSurface.Rectangle

/--
Use a centered Record panel only when enough terminal room remains around the
complete bounded editor. Compact terminals retain the full-screen surface.
-/
def floatingGeometry? (bounds : Bounds) : Option FloatingGeometry :=
  Loam.Tui.ModalSurface.centered? bounds 78 35 88 33

private inductive Surface where
  | full
  | floating (geometry : FloatingGeometry)


private def surfaceBounds (bounds : Bounds) (surface : Surface) : Bounds :=
  match surface with
  | .full => bounds
  | .floating geometry => { width := geometry.width - 1, height := geometry.height - 1 }

/-- Floating Record uses the existing focused-frame accent without changing form geometry. -/
def floatingRecordView
    (geometry : FloatingGeometry) (known : List String)
    (state : Loam.Tui.Record.State) : Widget :=
  let inner : Bounds := { width := geometry.width - 1, height := geometry.height - 1 }
  Loam.Tui.Layout.framedPanel geometry.width geometry.height
    "Record movement" (Loam.Tui.Record.viewForBounds inner known state) true

private def frameFor
    (bounds : Bounds) (surface : Surface) (known : List String)
    (state : Loam.Tui.Record.State) : CompiledWidget :=
  match surface with
  | .full =>
      compileWidget (Loam.Tui.Record.viewForBounds bounds known state)
  | .floating geometry =>
      compileWidget (floatingRecordView geometry known state)

private def redraw
    (bounds : Bounds) (surface : Surface)
    (old new : CompiledWidget) : IO Unit := do
  let geometry? := match surface with
    | .full => none
    | .floating geometry => some geometry
  Loam.Tui.ModalSurface.paint bounds geometry? .dirtyDiff old new

private partial def runWithSurface
    (bounds : Bounds) (surface : Surface)
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget)
    (requiresReload : Bool := false) : IO Result := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let (bounds, surface, frame) ← if active == bounds then pure (bounds, surface, frame) else do
    let nextSurface := match surface with
      | .full => Surface.full
      | .floating _ => match floatingGeometry? active with
          | some geometry => Surface.floating geometry
          | none => Surface.full
    let next := frameFor active nextSurface known state
    let screen := match nextSurface with
      | .full => next
      | .floating geometry => compileWidget (.column (
          List.replicate geometry.top (.row []) ++
          next.lines.toList.map fun cells =>
            Widget.row ([span (Loam.Tui.Layout.padRight geometry.left "")] ++
              cells.toList.map Cell.toSpan)))
    Loam.Tui.Terminal.redrawFromBlank active screen
    pure (active, nextSurface, next)
  -- A short-read timeout carries no editing intent. Keep the compiled frame and
  -- caret instead of rebuilding the editor and emitting a cursor move every tick.
  if key == .other then
    return (← runWithSurface bounds surface root world known state frame requiresReload)
  let limit := Loam.Tui.Record.previewScrollLimit (surfaceBounds bounds surface) state
  let state := { state with previewScroll := min state.previewScroll limit }
  let step := match Loam.Tui.Record.scrollPreview (surfaceBounds bounds surface) state key with
    | some next => { state := next : Loam.Tui.Record.Step }
    | none => Loam.Tui.Record.update world known state key
  if step.cancel then return { notice := "Record cancelled.", requiresReload := requiresReload }
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enableEditor? root step.state with
    | .error message =>
        let next := Loam.Tui.UnresolvedActivation.withEnableError step.state message
        let nextFrame := frameFor bounds surface known next
        redraw bounds surface frame nextFrame
        -- Activation can publish policy before its subsequent reload fails.
        runWithSurface bounds surface root world known next nextFrame true
    | .ok enabled =>
        let nextFrame := frameFor bounds surface enabled.known enabled.editor
        redraw bounds surface frame nextFrame
        runWithSurface bounds surface root enabled.world enabled.known enabled.editor nextFrame true
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
        | .ok eventId => return {
            notice := "Recorded " ++ eventId.token ++ "."
            requiresReload := true }
        | .error message =>
            let next := {
              step.state with
              mode := Loam.Tui.Record.Mode.editing
              notice := message
            }
            let nextFrame := frameFor bounds surface known next
            redraw bounds surface frame nextFrame
            -- Keep the conservative reload after any attempted publication.
            runWithSurface bounds surface root world known next nextFrame true
    | none =>
        let nextFrame := frameFor bounds surface known step.state
        redraw bounds surface frame nextFrame
        runWithSurface bounds surface root world known step.state nextFrame requiresReload

/-- Run one Record editor session and return its human-facing completion notice. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO Result :=
  runWithSurface bounds .full root world known state frame

/--
Open Record over the currently visible surface when the terminal is large enough.
Otherwise retain the historical full-screen editor. The caller still redraws its
fresh destination after Record completes.
-/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (background : CompiledWidget) : IO Result := do
  match floatingGeometry? bounds with
  | none =>
      let frame := frameFor bounds .full known state
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 background frame
      runWithSurface bounds .full root world known state frame
  | some geometry =>
      let surface := Surface.floating geometry
      let frame := frameFor bounds surface known state
      let blank := compileWidget (.row [])
      Loam.Tui.ModalSurface.paint bounds (some geometry) .dirtyDiff blank frame
      runWithSurface bounds surface root world known state frame

end Loam.Tui.RecordSession
