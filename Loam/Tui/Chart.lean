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

Logical observations can be overlaid as markers independently of the
interpolated presentation line. This keeps sparse observed data visually honest:
the line connects observations, while the markers show where observations
actually exist.

Selection and pointer hit-testing are renderer-independent.
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

structure Scale where
  range : Range
  step : Nat
  ticks : List Int
  deriving Repr, DecidableEq

inductive MarkerKind where
  | observed
  | partial
  deriving Repr, DecidableEq

structure Marker where
  index : Nat
  kind : MarkerKind
  deriving Repr, DecidableEq

private def minMax? : List Int → Option (Int × Int)
  | [] => none
  | first :: rest =>
      some <| rest.foldl
        (fun (low, high) value => (min low value, max high value))
        (first, first)

private def magnitude10 (value : Nat) : Nat :=
  (List.range 24).foldl
    (fun power _ =>
      if power * 10 <= max 1 value then power * 10 else power)
    1

private def niceStep (raw : Nat) : Nat :=
  let wanted := max 1 raw
  let base := magnitude10 wanted
  if wanted <= base then base
  else if wanted <= base * 2 then base * 2
  else if wanted <= base * 5 then base * 5
  else base * 10

private def floorToStep (value : Int) (step : Nat) : Int :=
  let size := Int.ofNat (max 1 step)
  if value >= 0 then
    (value / size) * size
  else
    - (((-value + size - 1) / size) * size)

private def ceilToStep (value : Int) (step : Nat) : Int :=
  let size := Int.ofNat (max 1 step)
  if value >= 0 then
    ((value + size - 1) / size) * size
  else
    - (((-value) / size) * size)

private def ticksBetween (low high : Int) (step : Nat) : List Int :=
  let size := Int.ofNat (max 1 step)
  let count := ((high - low) / size).natAbs + 1
  (List.range count).map fun index =>
    low + Int.ofNat (index * max 1 step)

/--
Choose human-readable axis bounds and ticks.

The requested interval count is a readability hint, not report semantics.
Bounds are rounded outward to 1/2/5×10^n steps. Flat series receive breathing
room first, so a stable quantity around 500 remains visible without forcing
zero into the chart.
-/
def scaleFor (values : List Int) (desiredIntervals : Nat := 4) : Scale :=
  match minMax? values with
  | none =>
      { range := { low := 0, high := 1 }, step := 1, ticks := [0, 1] }
  | some (minimum, maximum) =>
      let (seedLow, seedHigh) :=
        if minimum = maximum then
          let pad := max 1 (minimum.natAbs / 10)
          (minimum - Int.ofNat pad, maximum + Int.ofNat pad)
        else
          (minimum, maximum)
      let spread := max 1 (seedHigh - seedLow).natAbs
      let intervals := max 1 desiredIntervals
      let rawStep := max 1 ((spread + intervals - 1) / intervals)
      let step := niceStep rawStep
      let low := floorToStep seedLow step
      let high0 := ceilToStep seedHigh step
      let high := if high0 <= low then low + Int.ofNat step else high0
      {
        range := { low := low, high := high }
        step := step
        ticks := ticksBetween low high step
      }

/-- Compatibility range for callers that do not need explicit nice ticks. -/
def rangeFor (values : List Int) : Range :=
  (scaleFor values).range

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

private def distance (left right : Nat) : Nat :=
  if left <= right then right - left else left - right

private def markerAt?
    (markers : List Marker)
    (values : List Int) (range : Range)
    (width height col row : Nat) : Option Marker :=
  markers.find? fun marker =>
    match values[marker.index]? with
    | none => false
    | some value =>
        xForIndex width values.length marker.index = col &&
        rowForValue height range value = row

private def markerGlyph
    (marker : Marker) (selected : Nat) : Char :=
  match marker.kind with
  | .partial => '◇'
  | .observed => if marker.index = selected then '◆' else '●'

/--
Render one rectangular plot body in an explicit range.

Observed markers are independent from the interpolated line. The selected point
gets a quiet vertical guide plus a short local horizontal guide rather than a
full-width horizontal ruler.
-/
def renderInRange
    (renderer : Renderer)
    (width height : Nat)
    (values : List Int)
    (selected : Nat)
    (range : Range)
    (markers : List Marker := []) : List Widget :=
  let actualWidth := max 1 width
  let actualHeight := max 1 height
  let selectedX :=
    xForIndex actualWidth values.length selected
  let selectedY :=
    rowForValue actualHeight range (selectedPoint values selected)
  (List.range actualHeight).map fun row =>
    let spans :=
      (List.range actualWidth).map fun col =>
        let base := cellGlyph renderer values range actualWidth actualHeight col row
        match markerAt? markers values range actualWidth actualHeight col row with
        | some marker =>
            span (String.ofList [markerGlyph marker selected])
              (if marker.index = selected then .selected else .normal)
        | none =>
            if col = selectedX && row = selectedY then
              span "◆" .selected
            else if col = selectedX then
              if base = ' ' then span "│" .muted
              else span (String.ofList [base])
            else if row = selectedY && distance col selectedX <= 2 then
              if base = ' ' then span "─" .muted
              else span (String.ofList [base])
            else
              span (String.ofList [base])
    .row spans

/-- Render with the default nice range and no explicit observed markers. -/
def render
    (renderer : Renderer)
    (width height : Nat)
    (values : List Int)
    (selected : Nat) : List Widget :=
  renderInRange renderer width height values selected (rangeFor values)

end Loam.Tui.Chart
