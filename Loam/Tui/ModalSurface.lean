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

end Loam.Tui.ModalSurface
