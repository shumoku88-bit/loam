import Std

namespace Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

inductive Style where
  | normal
  | selected
  | muted
  deriving Repr, DecidableEq, BEq

structure Cell where
  glyph : Char
  style : Style
  deriving Repr, DecidableEq, BEq

structure Bounds where
  width : Nat
  height : Nat
  deriving Repr, DecidableEq, BEq

structure Position (bounds : Bounds) where
  row : Fin bounds.height
  col : Fin bounds.width
  deriving DecidableEq

abbrev Screen (bounds : Bounds) := Position bounds → Cell
abbrev Patch (bounds : Bounds) := Position bounds → Option Cell

def blankCell : Cell :=
  { glyph := ' ', style := .normal }

def blankScreen (bounds : Bounds) : Screen bounds :=
  fun _ => blankCell

def applyPatch {bounds : Bounds} (old : Screen bounds) (patch : Patch bounds) : Screen bounds :=
  fun pos =>
    match patch pos with
    | some cell => cell
    | none => old pos

def screenDiff {bounds : Bounds} (old new : Screen bounds) : Patch bounds :=
  fun pos =>
    if old pos = new pos then
      none
    else
      some (new pos)

inductive TerminalOp (bounds : Bounds) where
  | patch (changes : Patch bounds)

def applyOp {bounds : Bounds} (screen : Screen bounds) : TerminalOp bounds → Screen bounds
  | .patch changes => applyPatch screen changes

def applyOps {bounds : Bounds} : Screen bounds → List (TerminalOp bounds) → Screen bounds
  | screen, [] => screen
  | screen, op :: rest => applyOps (applyOp screen op) rest

def diff {bounds : Bounds} (old new : Screen bounds) : List (TerminalOp bounds) :=
  [.patch (screenDiff old new)]

theorem applyPatch_screenDiff {bounds : Bounds} (old new : Screen bounds) :
    applyPatch old (screenDiff old new) = new := by
  funext pos
  by_cases h : old pos = new pos
  · simp [applyPatch, screenDiff, h]
  · simp [applyPatch, screenDiff, h]

theorem applyOps_diff {bounds : Bounds} (old new : Screen bounds) :
    applyOps old (diff old new) = new := by
  simpa [diff, applyOps, applyOp] using applyPatch_screenDiff old new

theorem screenDiff_none_iff {bounds : Bounds} (old new : Screen bounds) (pos : Position bounds) :
    screenDiff old new pos = none ↔ old pos = new pos := by
  simp [screenDiff]

structure Span where
  style : Style
  text : String
  deriving Repr, DecidableEq

inductive Widget where
  | row (spans : List Span)
  | column (children : List Widget)
  deriving Repr

def span (text : String) (style : Style := .normal) : Span :=
  { style, text }

def Span.cells (value : Span) : List Cell :=
  value.text.toList.map fun glyph => { glyph, style := value.style }

def Widget.lines : Widget → List (List Cell)
  | .row spans => [spans.flatMap Span.cells]
  | .column children => children.flatMap Widget.lines

def widgetCellAt (lines : List (List Cell)) (row col : Nat) : Cell :=
  match lines.get? row with
  | none => blankCell
  | some line =>
      match line.get? col with
      | none => blankCell
      | some cell => cell

def Widget.width (widget : Widget) : Nat :=
  widget.lines.foldl (fun current line => max current line.length) 0

def Widget.height (widget : Widget) : Nat :=
  widget.lines.length

def Fits (bounds : Bounds) (top left : Nat) (widget : Widget) : Prop :=
  top + widget.height ≤ bounds.height ∧
    left + widget.width ≤ bounds.width

def renderAt (bounds : Bounds) (top left : Nat) (widget : Widget) : Screen bounds :=
  let lines := widget.lines
  fun pos =>
    if top ≤ pos.row.val ∧ left ≤ pos.col.val then
      widgetCellAt lines (pos.row.val - top) (pos.col.val - left)
    else
      blankCell

end Loam.Prototype.VerifiedTui04.Kernel
