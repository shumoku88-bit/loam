import Loam.Tui.Kernel

namespace Loam.Tui.Layout

open Loam.Tui.Kernel
set_option autoImplicit false

private def inRange (value lower upper : Nat) : Bool :=
  decide (lower ≤ value ∧ value ≤ upper)

/--
Approximate the terminal-column width used by the production UTF-8 TUI.

The household UI needs a small deterministic boundary rather than String.length:
ASCII occupies one column, combining marks occupy no additional column, and the
East-Asian / emoji ranges used by household labels occupy two columns. Ambiguous
Unicode width remains terminal-dependent; this boundary targets the Japanese and
emoji text actually used by the household TUI. This is presentation geometry only.
-/
def charWidth (char : Char) : Nat :=
  let value := char.toNat
  if decide (value < 32) || inRange value 0x7f 0x9f then 0
  else if
      inRange value 0x0300 0x036f ||
      inRange value 0x1ab0 0x1aff ||
      inRange value 0x1dc0 0x1dff ||
      inRange value 0x20d0 0x20ff ||
      value == 0x200d ||
      inRange value 0xfe00 0xfe0f ||
      inRange value 0xfe20 0xfe2f then 0
  else if
      inRange value 0x1100 0x115f ||
      inRange value 0x2329 0x232a ||
      inRange value 0x2e80 0x303e ||
      inRange value 0x3040 0xa4cf ||
      inRange value 0xac00 0xd7a3 ||
      inRange value 0xf900 0xfaff ||
      inRange value 0xfe10 0xfe19 ||
      inRange value 0xfe30 0xfe6f ||
      inRange value 0xff00 0xff60 ||
      inRange value 0xffe0 0xffe6 ||
      inRange value 0x1f300 0x1faff ||
      inRange value 0x20000 0x3fffd then 2
  else 1

/-- Physical terminal columns occupied by a UTF-8 string. -/
def displayWidth (text : String) : Nat :=
  text.toList.foldl (fun width char => width + charWidth char) 0

private def takeColumnsList : List Char → Nat → List Char
  | [], _ => []
  | char :: rest, remaining =>
      let width := charWidth char
      if width = 0 then
        char :: takeColumnsList rest remaining
      else if width ≤ remaining then
        char :: takeColumnsList rest (remaining - width)
      else
        []

/-- Keep the longest prefix that fits completely inside `columns`. -/
def clip (columns : Nat) (text : String) : String :=
  String.ofList (takeColumnsList text.toList columns)

private def spaces (count : Nat) : String :=
  String.ofList (List.replicate count ' ')

/-- Clip, then pad on the right to exactly `columns` terminal columns. -/
def padRight (columns : Nat) (text : String) : String :=
  let clipped := clip columns text
  clipped ++ spaces (columns - displayWidth clipped)

/-- Clip, then pad on the left to exactly `columns` terminal columns. -/
def padLeft (columns : Nat) (text : String) : String :=
  let clipped := clip columns text
  spaces (columns - displayWidth clipped) ++ clipped

/-- Reserve the physical terminal's final column so writing never arms auto-wrap. -/
def contentWidth (bounds : Bounds) : Nat :=
  if bounds.width > 1 then bounds.width - 1 else bounds.width

/--
Return at most `maxVisible` list items with their original indices, keeping the
selected index near the middle when the list is larger than the window.

This is presentation-only geometry. It deliberately does not clamp or reinterpret
selection state; callers retain ownership of cursor validity and movement rules.
-/
def centeredListWindow {α : Type} (items : List α) (selected maxVisible : Nat) : List (Nat × α) :=
  let total := items.length
  if total <= maxVisible then
    items.zipIdx.map fun (x, i) => (i, x)
  else
    let half := maxVisible / 2
    let start := if selected > half then min (selected - half) (total - maxVisible) else 0
    (items.drop start |>.take maxVisible).zipIdx.map fun (x, i) => (start + i, x)

private def takeCellsColumns : List Cell → Nat → List Cell
  | [], _ => []
  | cell :: rest, remaining =>
      let width := charWidth cell.glyph
      if width = 0 then
        cell :: takeCellsColumns rest remaining
      else if width ≤ remaining then
        cell :: takeCellsColumns rest (remaining - width)
      else
        []

/-- Preserve styles while clipping one rendered row by physical terminal columns. -/
def clipCells (columns : Nat) (cells : List Cell) : List Cell :=
  takeCellsColumns cells columns

/--
Pack tokens into lines separated by `separator`, wrapping to a new line whenever
adding the next token would exceed `columns` terminal columns. A single token
that exceeds `columns` is placed on its own line without further splitting.
-/
def flowTokens (columns : Nat) (separator : String) (tokens : List String) : List String :=
  let sepWidth := displayWidth separator
  let rec loop (currentLine : String) (currentWidth : Nat) (remaining : List String) (acc : List String) : List String :=
    match remaining with
    | [] =>
        if currentLine.isEmpty then acc.reverse
        else (currentLine :: acc).reverse
    | token :: rest =>
        let tokWidth := displayWidth token
        if currentLine.isEmpty then
          loop token tokWidth rest acc
        else if currentWidth + sepWidth + tokWidth ≤ columns then
          loop (currentLine ++ separator ++ token) (currentWidth + sepWidth + tokWidth) rest acc
        else
          loop token tokWidth rest (currentLine :: acc)
  loop "" 0 tokens []

/--
Flow multiple semantic token groups into lines. Each group starts on a new line,
preserving logical boundaries between groups while wrapping within each group.
-/
def flowLines (columns : Nat) (separator : String) (groups : List (List String)) : List String :=
  groups.flatMap (flowTokens columns separator)

end Loam.Tui.Layout