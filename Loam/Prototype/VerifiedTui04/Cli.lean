import Loam.Prototype.VerifiedTui04.Main

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Main

set_option autoImplicit false

/--
Lower a dense frame diff to one stdout write.

The semantic Screen remains the specification. Each rendered semantic frame is
materialized once into fixed-size vectors; subsequent diff lookup is O(1) per
cell and does not re-run the old/new Screen functions while emitting the patch.
`denseDiffAt_materialize` proves that each dense diff cell agrees with the
semantic `screenDiff` cell.
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
  let nextScreen := materialize (screenFor step.state)
  emitDenseDiff screen nextScreen
  loopFast step.state nextScreen

def run : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let screen := materialize (screenFor state)
    let blank := materialize (blankScreen screenBounds)
    emitDenseDiff blank screen
    loopFast state screen
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui04.FastCli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui04.FastCli.run
