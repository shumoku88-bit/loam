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
  IO.print "\x1b[2J"
  emitDirtyDiff bounds 0 0 (compileWidget (.row [])) frame

private def readByte : IO UInt8 := do
  let bytes ← (← IO.getStdin).read 1
  if bytes.isEmpty then return 0
  return bytes.get! 0

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
    | 60 =>
        let (payload, active) ← readSgrMousePayload 32 ""
        if active then
          return decodeSgrMousePayload payload
        else
          return .other
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

/--
Enable or disable button-motion reporting. Unlike all-pointer-motion, this emits
motion only while a mouse button is held, which supports drag/scrub interaction
without turning ordinary hover into selection.
-/
def setButtonMotion (enabled : Bool) : IO Unit := do
  IO.print (if enabled then "\x1b[?1002h" else "\x1b[?1002l")
  (← IO.getStdout).flush

def enter : IO Unit := do
  setTerminalMode "-echo -icanon min 0 time 1"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[?1000h\x1b[?1006h\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leave : IO Unit := do
  IO.print "\x1b[0m\x1b[?1003l\x1b[?1002l\x1b[?1006l\x1b[?1000l\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

end Loam.Tui.Terminal
