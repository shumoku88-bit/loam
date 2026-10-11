import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ModalSurface

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Shared modal surface geometry and painting

A modal's position and redraw policy are presentation concerns, independent of
its editor state, keyboard grammar, review, or publication authority. Keep the
caller responsible for input handling and for redrawing its parent after exit.
-/

/-- Physical rectangle occupied by a floating modal, in terminal cells. -/
structure Rectangle where
  top : Nat
  left : Nat
  width : Nat
  height : Nat
  deriving Repr, DecidableEq, BEq

/--
Center a panel with a four-column horizontal margin only when the terminal
meets the caller's minimum dimensions. Otherwise select the compact/full-screen
fallback by returning none. The caller owns the panel's actual content height.
-/
def centered? (bounds : Bounds)
    (minimumContentWidth minimumHeight maximumPanelWidth panelHeight : Nat) :
    Option Rectangle :=
  let usable := Loam.Tui.Layout.contentWidth bounds
  if usable < minimumContentWidth || bounds.height < minimumHeight ||
      usable < 4 || panelHeight > bounds.height then
    none
  else
    let width := min maximumPanelWidth (usable - 4)
    if width == 0 then
      none
    else
      some {
        top := (bounds.height - panelHeight) / 2
        left := (usable - width) / 2
        width := width
        height := panelHeight
      }

/-- Inner editor bounds of an optional floating frame; compact keeps full bounds. -/
def contentBounds (bounds : Bounds) (rectangle : Option Rectangle) : Bounds :=
  match rectangle with
  | none => bounds
  | some region => { width := region.width - 1, height := region.height - 1 }

/-- Share only modal framing, without owning local state, input, or publication. -/
def framedView (bounds : Bounds) (rectangle : Option Rectangle)
    (title : String) (inner : Bounds → Widget) : Widget :=
  match rectangle with
  | none => inner bounds
  | some region =>
      Loam.Tui.Layout.framedPanel region.width region.height title
        (inner (contentBounds bounds (some region))) true

/--
Existing full-screen callers have different redraw policies: rich editors
retain dirty-diff painting; the command palette clears the compact surface.
No generic editor loop or publisher is introduced here.
-/
inductive FullScreenPaint where
  | dirtyDiff
  | fromBlank

/-- Paint the floating rectangle or delegate to the caller's compact policy. -/
def paint (bounds : Bounds) (rectangle : Option Rectangle)
    (full : FullScreenPaint) (old next : CompiledWidget) : IO Unit := do
  match rectangle with
  | some region =>
      Loam.Tui.Terminal.emitDirtyRegion
        bounds region.top region.left region.width old next
  | none =>
      match full with
      | .dirtyDiff => Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 old next
      | .fromBlank => Loam.Tui.Terminal.redrawFromBlank bounds next


/--
After a terminal resize, reconstruct the visible parent before painting a new
floating region. Otherwise the old floating rectangle can remain stranded at
its previous coordinates, or the surrounding parent can be left blank.
Compact/full-screen mode owns every visible cell instead.
-/
def repaintOverParent (bounds : Bounds) (rectangle : Option Rectangle)
    (parent content : CompiledWidget) : IO Unit := do
  match rectangle with
  | none =>
      Loam.Tui.Terminal.redrawFromBlank bounds content
  | some region =>
      Loam.Tui.Terminal.redrawFromBlank bounds parent
      paint bounds (some region) .dirtyDiff (compileWidget (.row [])) content

end Loam.Tui.ModalSurface
