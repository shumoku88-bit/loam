import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.HomeCommandPalette

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
A small, temporary command chooser for budget-related administration.
This presentation-only palette never publishes household data. Its selections
delegate to the existing Home session entries and their validated publishers.
-/

inductive Choice where
  | budget
  | capacity
  | purposeRouting
  deriving Repr, DecidableEq

private def choices : List (Choice × String) :=
  [ (.budget, "Budget / current cycle")
  , (.capacity, "Capacity / allocations")
  , (.purposeRouting, "Purpose routing")
  ]

def choiceAt? (selected : Nat) : Option Choice :=
  (choices[selected]?).map (·.1)

def next (selected : Nat) (back : Bool) : Nat :=
  let limit := choices.length - 1
  if back then selected - 1 else min limit (selected + 1)

def view (bounds : Bounds) (selected : Nat) : Widget :=
  let lines :=
    choices.zipIdx.map fun ((_, title), index) =>
      let prefix := if selected == index then "  > " else "    "
      .row [span (prefix ++ title) (if selected == index then .selected else .normal)]
  let body : Widget := .column <|
    [ .row [span " Home / Commands"]
    , .row [span " Budget features are optional."]
    , .row []
    ] ++ lines ++
    [ .row []
    , .row [span " ↑/↓ select  Enter open  Esc cancel" .muted] ]
  Loam.Tui.Layout.framedPanel
    (min 54 (Loam.Tui.Layout.contentWidth bounds))
    (min 11 bounds.height) "Commands" body

private def floating? (bounds : Bounds) : Option (Nat × Nat × Nat × Nat) :=
  let available := Loam.Tui.Layout.contentWidth bounds
  if available < 64 || bounds.height < 18 then
    none
  else
    let width := min 54 (available - 4)
    let height := 11
    some ((bounds.height - height) / 2,
      (available - width) / 2, width, height)

private def renderPanel
    (bounds : Bounds) (geometry : Option (Nat × Nat × Nat × Nat))
    (old next : CompiledWidget) : IO Unit := do
  match geometry with
  | some (top, left, width, _) =>
      Loam.Tui.Terminal.emitDirtyRegion bounds top left width old next
  | none =>
      Loam.Tui.Terminal.redrawFromBlank bounds next

/-- Run a short-lived modal chooser. All keys not selected are ignored. -/
private partial def session
    (bounds : Bounds) (geometry : Option (Nat × Nat × Nat × Nat))
    (selected : Nat) (frame : CompiledWidget) : IO (Option Choice) := do
  let key ← Loam.Tui.Terminal.readKey
  match key with
  | .escape | .input 'q' | .input 'Q' | .input ' ' => return none
  | .enter => return choiceAt? selected
  | _ =>
      let nextSelected :=
        match key with
        | .up | .input 'k' | .input 'K' => next selected true
        | .down | .input 'j' | .input 'J' => next selected false
        | _ => selected
      if nextSelected == selected then
        session bounds geometry selected frame
      else
        let nextFrame := compileWidget (view bounds nextSelected)
        renderPanel bounds geometry frame nextFrame
        session bounds geometry nextSelected nextFrame

/-- Prefer a floating panel above Home; use full-width on small terminals. -/
def run (bounds : Bounds) : IO (Option Choice) := do
  let geometry := floating? bounds
  let frame := compileWidget (view bounds 0)
  match geometry with
  | some (top, left, width, _) =>
      Loam.Tui.Terminal.emitDirtyRegion bounds top left width
        (compileWidget (.row [])) frame
  | none =>
      Loam.Tui.Terminal.redrawFromBlank bounds frame
  session bounds geometry 0 frame

end Loam.Tui.HomeCommandPalette
