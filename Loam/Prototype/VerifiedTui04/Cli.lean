import Loam.Prototype.VerifiedTui04.Main

namespace Loam.Prototype.VerifiedTui04.FastCli

open Loam.Prototype.VerifiedTui04.Kernel
namespace Prototype := Loam.Prototype.VerifiedTui04.Main

set_option autoImplicit false

/--
Lower one semantic patch to a single stdout write.

The first dogfood run exposed visible input-to-redraw lag in the cell-at-a-time
adapter. Keep the verified Screen/diff semantics unchanged and batch only the
external ANSI lowering here so the experiment can distinguish kernel cost from
terminal I/O cost.
-/
def emitPatch (changes : Patch Prototype.screenBounds) : IO Unit := do
  let mut output := ""
  for row in List.finRange Prototype.screenBounds.height do
    for col in List.finRange Prototype.screenBounds.width do
      let pos : Position Prototype.screenBounds := { row, col }
      match changes pos with
      | none => pure ()
      | some cell =>
          output := output ++
            Prototype.cursorTo row.val col.val ++
            Prototype.ansiStyle cell.style ++
            toString cell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

def emitOps (ops : List (TerminalOp Prototype.screenBounds)) : IO Unit := do
  for op in ops do
    match op with
    | .patch changes => emitPatch changes

partial def loop
    (state : Prototype.State)
    (screen : Screen Prototype.screenBounds) : IO Unit := do
  let event := Prototype.keyEvent (← Prototype.readKey)
  let step := Prototype.update state event
  if step.quit then
    return
  let nextScreen := Prototype.screenFor step.state
  emitOps (diff screen nextScreen)
  loop step.state nextScreen

def run : IO Unit := do
  Prototype.enterTerminal
  try
    let state := Prototype.initialState
    let screen := Prototype.screenFor state
    emitOps (diff (blankScreen Prototype.screenBounds) screen)
    loop state screen
  finally
    Prototype.leaveTerminal

end Loam.Prototype.VerifiedTui04.FastCli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui04.FastCli.run
