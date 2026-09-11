import Loam.Tui.Kernel
import Loam.Tui.Layout
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
  | ctrl (char : Char)
  | input (char : Char)
  | other
  deriving Repr, DecidableEq

def ansiStyle : Style → String
  | .normal => "\x1b[0m"
  | .selected => "\x1b[0;30;46m"
  | .muted => "\x1b[0;2m"
  | .underlined => "\x1b[0;4;36m"
  | .selectedUnderlined => "\x1b[0;4;30;46m"

def cursorTo (row col : Nat) : String :=
  "\x1b[" ++ toString (row + 1) ++ ";" ++ toString (col + 1) ++ "H"

/--
Emit only structurally changed rows. The semantic reconstruction theorem remains
in `Loam.Tui.Runtime`; ANSI and terminal glyph advance are the physical boundary.
Rows are clipped by physical terminal columns before emission so a long surface
line can never arm terminal auto-wrap and spill into the following TUI row.
-/
def emitDirtyDiff (bounds : Bounds) (top left : Nat)
    (old new : CompiledWidget) : IO Unit := do
  let mut output := ""
  let available := Loam.Tui.Layout.contentWidth bounds - left
  for row in dirtyRows bounds top old new do
    output := output ++ cursorTo row.val left
    match new.rowAt top row.val with
    | none => pure ()
    | some cells =>
        for cell in Loam.Tui.Layout.clipCells available cells.toList do
          output := output ++ ansiStyle cell.style ++ toString cell.glyph
    output := output ++ "\x1b[0m\x1b[K"
  IO.print output
  (← IO.getStdout).flush

/-- Clear the physical screen and redraw one compiled frame from an empty structural baseline. -/
def redrawFromBlank (bounds : Bounds) (frame : CompiledWidget) : IO Unit := do
  IO.print "\x1b[2J"
  emitDirtyDiff bounds 0 0 (compileWidget (.row [])) frame

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
  else if value > 0 && value < 32 then
    return .ctrl (Char.ofNat (value + 96))
  else if value = 0 then
    return .other
  else if 126 < value then
    let count := if value >= 194 && value <= 223 then 2
      else if value <= 239 && value >= 224 then 3
      else if value <= 244 && value >= 240 then 4 else 0
    if count = 0 then return .other
    let mut bytes := ByteArray.empty.push first
    for _ in List.range (count - 1) do
      bytes := bytes.push (← readByte)
    match String.fromUTF8? bytes with
    | some text =>
        match text.toList with
        | [char] => return .input char
        | _ => return .other
    | none => return .other
  else
    return .input (Char.ofNat value)

private def fallbackBounds : Bounds := { width := 80, height := 24 }

/--
Read the active tty geometry. The physical terminal owns this fact; callers use
it only as presentation geometry. Failure falls back to the historical 80×24
viewport rather than changing household semantics.
-/
def currentBounds : IO Bounds := do
  try
    let output ← IO.Process.output {
      cmd := "sh"
      args := #["-c", "stty size < /dev/tty"]
    }
    if output.exitCode != 0 then return fallbackBounds
    let text := output.stdout.trimAsciiEnd.toString.trimAsciiStart.toString
    let parts := (text.splitOn " ").filter fun part => !part.isEmpty
    match parts with
    | [rowsText, colsText] =>
        match rowsText.toNat?, colsText.toNat? with
        | some rows, some cols =>
            if rows = 0 || cols = 0 then return fallbackBounds
            return { width := cols, height := rows }
        | _, _ => return fallbackBounds
    | _ => return fallbackBounds
  catch _ =>
    return fallbackBounds

def setTerminalMode (mode : String) : IO Unit := do
  discard <| IO.Process.run
    { cmd := "sh"
      args := #["-c", "stty " ++ mode ++ " < /dev/tty"] }

def enter : IO Unit := do
  setTerminalMode "-echo -icanon min 0 time 1"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leave : IO Unit := do
  IO.print "\x1b[0m\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

end Loam.Tui.Terminal
