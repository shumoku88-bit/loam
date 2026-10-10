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

/-- Reload after a publication attempt, including activation's independent policy write. -/
structure Result where
  notice : String
  requiresReload : Bool := false

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

private def caretStyle : Style → Bool
  | .selected | .selectedUnderlined => true
  | _ => false

private def rowCaretColumn? (cells : List Cell) : Option Nat :=
  let rec loop (remaining : List Cell) (col : Nat) (selected : Bool) : Option Nat :=
    match remaining with
    | [] =>
        if selected then some col else none
    | cell :: rest =>
        let nextCol := col + Loam.Tui.Layout.charWidth cell.glyph
        if caretStyle cell.style then
          loop rest nextCol true
        else if selected then
          some col
        else
          loop rest nextCol false
  loop cells 0 false

/--
Locate the end of the first selected run in physical terminal columns.

Record uses selected spans for its active field/action. Keeping this derived from
the rendered frame avoids hard-coding row numbers and preserves correct CJK
column geometry for terminal IME preedit placement.
-/
def focusedCursorPosition?
    (top left : Nat) (frame : CompiledWidget) : Option (Nat × Nat) :=
  let rec loop (rows : List (Array Cell)) (row : Nat) : Option (Nat × Nat) :=
    match rows with
    | [] => none
    | cells :: rest =>
        match rowCaretColumn? cells.toList with
        | some col => some (top + row, left + col)
        | none => loop rest (row + 1)
  loop frame.lines.toList 0

private def placeFocusCursor
    (bounds : Bounds) (surface : Surface) (frame : CompiledWidget) : IO Unit := do
  let (top, left) :=
    match surface with
    | .full => (0, 0)
    | .floating geometry => (geometry.top, geometry.left)
  match focusedCursorPosition? top left frame with
  | none => pure ()
  | some (row, col) =>
      let safeRow := min row (bounds.height - 1)
      let safeCol := min col (Loam.Tui.Layout.contentWidth bounds - 1)
      Loam.Tui.Terminal.placeCursor safeRow safeCol

private def surfaceBounds (bounds : Bounds) (surface : Surface) : Bounds :=
  match surface with
  | .full => bounds
  | .floating geometry => { width := geometry.width - 1, height := geometry.height - 1 }

private def frameFor
    (bounds : Bounds) (surface : Surface) (known : List String)
    (state : Loam.Tui.Record.State) : CompiledWidget :=
  match surface with
  | .full =>
      compileWidget (Loam.Tui.Record.viewForBounds bounds known state)
  | .floating geometry =>
      compileWidget <|
        Loam.Tui.Layout.framedPanel geometry.width geometry.height
          "Record movement" (Loam.Tui.Record.viewForBounds (surfaceBounds bounds surface) known state)

private def redraw
    (bounds : Bounds) (surface : Surface)
    (old new : CompiledWidget) : IO Unit := do
  match surface with
  | .full =>
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 old new
  | .floating geometry =>
      Loam.Tui.Terminal.emitDirtyRegion
        bounds geometry.top geometry.left geometry.width old new
  placeFocusCursor bounds surface new

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
              cells.toList.map (fun cell => span (String.singleton cell.glyph) cell.style))))
    Loam.Tui.Terminal.redrawFromBlank active screen
    placeFocusCursor active nextSurface next
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
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO Result := do
  placeFocusCursor bounds .full frame
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
      placeFocusCursor bounds .full frame
      runWithSurface bounds .full root world known state frame
  | some geometry =>
      let surface := Surface.floating geometry
      let frame := frameFor bounds surface known state
      let blank := compileWidget (.row [])
      Loam.Tui.Terminal.emitDirtyRegion
        bounds geometry.top geometry.left geometry.width blank frame
      placeFocusCursor bounds surface frame
      runWithSurface bounds surface root world known state frame

end Loam.Tui.RecordSession
