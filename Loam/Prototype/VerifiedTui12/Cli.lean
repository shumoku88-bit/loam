import Loam.Prototype.VerifiedTui04.Runtime
import Loam.Prototype.VerifiedTui12.Main
import Std

namespace Loam.Prototype.VerifiedTui12.Cli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Runtime
open Loam.Prototype.VerifiedTui12.Main

set_option autoImplicit false

def compiledFrameFor (state : State) : CompiledWidget :=
  compileWidget (view state)

theorem compiledFrameFor_spec (state : State) :
    (compiledFrameFor state).toScreen screenBounds 1 1 = screenFor state := by
  simpa [compiledFrameFor, screenFor] using
    compileWidget_spec screenBounds 1 1 (view state)

def ansiStyle : Style → String
  | .normal => "\x1b[0m"
  | .selected => "\x1b[30;46m"
  | .muted => "\x1b[2m"

def cursorTo (row col : Nat) : String :=
  "\x1b[" ++ toString (row + 1) ++ ";" ++ toString (col + 1) ++ "H"

/-- Same sparse-row lowering shape previously used by calendar and review. -/
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
        output := output ++ cursorTo row.val col.val ++ ansiStyle newCell.style ++ toString newCell.glyph
  IO.print (output ++ "\x1b[0m")
  (← IO.getStdout).flush

def readByte : IO UInt8 := do
  let bytes ← (← IO.getStdin).read 1
  if bytes.isEmpty then
    return 0
  return bytes.get! 0

/--
Small local terminal decoder. It deliberately supports ASCII editing only; UTF-8
input, mouse, bracketed paste, and a general key-event framework are not earned by
this experiment.
-/
def readEvent (state : State) : IO Event := do
  let first ← readByte
  let value := first.toNat
  if value = 27 then
    let second ← readByte
    let third ← readByte
    if second.toNat = 91 then
      match third.toNat with
      | 65 => return .up
      | 66 => return .down
      | 90 => return .shiftTab
      | _ => return .other
    else
      return .other
  else if value = 17 then
    return .quit
  else if value = 9 then
    return .tab
  else if value = 10 || value = 13 then
    return .enter
  else if value = 8 || value = 127 then
    return .backspace
  else if state.mode == .preview && (value = 101 || value = 69) then
    return .edit
  else if state.mode == .preview && (value = 98 || value = 66) then
    return .back
  else if state.mode == .preview && (value = 113 || value = 81) then
    return .quit
  else if 32 ≤ value then
    if value ≤ 126 then
      return .input (Char.ofNat value)
    else
      return .other
  else
    return .other

def setTerminalMode (mode : String) : IO Unit := do
  discard <| IO.Process.run
    { cmd := "sh"
      args := #["-c", "stty " ++ mode ++ " < /dev/tty"] }

def enterTerminal : IO Unit := do
  setTerminalMode "-echo -icanon min 1 time 0"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leaveTerminal : IO Unit := do
  IO.print "\x1b[0m\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

partial def loop (state : State) (frame : CompiledWidget) : IO Unit := do
  let event ← readEvent state
  let step := update state event
  if step.quit then
    return
  let nextFrame := compiledFrameFor step.state
  emitDirtyDiff frame nextFrame
  loop step.state nextFrame

def run : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let frame := compiledFrameFor state
    let blank := compileWidget (.row [])
    emitDirtyDiff blank frame
    loop state frame
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui12.Cli

def main : IO Unit :=
  Loam.Prototype.VerifiedTui12.Cli.run