import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.Chart

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Portable terminal chart foundation

A small domain-free chart renderer for ordinary text terminals.

The foundation assumes only Unicode text cells plus the existing LOAM style
boundary. No terminal-specific image protocol, sixel, kitty graphics, or
iTerm2 inline-image escape is required.

Three renderers share the same geometry:

* `braille`: two horizontal by four vertical subpixels per terminal cell;
* `block`: one full-block sample per terminal cell;
* `ascii`: one ASCII star sample per terminal cell.

Selection and pointer hit-testing are renderer-independent. A crosshair is
overlaid in ordinary single-cell Unicode so keyboard, click, and hover all
address the same logical point.
-/

inductive Renderer where
  | braille
  | block
  | ascii
  deriving Repr, DecidableEq

namespace Renderer

def label : Renderer → String
  | .braille => "braille"
  | .block => "block"
  | .ascii => "ascii"

def next : Renderer → Renderer
  | .braille => .block
  | .block => .ascii
  | .ascii => .braille

end Renderer

structure Range where
  low : Int
  high : Int
  deriving Repr, DecidableEq

private def minMax? : List Int → Option (Int × Int)
  | [] => none
  | first :: rest =>
      some <| rest.foldl
        (fun (low, high) value => (min low value, max high value))
        (first, first)

/--
Choose a readable vertical range without forcing zero into an all-positive or
all-negative series.

A flat positive series around 500 therefore gets visible vertical breathing
room instead of being crushed against a 0..500 axis. Crossing-zero data keeps
zero naturally inside the range.
-/
def rangeFor (values : List Int) : Range :=
  match minMax? values with
  | none => { low := 0, high := 1 }
  | some (low, high) =>
      if low = high then
        let pad := max 1 (low.natAbs / 10)
        { low := low - Int.ofNat pad, high := high + Int.ofNat pad }
      else
        let spread := (high - low).natAbs
        let pad := max 1 (spread / 5)
        let paddedLow := low - Int.ofNat pad
        let paddedHigh := high + Int.ofNat pad
        {
          low := if low >= 0 then max 0 paddedLow else paddedLow
          high := if high <= 0 then min 0 paddedHigh else paddedHigh
        }

def xForIndex (width count index : Nat) : Nat :=
  if width <= 1 || count <= 1 then 0
  else min (width - 1) (index * (width - 1) / (count - 1))

def nearestIndex (width count column : Nat) : Nat :=
  if width <= 1 || count <= 1 then 0
  else
    let x := min (width - 1) column
    min (count - 1)
      ((x * (count - 1) + (width - 1) / 2) / (width - 1))

private def interpolate
    (left right : Int) (numerator denominator : Nat) : Int :=
  if denominator = 0 then left
  else
    left +
      (right - left) * Int.ofNat numerator / Int.ofNat denominator

def sampleAt (values : List Int) (width x : Nat) : Int :=
  let count := values.length
  if count = 0 then 0
  else if count = 1 || width <= 1 then values.head?.getD 0
  else if x + 1 >= width then values.getLast?.getD 0
  else
    let denominator := width - 1
    let scaled := x * (count - 1)
    let segment := scaled / denominator
    let remainder := scaled % denominator
    let left := values[segment]?.getD 0
    let right := values[segment + 1]?.getD left
    interpolate left right remainder denominator

def rowForValue
    (height : Nat) (range : Range) (value : Int) : Nat :=
  if height <= 1 || range.high <= range.low then 0
  else
    let offset :=
      (value - range.low) * Int.ofNat (height - 1) /
        (range.high - range.low)
    (height - 1) - min (height - 1) offset.natAbs

def valueForRow
    (height row : Nat) (range : Range) : Int :=
  if height <= 1 || range.high <= range.low then range.high
  else
    range.high -
      (range.high - range.low) * Int.ofNat row / Int.ofNat (height - 1)

private def dotValue (dx dy : Nat) : Nat :=
  match dx, dy with
  | 0, 0 => 1
  | 0, 1 => 2
  | 0, 2 => 4
  | 1, 0 => 8
  | 1, 1 => 16
  | 1, 2 => 32
  | 0, 3 => 64
  | 1, 3 => 128
  | _, _ => 0

private def brailleGlyph
    (values : List Int) (range : Range)
    (width height cellX cellY : Nat) : Char :=
  let subWidth := max 1 (width * 2)
  let subHeight := max 1 (height * 4)
  let mask :=
    (List.range 2).foldl
      (fun current dx =>
        (List.range 4).foldl
          (fun inner dy =>
            let subX := cellX * 2 + dx
            let subY := cellY * 4 + dy
            let value := sampleAt values subWidth subX
            let lineY := rowForValue subHeight range value
            if lineY = subY then inner + dotValue dx dy else inner)
          current)
      0
  if mask = 0 then ' ' else Char.ofNat (0x2800 + mask)

private def cellGlyph
    (renderer : Renderer)
    (values : List Int) (range : Range)
    (width height x y : Nat) : Char :=
  match renderer with
  | .braille => brailleGlyph values range width height x y
  | .block =>
      let value := sampleAt values width x
      if rowForValue height range value = y then '█' else ' '
  | .ascii =>
      let value := sampleAt values width x
      if rowForValue height range value = y then '*' else ' '

private def selectedPoint
    (values : List Int) (selected : Nat) : Int :=
  values[selected]?.getD (values.getLast?.getD 0)

/--
Render only the rectangular plot body.

The selected logical point is shown with a crosshair. The underlying series
glyph is retained everywhere except the exact intersection, which becomes a
single-cell diamond. This keeps the cursor visible in Braille, block, and ASCII
modes without changing hit-testing geometry.
-/
def render
    (renderer : Renderer)
    (width height : Nat)
    (values : List Int)
    (selected : Nat) : List Widget :=
  let actualWidth := max 1 width
  let actualHeight := max 1 height
  let range := rangeFor values
  let selectedX :=
    xForIndex actualWidth values.length selected
  let selectedY :=
    rowForValue actualHeight range (selectedPoint values selected)
  (List.range actualHeight).map fun row =>
    let spans :=
      (List.range actualWidth).map fun col =>
        let base := cellGlyph renderer values range actualWidth actualHeight col row
        if col = selectedX && row = selectedY then
          span "◆" .selected
        else if col = selectedX then
          if base = ' ' then span "│" .muted
          else span (String.ofList [base]) .selected
        else if row = selectedY then
          if base = ' ' then span "─" .muted
          else span (String.ofList [base]) .selected
        else
          span (String.ofList [base])
    .row spans

end Loam.Tui.Chart
