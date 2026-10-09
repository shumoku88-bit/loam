import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.HomeCommandPalette

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
A short-lived, hierarchical command chooser. Pages and selection are presentation
state only: leaf choices delegate to the existing Home session entries and their
validated publishers. The palette never reads or publishes household data.
-/

inductive Choice where
  | budget
  | capacity
  | purposeRouting
  deriving Repr, DecidableEq

inductive Page where
  | commands
  | envelopeBudget
  deriving Repr, DecidableEq

structure State where
  page : Page := .commands
  selected : Nat := 0
  deriving Repr, DecidableEq

private inductive Entry where
  | page (target : Page)
  | action (choice : Choice)

private def entries : Page → List (Entry × String)
  | .commands => [(.page .envelopeBudget, "Envelope budget →")]
  | .envelopeBudget =>
      [ (.action .budget, "Budget / current cycle")
      , (.action .capacity, "Capacity / allocations")
      , (.action .purposeRouting, "Purpose routing")
      ]

inductive Transition where
  | stay (state : State)
  | open (choice : Choice)
  | close
  deriving Repr, DecidableEq

/-- Pure navigation; only a leaf can request an existing workspace. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Transition :=
  match key with
  | .left | .escape | .input 'q' | .input 'Q' | .input ' ' =>
      match state.page with
      | .commands => .close
      | .envelopeBudget => .stay {}
  | .right =>
      match (entries state.page)[state.selected]? with
      | some (.page target, _) => .stay { page := target }
      | _ => .stay state
  | .enter =>
      match (entries state.page)[state.selected]? with
      | some (.page target, _) => .stay { page := target }
      | some (.action choice, _) => .open choice
      | none => .stay state
  | .up | .input 'k' | .input 'K' =>
      .stay { state with selected := state.selected - 1 }
  | .down | .input 'j' | .input 'J' =>
      .stay { state with selected := min (entries state.page).length.pred (state.selected + 1) }
  | _ => .stay state

def view (bounds : Bounds) (state : State) : Widget :=
  let panelWidth := min 54 (Loam.Tui.Layout.contentWidth bounds)
  let lines :=
    (entries state.page).zipIdx.map fun ((_, title), index) =>
      let markerText := if state.selected == index then "  > " else "    "
      -- Keep the background beyond the final glyph, including arrow overhang.
      let text := Loam.Tui.Layout.padRight (panelWidth - 2) (markerText ++ title)
      .row [span text (if state.selected == index then .selected else .normal)]
  let (path, description, backLabel) :=
    match state.page with
    | .commands => (" Home / Commands", " Choose a command group.", "Esc close")
    | .envelopeBudget =>
        (" Commands / Envelope budget", " Budget features are optional.", "Esc back")
  let body : Widget := .column <|
    [ .row [span path]
    , .row [span description]
    , .row []
    ] ++ lines ++
    [ .row []
    , .row [span " ↑/↓ select  → group  ← back" .muted]
    , .row [span (" Enter open  " ++ backLabel) .muted] ]
  Loam.Tui.Layout.framedPanel
    panelWidth (min 11 bounds.height) "Commands" body

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

/-- Run a short-lived modal chooser. Unhandled keys leave navigation unchanged. -/
private partial def session
    (bounds : Bounds) (geometry : Option (Nat × Nat × Nat × Nat))
    (state : State) (frame : CompiledWidget) : IO (Option Choice) := do
  let key ← Loam.Tui.Terminal.readKey
  match update state key with
  | .close => return none
  | .open choice => return some choice
  | .stay next =>
      if next == state then
        session bounds geometry state frame
      else
        let nextFrame := compileWidget (view bounds next)
        renderPanel bounds geometry frame nextFrame
        session bounds geometry next nextFrame

/-- Prefer a floating panel above Home; use full-width on small terminals. -/
def run (bounds : Bounds) : IO (Option Choice) := do
  let geometry := floating? bounds
  let state : State := {}
  let frame := compileWidget (view bounds state)
  match geometry with
  | some (top, left, width, _) =>
      Loam.Tui.Terminal.emitDirtyRegion bounds top left width
        (compileWidget (.row [])) frame
  | none =>
      Loam.Tui.Terminal.redrawFromBlank bounds frame
  session bounds geometry state frame

end Loam.Tui.HomeCommandPalette
