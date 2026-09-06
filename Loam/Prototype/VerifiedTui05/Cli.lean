import Loam.Prototype.VerifiedTui04.Main
import Loam.Prototype.VerifiedTui04.Runtime
import Loam.Prototype.VerifiedTui05.Main

namespace Loam.Prototype.VerifiedTui05.Cli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Runtime
open Loam.Prototype.VerifiedTui05.Main

set_option autoImplicit false

def compiledFrameFor (state : State) : CompiledWidget :=
  compileWidget (view state)

theorem compiledFrameFor_spec (state : State) :
    (compiledFrameFor state).toScreen screenBounds 1 1 = screenFor state := by
  simpa [compiledFrameFor, screenFor] using
    compileWidget_spec screenBounds 1 1 (view state)

def keyEvent : Loam.Prototype.VerifiedTui04.Main.Key → Event
  | .up => .up
  | .down => .down
  | .enter => .enter
  | .back => .back
  | .quit => .quit
  | _ => .other

/--
Use the same compiled-row damage mechanics as Prototype 04. The terminal byte
reader and ANSI lowering remain external mechanics; the review state/update/view
are independent from the calendar state machine.
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
          Loam.Prototype.VerifiedTui04.Main.cursorTo row.val col.val ++
          Loam.Prototype.VerifiedTui04.Main.ansiStyle newCell.style ++
          toString newCell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

partial def loop
    (state : State)
    (frame : CompiledWidget) : IO Unit := do
  let event := keyEvent (← Loam.Prototype.VerifiedTui04.Main.readKey)
  let step := update state event
  if step.quit then
    return
  let nextFrame := compiledFrameFor step.state
  emitDirtyDiff frame nextFrame
  loop step.state nextFrame

def run : IO Unit := do
  Loam.Prototype.VerifiedTui04.Main.enterTerminal
  try
    let state := initialState
    let frame := compiledFrameFor state
    let blank := compileWidget (.row [])
    emitDirtyDiff blank frame
    loop state frame
  finally
    Loam.Prototype.VerifiedTui04.Main.leaveTerminal

end Loam.Prototype.VerifiedTui05.Cli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui05.Cli.run
