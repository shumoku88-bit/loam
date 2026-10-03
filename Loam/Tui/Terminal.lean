import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime

namespace Loam.Tui.Terminal

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-- Normalized terminal input. Surface-specific meaning stays in the pure TUI update function. -/
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
  | paste (text : String)
  | pageUp
  | pageDown
  | home
  | «end»
  | delete
  /-- Zero-based pointer press coordinate. Surfaces decide whether it is actionable. -/
  | pointer (col row : Nat)
  /-- Zero-based pointer motion while the primary button remains pressed. -/
  | pointerDrag (col row : Nat)
  /-- Zero-based passive pointer motion with no button pressed. -/
  | pointerMotion (col row : Nat)
  | other
  deriving Repr, DecidableEq

def ansiStyle : Style → String
  | .normal => "\x1b[0m"
  | .selected => "\x1b[0;30;46m"
  | .muted => "\x1b[0;2m"
  | .underlined => "\x1b[0;4;36m"
  | .selectedUnderlined => "\x1b[0;4;30;46m"
  | .series1 => "\x1b[0;36m"
  | .series2 => "\x1b[0;33m"
  | .series3 => "\x1b[0;35m"
  | .series4 => "\x1b[0;32m"
  | .series5 => "\x1b[0;31m"

def cursorTo (row col : Nat) : String :=
  "\x1b[" ++ toString (row + 1) ++ ";" ++ toString (col + 1) ++ "H"

/-- Move the terminal's logical cursor without changing any rendered cells. -/
def placeCursor (row col : Nat) : IO Unit := do
  IO.print (cursorTo row col)
  (← IO.getStdout).flush

private def sameStyleRun
    (style : Style) (chars : List Char) (remaining : List Cell)
    (acc : List Span) : List Span :=
  match remaining with
  | [] =>
      (span (String.ofList chars.reverse) style :: acc).reverse
  | cell :: rest =>
      if cell.style == style then
        sameStyleRun style (cell.glyph :: chars) rest acc
      else
        sameStyleRun
          cell.style [cell.glyph] rest
          (span (String.ofList chars.reverse) style :: acc)

/-- Coalesce adjacent cells that share one terminal style into semantic text runs. -/
def cellsToStyleRuns (cells : List Cell) : List Span :=
  match cells with
  | [] => []
  | first :: rest =>
      sameStyleRun first.style [first.glyph] rest []

/--
Render one already-clipped terminal row with one ANSI style prefix per contiguous
style run rather than one prefix per glyph.
-/
def renderCellsAnsi (cells : List Cell) : String :=
  let chunks :=
    (cellsToStyleRuns cells).map fun run =>
      ansiStyle run.style ++ run.text
  String.intercalate "" chunks

/--
Recover Widget rows without lowering semantic spans to per-glyph Cells.

This is the thin path used by the Reports direct renderer experiment.
-/
def widgetSpanLines : Widget → List (List Span)
  | .row spans => [spans]
  | .column children => children.flatMap widgetSpanLines

private def clipSpanLine : List Span → Nat → List Span
  | [], _ => []
  | _, 0 => []
  | run :: rest, remaining =>
      let clipped := Loam.Tui.Layout.clip remaining run.text
      let clippedWidth := Loam.Tui.Layout.displayWidth clipped
      let fullWidth := Loam.Tui.Layout.displayWidth run.text
      let current :=
        if clipped.isEmpty then []
        else [{ run with text := clipped }]
      if clippedWidth < fullWidth then
        current
      else
        current ++ clipSpanLine rest (remaining - clippedWidth)

/-- Render one semantic Widget row directly from styled spans. -/
def renderSpansAnsi (columns : Nat) (spans : List Span) : String :=
  let chunks :=
    (clipSpanLine spans columns).map fun run =>
      ansiStyle run.style ++ run.text
  String.intercalate "" chunks

/--
Build one complete visible terminal frame directly from Widget spans.

Unlike the normal renderer this performs no Cell expansion, CompiledWidget
construction, previous-frame comparison, or dirty-row discovery. Every physical
row is overwritten and cleared, matching the deliberately simple full-redraw
shape used for the Reports renderer experiment.
-/
def directFrameAnsi (bounds : Bounds) (widget : Widget) : String :=
  let rows := widgetSpanLines widget
  let available := Loam.Tui.Layout.contentWidth bounds
  String.intercalate "" <|
    (List.range bounds.height).map fun row =>
      let content :=
        match rows[row]? with
        | none => ""
        | some spans => renderSpansAnsi available spans
      cursorTo row 0 ++ content ++ "\x1b[0m\x1b[K"

/-- Overwrite the complete visible terminal from semantic Widget spans. -/
def redrawWidgetDirect (bounds : Bounds) (widget : Widget) : IO Unit := do
  IO.print (directFrameAnsi bounds widget)
  (← IO.getStdout).flush

private def dirtyRowAnsi
    (bounds : Bounds) (top left : Nat)
    (new : CompiledWidget) (row : Fin bounds.height) : String :=
  let available := Loam.Tui.Layout.contentWidth bounds - left
  let content :=
    match new.rowAt top row.val with
    | none => ""
    | some cells =>
        renderCellsAnsi <| Loam.Tui.Layout.clipCells available cells.toList
  cursorTo row.val left ++ content ++ "\x1b[0m\x1b[K"


private def regionCellsWidth (cells : List Cell) : Nat :=
  cells.foldl (fun width cell => width + Loam.Tui.Layout.charWidth cell.glyph) 0

/--
Build ANSI for structurally changed rows inside one fixed-width region.

Unlike the full-row dirty renderer, this deliberately does not clear to the
physical end of line. The caller owns a rectangular overlay and therefore only
that many terminal columns may be replaced.
-/
def dirtyRegionAnsi
    (bounds : Bounds) (top left width : Nat)
    (old new : CompiledWidget) : String :=
  let available := min width (Loam.Tui.Layout.contentWidth bounds - left)
  String.intercalate "" <|
    (dirtyRows bounds top old new).map fun row =>
      let clipped :=
        match new.rowAt top row.val with
        | none => []
        | some cells =>
            Loam.Tui.Layout.clipCells available cells.toList
      let padding :=
        String.ofList (List.replicate (available - regionCellsWidth clipped) ' ')
      cursorTo row.val left ++
        renderCellsAnsi clipped ++
        "\x1b[0m" ++ padding

/-- Emit only the changed rows of one fixed-width overlay rectangle. -/
def emitDirtyRegion
    (bounds : Bounds) (top left width : Nat)
    (old new : CompiledWidget) : IO Unit := do
  IO.print (dirtyRegionAnsi bounds top left width old new)
  (← IO.getStdout).flush

/--
Emit only structurally changed rows. The semantic reconstruction theorem remains
in `Loam.Tui.Runtime`; ANSI and terminal glyph advance are the physical boundary.
Rows are clipped by physical terminal columns before emission so a long surface
line can never arm terminal auto-wrap and spill into the following TUI row.
-/
def emitDirtyDiff (bounds : Bounds) (top left : Nat)
    (old new : CompiledWidget) : IO Unit := do
  let output :=
    String.intercalate "" <|
      (dirtyRows bounds top old new).map fun row =>
        dirtyRowAnsi bounds top left new row
  IO.print output
  (← IO.getStdout).flush

/-- Clear the physical screen and redraw one compiled frame from an empty structural baseline. -/
def redrawFromBlank (bounds : Bounds) (frame : CompiledWidget) : IO Unit := do
  IO.print "\x1b[2J\x1b[H"
  emitDirtyDiff bounds 0 0 (compileWidget (.row [])) frame

/--
Extract clean plain text from a compiled terminal frame.
Strips trailing whitespace from each line and drops trailing empty lines at the
bottom of the frame to produce clean, token-efficient text for external sharing.
-/
def compiledWidgetToCleanText (frame : CompiledWidget) : String :=
  let lines := frame.lines.map fun row =>
    let chars := row.toList.map (·.glyph)
    (String.ofList chars).trimAsciiEnd.toString
  let trimmed := lines.toList.reverse.dropWhile String.isEmpty |>.reverse
  String.intercalate "\n" trimmed

/-- Extract clean plain text from an uncompiled Widget. -/
def widgetToCleanText (widget : Widget) : String :=
  compiledWidgetToCleanText (compileWidget widget)

/--
Write plain text to the system clipboard.
Tries macOS `pbcopy` first, then Linux `wl-copy` and `xclip`.
Returns `true` if a clipboard command succeeded, or `false` on failure.
-/
def copyToClipboard (text : String) : IO Bool := do
  let tryCommand (cmd : String) (args : Array String) : IO Bool := do
    try
      let child ← IO.Process.spawn {
        cmd := cmd
        args := args
        stdin := .piped
        stdout := .null
        stderr := .null
      }
      let (stdin, child) ← child.takeStdin
      stdin.putStr text
      stdin.flush
      let exitCode ← child.wait
      return exitCode == 0
    catch _ =>
      return false

  if ← tryCommand "pbcopy" #[] then
    return true
  if ← tryCommand "wl-copy" #[] then
    return true
  if ← tryCommand "xclip" #["-selection", "clipboard"] then
    return true
  return false

structure InputBuffer where
  data : ByteArray := ByteArray.empty
  pos  : Nat := 0
deriving Inhabited

initialize inputBufferRef : IO.Ref InputBuffer ← IO.mkRef {}

/-- Reset any buffered terminal input bytes. -/
def resetInputBuffer : IO Unit := do
  inputBufferRef.set {}

private def readByte : IO UInt8 := do
  let state ← inputBufferRef.get
  if state.pos < state.data.size then
    let b := state.data.get! state.pos
    inputBufferRef.set { state with pos := state.pos + 1 }
    return b
  let bytes ← (← IO.getStdin).read 1024
  if bytes.isEmpty then
    inputBufferRef.set { data := ByteArray.empty, pos := 0 }
    return 0
  let b := bytes.get! 0
  inputBufferRef.set { data := bytes, pos := 1 }
  return b

private def parseNatFromBytes (buf : ByteArray) (start : Nat) (stop : Nat) : Option Nat :=
  if start >= stop then none
  else
    let rec loop (i : Nat) (acc : Nat) : Option Nat :=
      if i >= stop then some acc
      else
        let b := buf.get! i
        if b >= 48 && b <= 57 then
          loop (i + 1) (acc * 10 + (b.toNat - 48))
        else
          none
    loop start 0

private def findByteIndex (buf : ByteArray) (start : Nat) (target : UInt8) : Option Nat :=
  let rec loop (i : Nat) : Option Nat :=
    if i >= buf.size then none
    else if buf.get! i == target then some i
    else loop (i + 1)
  loop start

/--
Attempt to parse one SGR mouse sequence at the given position in `buf`.
Format: `\x1b[<button;col;rowM`
Returns `some (button, nextPos)` if a valid SGR press packet was matched, or `none`.
-/
def parseSgrMousePacket? (buf : ByteArray) (pos : Nat) : Option (Nat × Nat) := do
  if pos + 6 > buf.size then none
  if buf.get! pos != 27 then none
  if buf.get! (pos + 1) != 91 then none
  if buf.get! (pos + 2) != 60 then none
  let semi1 ← findByteIndex buf (pos + 3) 59
  let button ← parseNatFromBytes buf (pos + 3) semi1
  let semi2 ← findByteIndex buf (semi1 + 1) 59
  let _col ← parseNatFromBytes buf (semi1 + 1) semi2
  let rec findTerm (i : Nat) : Option (UInt8 × Nat) :=
    if i >= buf.size then none
    else
      let b := buf.get! i
      if b == 77 || b == 109 then some (b, i)
      else if b >= 48 && b <= 57 then findTerm (i + 1)
      else none
  let (term, termPos) ← findTerm (semi2 + 1)
  if term != 77 then none
  let _row ← parseNatFromBytes buf (semi2 + 1) termPos
  return (button, termPos + 1)

/-- Drain consecutive SGR mouse packets matching `targetButton` starting at `pos`. -/
def drainMatchingWheel (buf : ByteArray) (pos : Nat) (targetButton : Nat) : Nat × Nat :=
  let rec loop (currPos : Nat) (count : Nat) (fuel : Nat) : Nat × Nat :=
    match fuel with
    | 0 => (currPos, count)
    | fuel + 1 =>
        match parseSgrMousePacket? buf currPos with
        | some (btn, nextPos) =>
            if btn == targetButton && nextPos > currPos then
              loop nextPos (count + 1) fuel
            else
              (currPos, count)
        | none => (currPos, count)
  loop pos 0 (buf.size - pos)

/--
Drain any immediate consecutive wheel scroll events matching the given direction
from the buffered input queue without waiting for more input.
Returns the total number of additional events drained (0 if no consecutive wheel events).
-/
def drainPendingWheel (direction : Key) : IO Nat := do
  let targetButton :=
    match direction with
    | .up => 64
    | .down => 65
    | .left => 66
    | .right => 67
    | _ => 0
  if targetButton == 0 then return 0
  let state ← inputBufferRef.get
  if state.pos >= state.data.size then return 0
  let (newPos, count) := drainMatchingWheel state.data state.pos targetButton
  if count > 0 then
    inputBufferRef.set { state with pos := newPos }
  return count

/--
Normalize one SGR mouse payload (the bytes after CSI `<` and before `M`/`m`).
Plain wheel motion becomes the same directional input as keyboard Up/Down so
surface-specific scrolling and selection policy remains caller-owned.
-/
def decodeSgrMousePayload (payload : String) : Key :=
  match payload.splitOn ";" with
  | [buttonText, colText, rowText] =>
      match buttonText.toNat?, colText.toNat?, rowText.toNat? with
      | some 64, _, _ => .up
      | some 65, _, _ => .down
      | some 66, _, _ => .left
      | some 67, _, _ => .right
      | some button, some col, some row =>
          if col = 0 || row = 0 then
            .other
          else if button = 0 then
            .pointer (col - 1) (row - 1)
          else if button = 32 then
            .pointerDrag (col - 1) (row - 1)
          else if button = 35 then
            .pointerMotion (col - 1) (row - 1)
          else
            .other
      | _, _, _ => .other
  | _ => .other

/--
Read one SGR mouse packet body and retain whether the terminal marked it as a
press/motion (`M`) rather than a release (`m`).
-/
private def readSgrMousePayload : Nat → String → IO (String × Bool)
  | 0, acc => pure (acc, false)
  | Nat.succ fuel, acc => do
      let byte ← readByte
      let value := byte.toNat
      if value = 0 then
        return (acc, false)
      else if value = 77 then
        return (acc, true)
      else if value = 109 then
        return (acc, false)
      else
        readSgrMousePayload fuel (acc.push (Char.ofNat value))

/-- Apply one normalized Backspace edit to presentation-local text. -/
def backspaceText (text : String) : String :=
  String.ofList text.toList.dropLast

/-- Normalize CRLF and CR to LF in pasted text. -/
def normalizePasteText (text : String) : String :=
  text.replace "\r\n" "\n" |>.replace "\r" "\n"

/-- Extract the first line of pasted text for single-line input fields. -/
def singleLinePaste (text : String) : String :=
  match (normalizePasteText text).splitOn "\n" with
  | [] => ""
  | line :: _ => line.trimAsciiEnd.toString

/-- Read remaining bytes of a bracketed paste payload until `\x1b[201~` is encountered. -/
private def readBracketedPastePayload (fuel : Nat) (acc : ByteArray) : IO String := do
  match fuel with
  | 0 => pure (String.fromUTF8? acc |>.getD "")
  | Nat.succ nextFuel =>
      let b ← readByte
      if b == 0 then
        pure (String.fromUTF8? acc |>.getD "")
      else if b == 27 then
        let b2 ← readByte
        if b2 == 0 then
          pure (String.fromUTF8? (acc.push 27) |>.getD "")
        else if b2 == 91 then
          let b3 ← readByte
          if b3 == 0 then
            pure (String.fromUTF8? (acc.push 27 |>.push 91) |>.getD "")
          else if b3 == 50 then
            let b4 ← readByte
            if b4 == 0 then
              pure (String.fromUTF8? (acc.push 27 |>.push 91 |>.push 50) |>.getD "")
            else if b4 == 48 then
              let b5 ← readByte
              if b5 == 0 then
                pure (String.fromUTF8? (acc.push 27 |>.push 91 |>.push 50 |>.push 48) |>.getD "")
              else if b5 == 49 then
                let b6 ← readByte
                if b6 == 126 then
                  pure (String.fromUTF8? acc |>.getD "")
                else if b6 == 0 then
                  pure (String.fromUTF8? (acc.push 27 |>.push 91 |>.push 50 |>.push 48 |>.push 49) |>.getD "")
                else
                  let acc' := acc.push 27 |>.push 91 |>.push 50 |>.push 48 |>.push 49 |>.push b6
                  readBracketedPastePayload nextFuel acc'
              else
                let acc' := acc.push 27 |>.push 91 |>.push 50 |>.push 48 |>.push b5
                readBracketedPastePayload nextFuel acc'
            else
              let acc' := acc.push 27 |>.push 91 |>.push 50 |>.push b4
              readBracketedPastePayload nextFuel acc'
          else
            let acc' := acc.push 27 |>.push 91 |>.push b3
            readBracketedPastePayload nextFuel acc'
        else
          let acc' := acc.push 27 |>.push b2
          readBracketedPastePayload nextFuel acc'
      else
        readBracketedPastePayload nextFuel (acc.push b)

/-- Read remaining bytes of one CSI parameter sequence until the terminating letter or `~`. -/
private def readCsiPayload (fuel : Nat) (acc : String) : IO (String × Nat) :=
  match fuel with
  | 0 => pure (acc, 0)
  | Nat.succ nextFuel => do
      let byte ← readByte
      let value := byte.toNat
      if value = 0 then
        return (acc, 0)
      else if value >= 64 && value <= 126 then
        return (acc, value)
      else
        readCsiPayload nextFuel (acc.push (Char.ofNat value))

/-- Decode ANSI CSI parameter and terminating character into normalized Key. -/
def decodeCsi (param : String) (finalByte : Nat) : Key :=
  if finalByte == 126 then
    if param == "5" || param.startsWith "5;" then .pageUp
    else if param == "6" || param.startsWith "6;" then .pageDown
    else if param == "3" || param.startsWith "3;" then .delete
    else if param == "1" || param == "7" || param.startsWith "1;" then .home
    else if param == "4" || param == "8" || param.startsWith "4;" then .«end»
    else .other
  else if finalByte == 72 then .home
  else if finalByte == 70 then .«end»
  else if finalByte == 65 then .up
  else if finalByte == 66 then .down
  else if finalByte == 67 then .right
  else if finalByte == 68 then .left
  else if finalByte == 90 then .shiftTab
  else .other

/-- Small input decoder shared by all production TUI surfaces. -/
def readKey : IO Key := do
  let first ← readByte
  let value := first.toNat
  if value = 27 then
    let second ← readByte
    let secondVal := second.toNat
    if secondVal = 79 then
      let third ← readByte
      match third.toNat with
      | 72 => return .home
      | 70 => return .«end»
      | 65 => return .up
      | 66 => return .down
      | 67 => return .right
      | 68 => return .left
      | _ => return .other
    else if secondVal != 91 then
      return .escape
    let third ← readByte
    let thirdVal := third.toNat
    if thirdVal = 60 then
      let (payload, active) ← readSgrMousePayload 32 ""
      if active then
        return decodeSgrMousePayload payload
      else
        return .other
    else if thirdVal >= 64 && thirdVal <= 126 then
      return decodeCsi "" thirdVal
    else if thirdVal > 0 then
      let (param, finalByte) ← readCsiPayload 16 (String.singleton (Char.ofNat thirdVal))
      if param == "200" && finalByte == 126 then
        let text ← readBracketedPastePayload 65536 ByteArray.empty
        return .paste (normalizePasteText text)
      else
        return decodeCsi param finalByte
    else
      return .other
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

/-- Read one normalized Key, draining any immediately queued identical wheel scroll events. -/
def readKeyWithRepeat : IO (Key × Nat) := do
  let key ← readKey
  let extra ← drainPendingWheel key
  return (key, 1 + extra)

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

/--
Enable or disable button-motion reporting. Unlike all-pointer-motion, this emits
motion only while a mouse button is held, which supports drag/scrub interaction
without turning ordinary hover into selection.
-/
def setButtonMotion (enabled : Bool) : IO Unit := do
  IO.print (if enabled then "\x1b[?1002h" else "\x1b[?1002l")
  (← IO.getStdout).flush

def enter : IO Unit := do
  resetInputBuffer
  setTerminalMode "-echo -icanon min 0 time 1"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[?1000h\x1b[?1006h\x1b[?2004h\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leave : IO Unit := do
  resetInputBuffer
  IO.print "\x1b[0m\x1b[?2004l\x1b[?1003l\x1b[?1002l\x1b[?1006l\x1b[?1000l\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

end Loam.Tui.Terminal
