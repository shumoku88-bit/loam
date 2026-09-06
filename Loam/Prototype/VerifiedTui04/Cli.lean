import Loam.Prototype.VerifiedTui04.Main

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Main

set_option autoImplicit false

/--
Direct runtime rendering for the current LOAM prototype surface.

The semantic `screenFor` remains the specification. The executable path instead
compiles the same Widget directly to a fixed-size dense frame, avoiding the old
per-cell recursive List lookup and the intermediate semantic Screen evaluation.
-/
def denseScreenFor (state : State) : DenseScreen screenBounds :=
  denseRenderAt screenBounds 1 1 (view state)

theorem denseScreenFor_spec (state : State) :
    (denseScreenFor state).toScreen = screenFor state := by
  simpa [denseScreenFor, screenFor] using
    denseRenderAt_spec screenBounds 1 1 (view state)

/--
Lower a dense frame diff to one stdout write.

The semantic Screen remains the specification. Runtime frames are rendered
directly to fixed-size vectors, and diff lookup is O(1) per cell. The generic
`denseRenderAt_spec` theorem and this module's `denseScreenFor_spec` keep that
runtime path tied to the semantic renderer.
-/
def emitDenseDiff
    (old new : DenseScreen screenBounds) : IO Unit := do
  let mut output := ""
  for row in List.finRange screenBounds.height do
    for col in List.finRange screenBounds.width do
      let pos : Position screenBounds := { row, col }
      match denseDiffAt old new pos with
      | none => pure ()
      | some cell =>
          output := output ++
            cursorTo row.val col.val ++
            ansiStyle cell.style ++
            toString cell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

partial def loopFast
    (state : State)
    (screen : DenseScreen screenBounds) : IO Unit := do
  let event := keyEvent (← readKey)
  let step := update state event
  if step.quit then
    return
  let nextScreen := denseScreenFor step.state
  emitDenseDiff screen nextScreen
  loopFast step.state nextScreen

def run : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let screen := denseScreenFor state
    let blank := materialize (blankScreen screenBounds)
    emitDenseDiff blank screen
    loopFast state screen
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui04.FastCli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui04.FastCli.run
