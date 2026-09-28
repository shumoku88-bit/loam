import Loam.Tui.Chart

open Loam.Tui.Kernel

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def text (rows : List Widget) : String :=
  String.intercalate "\n" <| rows.flatMap Widget.lines |>.map fun cells =>
    String.ofList (cells.map Cell.glyph)

def main : IO Unit := do
  let flat := Loam.Tui.Chart.rangeFor [500, 500, 500]
  expect (flat.low < 500 && 500 < flat.high)
    "portable chart range did not give a flat series vertical breathing room"

  let positive := Loam.Tui.Chart.rangeFor [459, 508, 500]
  expect (positive.low > 0 && positive.high > 508)
    "portable chart range unnecessarily forced zero into positive history"

  expect (Loam.Tui.Chart.xForIndex 61 3 0 == 0)
    "portable chart first logical point left the first plot column"
  expect (Loam.Tui.Chart.xForIndex 61 3 2 == 60)
    "portable chart final logical point left the final plot column"
  expect (Loam.Tui.Chart.nearestIndex 61 3 30 == 1)
    "portable chart pointer hit-testing drifted from logical selection"

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

  expect (Loam.Tui.Chart.Renderer.next .braille == .block)
    "renderer fallback order lost Braille to block transition"
  expect (Loam.Tui.Chart.Renderer.next .block == .ascii)
    "renderer fallback order lost block to ASCII transition"
  expect (Loam.Tui.Chart.Renderer.next .ascii == .braille)
    "renderer fallback order lost ASCII to Braille transition"

  IO.println "portable TUI chart geometry and renderer fallbacks passed."
