import Loam.Prototype.VerifiedTui04.Main
import Loam.Prototype.VerifiedTui04.Runtime

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Main
open Loam.Prototype.VerifiedTui04.Runtime

set_option autoImplicit false

/-- Direct dense rendering retained as the previous optimization specimen. -/
def denseScreenFor (state : State) : DenseScreen screenBounds :=
  denseRenderAt screenBounds 1 1 (view state)

theorem denseScreenFor_spec (state : State) :
    (denseScreenFor state).toScreen = screenFor state := by
  simpa [denseScreenFor, screenFor] using
    denseRenderAt_spec screenBounds 1 1 (view state)

/-- The calendar surface compiled through the shared sparse runtime. -/
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
