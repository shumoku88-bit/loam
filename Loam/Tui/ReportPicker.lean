import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.ReportDestination
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ReportPicker

open Loam.Tui.Kernel
open Loam.Tui.Runtime
open Loam.Tui.Reports

set_option autoImplicit false

/-!
# In-session report switch picker

A lightweight floating modal to switch between internal reports without exiting
to the root Home screen. Selection and key navigation are presentation concerns only.
-/

structure State where
  selected : Nat := 0
  current : Option Destination := none
  deriving Repr, DecidableEq

def destinations : List Destination := Destination.internalReports

def initial (current : Option Destination := none) : State :=
  let idx := match current with
    | some dest => (destinations.findIdx? (· == dest)).getD 0
    | none => 0
  { selected := idx, current := current }

/--
Pure navigation. Returns:
- `some (some dest)`: confirmed switch to target destination
- `some none`: canceled (close picker and resume parent report)
- `none`: stay in picker (cursor moved)
-/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Option (Option Destination) :=
  match key with
  | .escape | .input 'q' | .input 'Q' | .input ' ' =>
      some none
  | .enter =>
      some (destinations[state.selected]?)
  | .up | .input 'k' | .input 'K' =>
      none
  | .down | .input 'j' | .input 'J' =>
      none
  | .input '1' => some (destinations[0]?)
  | .input '2' => some (destinations[1]?)
  | .input '3' => some (destinations[2]?)
  | .input '4' => some (destinations[3]?)
  | .input '5' => some (destinations[4]?)
  | .input '6' => some (destinations[5]?)
  | .input '7' => some (destinations[6]?)
  | .input '8' => some (destinations[7]?)
  | _ => none

def stepState (state : State) (key : Loam.Tui.Terminal.Key) : State :=
  match key with
  | .up | .input 'k' | .input 'K' =>
      let count := destinations.length
      let next := if state.selected == 0 then count - 1 else state.selected - 1
      { state with selected := next }
  | .down | .input 'j' | .input 'J' =>
      let count := destinations.length
      let next := (state.selected + 1) % count
      { state with selected := next }
  | _ => state

private def floating? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 38 12 50 12

def view (bounds : Bounds) (state : State) : Widget :=
  let rect := floating? bounds
  Loam.Tui.ModalSurface.framedView bounds rect "Switch Report" fun contentBounds =>
    let width := Loam.Tui.Layout.contentWidth contentBounds
    let items := destinations.zipIdx.map fun (dest, idx) =>
      let selected := idx == state.selected
      let marker := if selected then " > " else "   "
      let numStr := toString (idx + 1) ++ ". "
      let isCurrent := some dest == state.current
      let tag := if isCurrent then " (current)" else ""
      let label := marker ++ numStr ++ dest.label ++ tag
      .row [span (Loam.Tui.Layout.padRight (width - 1) label) (if selected then .selected else .normal)]
    let hint := .row [span " ↑/↓ select  1-8 jump  Enter switch  Esc close" .muted]
    .column ([.row [span ""]] ++ items ++ [.row [span ""], hint])

private def renderPanel (bounds : Bounds) (geometry : Option Loam.Tui.ModalSurface.Rectangle)
    (previous next : CompiledWidget) : IO Unit :=
  Loam.Tui.ModalSurface.paint bounds geometry .dirtyDiff previous next

private partial def session (bounds : Bounds)
    (geometry : Option Loam.Tui.ModalSurface.Rectangle)
    (state : State) (frame : CompiledWidget)
    (parentFrame : CompiledWidget) : IO (Option Destination) := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := if active == bounds then geometry else floating? active
  let frame ←
    if active == bounds then pure frame
    else do
      let next := compileWidget (view active state)
      Loam.Tui.Terminal.redrawFromBlank active parentFrame
      Loam.Tui.ModalSurface.paint active geometry .fromBlank (compileWidget (.row [])) next
      pure next
  match update state key with
  | some result => return result
  | none =>
      let next := stepState state key
      if next == state then
        session active geometry state frame parentFrame
      else
        let nextFrame := compileWidget (view active next)
        renderPanel active geometry frame nextFrame
        session active geometry next nextFrame parentFrame

/-- Run the modal picker above the active report screen. -/
def run (bounds : Bounds) (current : Option Destination)
    (parentFrame : CompiledWidget) : IO (Option Destination) := do
  let geometry := floating? bounds
  let state := initial current
  let frame := compileWidget (view bounds state)
  Loam.Tui.ModalSurface.paint bounds geometry .fromBlank (compileWidget (.row [])) frame
  session bounds geometry state frame parentFrame

end Loam.Tui.ReportPicker
