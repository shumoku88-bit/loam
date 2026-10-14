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

Opt-in editors use selected spans for their active text field. Selection alone
does not imply text editing: the session must disable its caret on actions and
confirmation screens. Geometry is derived from the same frame that was painted.
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

/-- A stale or clipped field cannot anchor composition in unrelated parent cells. -/
def textCaretPosition? (bounds : Bounds) (rectangle : Option Rectangle)
    (editing : Bool) (frame : CompiledWidget) : Option (Nat × Nat) := do
  if !editing then none else do
    let (top, left, width, height) := match rectangle with
      | none => (0, 0, Loam.Tui.Layout.contentWidth bounds, bounds.height)
      | some region => (region.top, region.left, region.width, region.height)
    let (row, col) ← focusedCursorPosition? top left frame
    if row < min bounds.height (top + height) &&
        col < min (Loam.Tui.Layout.contentWidth bounds) (left + width) then
      some (row, col)
    else none

/-- Browsing, confirmation and painting keep the hardware cursor hidden. -/
def hideTextCaret : IO Unit := do
  IO.print "\x1b[?25l"
  (← IO.getStdout).flush

/--
Opt-in text editors restore the physical insertion anchor after painting.
Check live bounds again: layout and output may straddle a tty resize.
This anchors terminal/OS IME presentation; it does not render preedit itself.
-/
def placeTextCaret (bounds : Bounds) (rectangle : Option Rectangle)
    (editing : Bool) (frame : CompiledWidget) : IO Unit := do
  let live ← Loam.Tui.Terminal.currentBounds
  let visible := { width := min bounds.width live.width,
                   height := min bounds.height live.height : Bounds }
  match textCaretPosition? visible rectangle editing frame with
  | none => hideTextCaret
  | some (row, col) =>
      Loam.Tui.Terminal.placeCursor row col
      IO.print "\x1b[?25h"
      (← IO.getStdout).flush

/-- Restore browsing policy on cancel, success, refusal exit or exception. -/
def withTextCaret {α : Type} (action : IO α) : IO α := do
  try action finally hideTextCaret

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

/-- Start a floating or compact editor using the pre-existing paint policy.
    Same-sized entrants paint only their modal region; a resized entrance
    restores the fresh parent before overlaying the editor. The parent callback
    stays lazy, so no parent frame is compiled when it cannot be displayed. -/
def paintEntrance (previous current : Bounds) (rectangle : Option Rectangle)
    (parent : Bounds → CompiledWidget) (content : CompiledWidget) : IO Unit := do
  if current == previous then
    paint current rectangle .fromBlank (compileWidget (.row [])) content
  else
    repaintOverParent current rectangle (parent current) content

end Loam.Tui.ModalSurface
