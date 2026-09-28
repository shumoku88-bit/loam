import Loam.Tui.Chart

open Loam.Tui.Kernel

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def text (rows : List Widget) : String :=
  let lines := rows.flatMap Widget.lines
  String.intercalate "\n" <| lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

def main : IO Unit := do
  let flat := Loam.Tui.Chart.rangeFor [500, 500, 500]
  expect (flat.low < 500 && 500 < flat.high)
    "portable chart range did not give a flat series vertical breathing room"

  let positive := Loam.Tui.Chart.rangeFor [459, 508, 500]
  expect (positive.low > 0 && positive.high > 508)
    "portable chart range unnecessarily forced zero into positive history"

  let overviewScale := Loam.Tui.Chart.scaleFor [464, 508, 500] 3
  expect
    (overviewScale.range.low == 460 &&
      overviewScale.range.high == 520 &&
      overviewScale.step == 20 &&
      overviewScale.ticks == [460, 480, 500, 520])
    "portable chart nice scale regressed to awkward sparse-history ticks"

  expect (Loam.Tui.Chart.xForIndex 61 3 0 == 0)
    "portable chart first logical point left the first plot column"
  expect (Loam.Tui.Chart.xForIndex 61 3 2 == 60)
    "portable chart final logical point left the final plot column"
  expect (Loam.Tui.Chart.nearestIndex 61 3 30 == 1)
    "portable chart pointer hit-testing drifted from logical selection"

  expect
    (Loam.Tui.Layout.displayWidth (String.ofList [Char.ofNat 0x28ff]) == 1 &&
      Loam.Tui.Layout.displayWidth "█" == 1 &&
      Loam.Tui.Layout.displayWidth "◆" == 1)
    "portable chart glyphs stopped occupying one terminal column"

  let braille := Loam.Tui.Chart.render .braille 24 8 [459, 508, 500] 2
  let block := Loam.Tui.Chart.render .block 24 8 [459, 508, 500] 2
  let ascii := Loam.Tui.Chart.render .ascii 24 8 [459, 508, 500] 2

  expect (braille.length == 8 && block.length == 8 && ascii.length == 8)
    "portable chart renderer changed requested terminal height"
  expect (braille.all fun row => row.width == 24)
    "Braille chart renderer changed requested terminal width"
  expect (block.all fun row => row.width == 24)
    "block chart renderer changed requested terminal width"
  expect (ascii.all fun row => row.width == 24)
    "ASCII chart renderer changed requested terminal width"

  let brailleText := text braille
  expect (brailleText.toList.any fun ch => 0x2800 <= ch.toNat && ch.toNat <= 0x28ff)
    "Braille chart renderer emitted no Braille pattern cells"
  expect (brailleText.toList.any fun ch => ch = '◆')
    "portable chart renderer lost the selected crosshair intersection"

  let gridRows :=
    overviewScale.ticks.map fun tick =>
      Loam.Tui.Chart.rowForValue 10 overviewScale.range tick
  let marked :=
    Loam.Tui.Chart.renderInRange .braille 36 10
      [464, 508, 500] 0 overviewScale.range
      [ { index := 0, kind := .observed }
      , { index := 1, kind := .observed }
      , { index := 2, kind := .incomplete }
      ] gridRows
  let markedText := text marked
  expect (markedText.toList.any fun ch => ch = '◆')
    "selected observed chart point lost its explicit marker"
  expect (markedText.toList.any fun ch => ch = '●')
    "unselected observed chart point lost its explicit marker"
  expect (markedText.toList.any fun ch => ch = '◇')
    "partial chart point lost its distinct marker"
  let horizontalGuides := (markedText.toList.filter fun ch => ch = '─').length
  expect (horizontalGuides <= 4)
    "selected crosshair expanded back into a distracting full-width ruler"
  expect (markedText.toList.any fun ch => ch = '┄')
    "nice-tick chart lost its subtle horizontal grid"

  expect (Loam.Tui.Chart.Renderer.next .braille == .block)
    "renderer fallback order lost Braille to block transition"
  expect (Loam.Tui.Chart.Renderer.next .block == .ascii)
    "renderer fallback order lost block to ASCII transition"
  expect (Loam.Tui.Chart.Renderer.next .ascii == .braille)
    "renderer fallback order lost ASCII to Braille transition"

  let narrow := Loam.Tui.Chart.render .braille 12 4 [459, 508, 500] 1
  let wide := Loam.Tui.Chart.render .braille 48 12 [459, 508, 500] 1
  expect (narrow.all fun row => row.width == 12)
    "portable chart did not reflow to a narrow terminal width"
  expect (wide.length == 12 && wide.all fun row => row.width == 48)
    "portable chart did not reflow to a larger terminal geometry"

  IO.println "portable TUI chart geometry and renderer fallbacks passed."
