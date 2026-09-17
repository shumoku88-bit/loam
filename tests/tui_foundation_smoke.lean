import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Scroll
import Loam.Tui.CyclicIndex
import Loam.Tui.Terminal

open Loam.Tui.Kernel
open Loam.Tui.Layout

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

-- Domain-free laws for small presentation primitives.
example : trailingWindowStart 0 12 = 0 := by decide
example : trailingWindowStart 11 12 = 0 := by decide
example : trailingWindowStart 12 12 = 1 := by decide
example : trailingWindowStart 20 12 = 9 := by decide

example : Loam.Tui.Scroll.maxOffset 20 5 = 15 := by decide
example : Loam.Tui.Scroll.clamp 20 5 99 = 15 := by decide
example : Loam.Tui.Scroll.backward 20 5 8 3 = 5 := by decide
example : Loam.Tui.Scroll.forward 20 5 13 9 = 15 := by decide

example : Loam.Tui.CyclicIndex.backward 3 0 = 2 := by decide
example : Loam.Tui.CyclicIndex.forward 3 2 = 0 := by decide

example : Loam.Tui.Terminal.decodeSgrMousePayload "64;10;5" = .up := by decide
example : Loam.Tui.Terminal.decodeSgrMousePayload "65;10;5" = .down := by decide
example : Loam.Tui.Terminal.decodeSgrMousePayload "0;10;5" = .other := by decide

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)


def main : IO Unit := do
  expect (displayWidth "Aあ" == 3)
    "display width lost mixed ASCII/CJK geometry"

  let centered := centeredListWindow ["a", "b", "c", "d", "e"] 3 3
  expect (centered.map Prod.fst == [2, 3, 4])
    "centered list window no longer keeps the selected row near the middle"

  let bounds : Bounds := { width := 80, height := 6 }
  let body : List Widget := [.row [span "body"]]
  let footer : List Widget := [.row [span "footer-a"], .row [span "footer-b"]]
  let fitted := fitWithFooter bounds body footer
  expect (fitted.length == 5)
    "stable footer geometry no longer fills the usable terminal rows"
  expect (widgetText (.column fitted) == "body\n\n\nfooter-a\nfooter-b")
    "stable footer geometry no longer pads above caller-owned footer rows"

  let widget : Widget := .column [.row [span "alpha"], .row [span "beta"]]
  let compiled := Loam.Tui.Runtime.compileWidget widget
  expect (compiled.lines.size == 2)
    "compiled widget lost its structural row count"

  expect (Loam.Tui.Terminal.cursorTo 1 2 == "\x1b[2;3H")
    "terminal cursor addressing no longer converts zero-based coordinates"

  IO.println "domain-free TUI foundation smoke checks passed"
