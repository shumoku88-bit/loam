import Loam.Prototype.VerifiedTui04.Main

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Main

set_option autoImplicit false

/--
Direct dense rendering retained as the previous optimization specimen.
-/
def denseScreenFor (state : State) : DenseScreen screenBounds :=
  denseRenderAt screenBounds 1 1 (view state)

theorem denseScreenFor_spec (state : State) :
    (denseScreenFor state).toScreen = screenFor state := by
  simpa [denseScreenFor, screenFor] using
    denseRenderAt_spec screenBounds 1 1 (view state)

/--
A widget compiled once to row arrays. Runtime damage detection compares these
rows before touching terminal cells, so ordinary interaction does not need to
build or scan a complete 80x24 DenseScreen.
-/
structure CompiledWidget where
  lines : Array (Array Cell)
  deriving Repr, DecidableEq

def compileWidget (widget : Widget) : CompiledWidget :=
  { lines := widgetArrayLines widget.lines }

def CompiledWidget.rowAt
    (frame : CompiledWidget) (top screenRow : Nat) : Option (Array Cell) :=
  if top ≤ screenRow then
    frame.lines[screenRow - top]?
  else
    none

def compiledRowCell (row : Option (Array Cell)) (col : Nat) : Cell :=
  match row with
  | none => blankCell
  | some line =>
      match line[col]? with
      | none => blankCell
      | some cell => cell

theorem compiledRowCell_spec (lines : List (List Cell)) (row col : Nat) :
    compiledRowCell (widgetArrayLines lines)[row]? col = widgetCellAt lines row col := by
  cases h : lines[row]? with
  | none =>
      simp [compiledRowCell, widgetArrayLines, widgetCellAt, listGet?_eq_getElem?, h]
  | some line =>
      cases hCol : line[col]? <;>
        simp [compiledRowCell, widgetArrayLines, widgetCellAt, listGet?_eq_getElem?, h, hCol]

def CompiledWidget.cellAt {bounds : Bounds}
    (frame : CompiledWidget) (top left : Nat) (pos : Position bounds) : Cell :=
  if left ≤ pos.col.val then
    compiledRowCell (frame.rowAt top pos.row.val) (pos.col.val - left)
  else
    blankCell

def CompiledWidget.toScreen
    (frame : CompiledWidget) (bounds : Bounds) (top left : Nat) : Screen bounds :=
  fun pos => frame.cellAt top left pos

theorem compileWidget_cellAt_spec
    (bounds : Bounds) (top left : Nat) (widget : Widget) (pos : Position bounds) :
    (compileWidget widget).cellAt top left pos = renderAt bounds top left widget pos := by
  by_cases hRow : top ≤ pos.row.val
  · by_cases hCol : left ≤ pos.col.val
    · simp [CompiledWidget.cellAt, CompiledWidget.rowAt, compileWidget, renderAt,
        hRow, hCol, compiledRowCell_spec]
    · simp [CompiledWidget.cellAt, renderAt, hRow, hCol]
  · by_cases hCol : left ≤ pos.col.val
    · simp [CompiledWidget.cellAt, CompiledWidget.rowAt, compiledRowCell, renderAt,
        hRow, hCol]
    · simp [CompiledWidget.cellAt, renderAt, hRow, hCol]

theorem compileWidget_spec
    (bounds : Bounds) (top left : Nat) (widget : Widget) :
    (compileWidget widget).toScreen bounds top left = renderAt bounds top left widget := by
  funext pos
  exact compileWidget_cellAt_spec bounds top left widget pos

/--
A row is damaged exactly when its compiled widget row changed. Structural row
comparison may conservatively mark cells that still render identically, but it
cannot miss a changed cell in that row.
-/
def rowChanged
    (top : Nat) (old new : CompiledWidget) (screenRow : Nat) : Bool :=
  decide (old.rowAt top screenRow ≠ new.rowAt top screenRow)

def dirtyRows
    (bounds : Bounds) (top : Nat) (old new : CompiledWidget) : List (Fin bounds.height) :=
  (List.finRange bounds.height).filter fun row =>
    rowChanged top old new row.val

theorem mem_dirtyRows_iff
    (bounds : Bounds) (top : Nat) (old new : CompiledWidget) (row : Fin bounds.height) :
    row ∈ dirtyRows bounds top old new ↔
      old.rowAt top row.val ≠ new.rowAt top row.val := by
  simp [dirtyRows, rowChanged]

theorem rowChanged_false_cell_eq {bounds : Bounds}
    (top left : Nat) (old new : CompiledWidget) (pos : Position bounds)
    (h : rowChanged top old new pos.row.val = false) :
    old.cellAt top left pos = new.cellAt top left pos := by
  have hRow : old.rowAt top pos.row.val = new.rowAt top pos.row.val := by
    simpa [rowChanged] using h
  by_cases hCol : left ≤ pos.col.val
  · simp [CompiledWidget.cellAt, hCol, hRow]
  · simp [CompiledWidget.cellAt, hCol]

/--
Semantic patch represented by dirty rows. This is specification-only: the
terminal adapter iterates `dirtyRows` directly instead of testing all cells.
-/
def dirtyRowPatch (bounds : Bounds) (top left : Nat)
    (old new : CompiledWidget) : Patch bounds :=
  fun pos =>
    if rowChanged top old new pos.row.val then
      let oldCell := old.cellAt top left pos
      let newCell := new.cellAt top left pos
      if oldCell = newCell then none else some newCell
    else
      none

/--
Redrawing only structurally changed compiled rows reconstructs the same screen
as a complete redraw.
-/
theorem applyPatch_dirtyRowPatch
    (bounds : Bounds) (top left : Nat) (old new : CompiledWidget) :
    applyPatch (old.toScreen bounds top left) (dirtyRowPatch bounds top left old new) =
      new.toScreen bounds top left := by
  funext pos
  cases hRow : rowChanged top old new pos.row.val with
  | false =>
      have hCell := rowChanged_false_cell_eq top left old new pos hRow
      simp [applyPatch, dirtyRowPatch, CompiledWidget.toScreen, hRow, hCell]
  | true =>
      by_cases hCell : old.cellAt top left pos = new.cellAt top left pos
      · simp [applyPatch, dirtyRowPatch, CompiledWidget.toScreen, hRow, hCell]
      · simp [applyPatch, dirtyRowPatch, CompiledWidget.toScreen, hRow, hCell]

def compiledFrameFor (state : State) : CompiledWidget :=
  compileWidget (view state)

theorem compiledFrameFor_spec (state : State) :
    (compiledFrameFor state).toScreen screenBounds 1 1 = screenFor state := by
  simpa [compiledFrameFor, screenFor] using
    compileWidget_spec screenBounds 1 1 (view state)

/--
Emit only rows whose compiled widget representation changed. Inside those rows
we still compare cells, so conservative row damage does not produce unnecessary
glyph writes. One event is emitted as one stdout write.
-/
def emitDirtyDiff (old new : CompiledWidget) : IO Unit := do
  let mut output := ""
  for row in dirtyRows screenBounds 1 old new do
    for col in List.finRange screenBounds.width do
      let pos : Position screenBounds := { row, col }
      let oldCell := old.cellAt 1 1 pos
      let newCell := new.cellAt 1 1 pos
      if oldCell = newCell then
        pure ()
      else
        output := output ++
          cursorTo row.val col.val ++
          ansiStyle newCell.style ++
          toString newCell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

partial def loopDirty
    (state : State)
    (frame : CompiledWidget) : IO Unit := do
  let event := keyEvent (← readKey)
  let step := update state event
  if step.quit then
    return
  let nextFrame := compiledFrameFor step.state
  emitDirtyDiff frame nextFrame
  loopDirty step.state nextFrame

def run : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let frame := compiledFrameFor state
    let blank := compileWidget (.row [])
    emitDirtyDiff blank frame
    loopDirty state frame
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui04.FastCli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui04.FastCli.run
