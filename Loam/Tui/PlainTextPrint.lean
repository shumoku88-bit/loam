import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.PlainTextPrint

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Bounded plain-text terminal printing

A shared read-only output boundary for report surfaces. The producer supplies
one logical line per row, not a screenshot or a viewport. Preparation completes
and checks **both** limits before the terminal is touched. There is no partial
print when a report exceeds the limits, no write to household files, and no
clipboard dependency.

Future large collections should offer explicit filtered/ranged producers.
Increasing these limits to emit entire histories is not an escape hatch.
-/

def maxLines : Nat := 200
def maxBytes : Nat := 32768

structure Prepared where
  lines : List String
  lineCount : Nat
  byteCount : Nat
deriving Repr, DecidableEq

/-- Fail closed before constructing one large output string or printing anything. -/
def prepare (lines : List String) : Except String Prepared := Id.run do
  let mut acc : List String := []
  let mut count := 0
  let mut bytes := 0
  for line in lines do
    if count >= maxLines then
      return .error s!"Print refused: more than {maxLines} lines. Narrow the report first."
    let clean := Loam.Tui.Terminal.plainTerminalText line
    let nextBytes := clean.utf8ByteSize + 1
    if nextBytes > maxBytes - bytes then
      return .error s!"Print refused: more than {maxBytes} UTF-8 bytes. Narrow the report first."
    acc := clean :: acc
    count := count + 1
    bytes := bytes + nextBytes
  return .ok { lines := acc.reverse, lineCount := count, byteCount := bytes }

/--
Convert single-line display rows into plain text with a row-count gate *before*
converting the rows. The existing Review presentation owns formatting.
-/
def prepareWidgets (rows : List Widget) : Except String Prepared := do
  if rows.length > maxLines then
    throw s!"Print refused: more than {maxLines} lines. Narrow the report first."
  let mut strings : List String := []
  for widget in rows do
    match widget.lines with
    | [cells] => strings := String.ofList (cells.map (·.glyph)) :: strings
    | _ => throw "Print refused: expected one text row per report line."
  prepare strings.reverse

/--
Leave alternate-screen/raw mouse mode, request explicit permission to put the
sensitive output into persistent terminal scrollback, then return to the TUI.
The caller must redraw its workspace after this returns. No file is created.
-/
def run (label : String) (prepared : Prepared) : IO Unit := do
  Loam.Tui.Terminal.leave
  try
    IO.println ""
    IO.println s!"LOAM / Print view: {label}"
    IO.println s!"Prepared {prepared.lineCount} lines / {prepared.byteCount} UTF-8 bytes (maximum {maxLines} lines / {maxBytes} bytes)."
    IO.println "Note: printed household data may remain in your terminal scrollback."
    IO.print "Print to scrollback? Type y then Enter to confirm [default: no]: "
    (← IO.getStdout).flush
    let answer ← (← IO.getStdin).getLine
    if answer.trimAscii.toString == "y" then
      IO.println ""
      for line in prepared.lines do
        IO.println line
      IO.println ""
      IO.println "End of LOAM report. Select and copy using the terminal."
    else
      IO.println "Print cancelled. No report lines emitted."
    IO.print "Press Enter to return to LOAM: "
    (← IO.getStdout).flush
    let _ ← (← IO.getStdin).getLine
  finally
    Loam.Tui.Terminal.enter

end Loam.Tui.PlainTextPrint
