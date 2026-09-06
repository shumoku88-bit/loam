import Loam.Prototype.VerifiedTui04.Main

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Main

set_option autoImplicit false

/--
Lower one semantic patch to a single stdout write.

The first dogfood run exposed visible input-to-redraw lag in the cell-at-a-time
adapter. Keep the verified Screen/diff semantics unchanged and batch only the
external ANSI lowering here so the experiment can distinguish kernel cost from
terminal I/O cost.
-/
def emitPatchFast (changes : Patch screenBounds) : IO Unit := do
  let mut output := ""
  for row in List.finRange screenBounds.height do
    for col in List.finRange screenBounds.width do
      let pos : Position screenBounds := { row, col }
      match changes pos with
      | none => pure ()
      | some cell =>
          output := output ++
            cursorTo row.val col.val ++
            ansiStyle cell.style ++
            toString cell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

def emitOpsFast (ops : List (TerminalOp screenBounds)) : IO Unit := do
  for op in ops do
    match op with
    | .patch changes => emitPatchFast changes

partial def loopFast (state : State) (screen : Screen screenBounds) : IO Unit := do
  let event := keyEvent (← readKey)
  let step := update state event
  if step.quit then
    return
  let nextScreen := screenFor step.state
  emitOpsFast (diff screen nextScreen)
  loopFast step.state nextScreen

def run : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let screen := screenFor state
    emitOpsFast (diff (blankScreen screenBounds) screen)
    loopFast state screen
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui04.FastCli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui04.FastCli.run
