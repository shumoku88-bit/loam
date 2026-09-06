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

abbrev DenseScreen (bounds : Bounds) :=
  Vector (Vector Cell bounds.width) bounds.height

def DenseScreen.cellAt {bounds : Bounds}
    (screen : DenseScreen bounds) (pos : Position bounds) : Cell :=
  (screen[pos.row.val]'pos.row.isLt)[pos.col.val]'pos.col.isLt

def DenseScreen.toScreen {bounds : Bounds}
    (screen : DenseScreen bounds) : Screen bounds :=
  fun pos => screen.cellAt pos

def materialize {bounds : Bounds} (screen : Screen bounds) : DenseScreen bounds :=
  Vector.ofFn fun row =>
    Vector.ofFn fun col =>
      screen { row, col }

theorem cellAt_materialize {bounds : Bounds} (screen : Screen bounds) (pos : Position bounds) :
    (materialize screen).cellAt pos = screen pos := by
  simp [DenseScreen.cellAt, materialize]

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

def denseDiffAt {bounds : Bounds}
    (old new : DenseScreen bounds) (pos : Position bounds) : Option Cell :=
  let oldCell := old.cellAt pos
  let newCell := new.cellAt pos
  if oldCell = newCell then none else some newCell

theorem denseDiffAt_materialize {bounds : Bounds}
    (old new : Screen bounds) (pos : Position bounds) :
    denseDiffAt (materialize old) (materialize new) pos = screenDiff old new pos := by
  simp [denseDiffAt, screenDiff, cellAt_materialize]

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

def listGet? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | value :: _, 0 => some value
  | _ :: rest, index + 1 => listGet? rest index

theorem listGet?_eq_getElem? {α : Type} (values : List α) (index : Nat) :
    listGet? values index = values[index]? := by
  induction values generalizing index with
  | nil => simp [listGet?]
  | cons value rest ih =>
      cases index with
      | zero => simp [listGet?]
      | succ index => simp [listGet?, ih]

def widgetCellAt (lines : List (List Cell)) (row col : Nat) : Cell :=
  match listGet? lines row with
  | none => blankCell
  | some line =>
      match listGet? line col with
      | none => blankCell
      | some cell => cell

def widgetArrayLines (lines : List (List Cell)) : Array (Array Cell) :=
  (lines.map List.toArray).toArray

def widgetCellAtArray (lines : Array (Array Cell)) (row col : Nat) : Cell :=
  match lines[row]? with
  | none => blankCell
  | some line =>
      match line[col]? with
      | none => blankCell
      | some cell => cell

theorem widgetCellAtArray_spec (lines : List (List Cell)) (row col : Nat) :
    widgetCellAtArray (widgetArrayLines lines) row col = widgetCellAt lines row col := by
  cases h : lines[row]? with
  | none =>
      simp [widgetCellAtArray, widgetArrayLines, widgetCellAt, listGet?_eq_getElem?, h]
  | some line =>
      simp [widgetCellAtArray, widgetArrayLines, widgetCellAt, listGet?_eq_getElem?, h]

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

def denseRenderAt (bounds : Bounds) (top left : Nat) (widget : Widget) : DenseScreen bounds :=
  let lines := widget.lines
  let arrayLines := widgetArrayLines lines
  Vector.ofFn fun row =>
    Vector.ofFn fun col =>
      if top ≤ row.val ∧ left ≤ col.val then
        widgetCellAtArray arrayLines (row.val - top) (col.val - left)
      else
        blankCell

theorem cellAt_denseRenderAt
    (bounds : Bounds) (top left : Nat) (widget : Widget) (pos : Position bounds) :
    (denseRenderAt bounds top left widget).cellAt pos = renderAt bounds top left widget pos := by
  simp [denseRenderAt, DenseScreen.cellAt, renderAt, widgetCellAtArray_spec]

theorem denseRenderAt_spec
    (bounds : Bounds) (top left : Nat) (widget : Widget) :
    (denseRenderAt bounds top left widget).toScreen = renderAt bounds top left widget := by
  funext pos
  exact cellAt_denseRenderAt bounds top left widget pos

end Loam.Prototype.VerifiedTui04.Kernel