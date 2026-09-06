import Loam.Tui.Kernel
import Loam.Tui.Runtime

namespace Loam.Tui.Terminal

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-- Raw terminal input. Surface-specific meaning stays in the pure TUI update function. -/
inductive Key where
  | left
  | right
  | up
  | down
  | tab
  | shiftTab
  | enter
  | backspace
  | escape
  | input (char : Char)
  | other
  deriving Repr, DecidableEq

def ansiStyle : Style → String
  | .normal => "\x1b[0m"
  | .selected => "\x1b[30;46m"
  | .muted => "\x1b[2m"

def cursorTo (row col : Nat) : String :=
  "\x1b[" ++ toString (row + 1) ++ ";" ++ toString (col + 1) ++ "H"

/--
Emit only structurally changed rows. The semantic reconstruction theorem remains
in `Loam.Tui.Runtime`; ANSI and terminal glyph advance are the physical boundary.
-/
def emitDirtyDiff (bounds : Bounds) (top left : Nat)
    (old new : CompiledWidget) : IO Unit := do
  let mut output := ""
  for row in dirtyRows bounds top old new do
    output := output ++ cursorTo row.val left
    match new.rowAt top row.val with
    | none => pure ()
    | some cells =>
        for cell in cells do
          output := output ++ ansiStyle cell.style ++ toString cell.glyph
    output := output ++ "\x1b[0m\x1b[K"
  IO.print output
  (← IO.getStdout).flush

private def readByte : IO UInt8 := do
  let bytes ← (← IO.getStdin).read 1
  if bytes.isEmpty then return 0
  return bytes.get! 0

/-- Small input decoder shared by all production TUI surfaces. -/
def readKey : IO Key := do
  let first ← readByte
  let value := first.toNat
  if value = 27 then
    let second ← readByte
    if second.toNat != 91 then
      return .escape
    let third ← readByte
    match third.toNat with
    | 65 => return .up
    | 66 => return .down
    | 67 => return .right
    | 68 => return .left
    | 90 => return .shiftTab
    | _ => return .other
  else if value = 9 then
    return .tab
  else if value = 10 ∨ value = 13 then
    return .enter
  else if value = 8 ∨ value = 127 then
    return .backspace
  else if value < 32 then
    return .other
  else if 126 < value then
    return .other
  else
    return .input (Char.ofNat value)

def setTerminalMode (mode : String) : IO Unit := do
  discard <| IO.Process.run
    { cmd := "sh"
      args := #["-c", "stty " ++ mode ++ " < /dev/tty"] }

def enter : IO Unit := do
  setTerminalMode "-echo -icanon min 1 time 0"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leave : IO Unit := do
  IO.print "\x1b[0m\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

end Loam.Tui.Terminal
