import Loam.Tui.Layout
import Loam.Tui.Terminal

open Loam.Tui.Layout
open Loam.Tui.Kernel Loam.Tui.Runtime

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def checkSemanticCaret : IO Unit := do
  let bounds : Bounds := { width := 80, height := 24 }
  let menu := compileWidget (.row [span "[Publish]" .selected])
  expect ((Loam.Tui.Terminal.textCaretPosition? bounds 0 0 79 menu).isNone)
    "selection styling was mistaken for editable text"
  let field := inputSpan 12 true "日本"
  let ordinary := compileWidget (.row [{ field with style := .normal }])
  expect (Loam.Tui.Terminal.textCaretPosition? bounds 0 0 79 ordinary == some (0, 4))
    "semantic input lost its insertion point when styling changed"
  let nested := compileWidget (framedPanel 16 5 "Outer"
    (framedPanel 14 3 "Inner" (.row [field])))
  expect (Loam.Tui.Terminal.textCaretPosition? bounds 5 10 16 nested == some (7, 16))
    "nested clipping/framing lost the CJK insertion cell or floating origin"
  let split := compileWidget (.column (sideBySide 1 8 12
    (plainLine "context") (.row [field]) " | "))
  expect (Loam.Tui.Terminal.textCaretPosition? bounds 2 5 23 split == some (2, 20))
    "side-by-side composition lost its input field's physical offset"
  let clipped := compileWidget (clipWidgetRow 4 (.row [field]))
  expect ((Loam.Tui.Terminal.textCaretPosition? bounds 0 0 79 clipped).isNone)
    "clipped-away insertion cell was clamped onto text or a border"
  let ambiguous := compileWidget (.column [.row [field], .row [field]])
  expect ((Loam.Tui.Terminal.textCaretPosition? bounds 0 0 79 ambiguous).isNone)
    "two active fields silently chose one insertion anchor"
  expect ((Loam.Tui.Terminal.textCaretPosition? bounds 0 80 12 ordinary).isNone &&
    (Loam.Tui.Terminal.textCaretPosition? bounds 24 0 12 ordinary).isNone &&
    (Loam.Tui.Terminal.textCaretPosition? bounds 0 0 0 ordinary).isNone)
    "offscreen or zero-width field acquired a physical cursor"
  for columns in [0, 1, 2, 3, 4, 5, 12, 31] do
    for text in ["", "abc", "日本語の長い入力末尾", "abc界", "abcx"] do
      let active := compileWidget (.row [inputSpan columns true text])
      let physical : Bounds := { width := columns + 1, height := 2 }
      let position := Loam.Tui.Terminal.textCaretPosition? physical 0 0 columns active
      if columns == 0 then
        expect position.isNone "zero-width field exposed an insertion anchor"
      else
        let some (row, col) := position
          | throw (IO.userError "bounded input lost its insertion cell")
        expect (row == 0 && col < columns)
          "long/CJK input put its insertion anchor outside the actual field"
      let inactive := compileWidget (.row [inputSpan columns false text])
      expect ((Loam.Tui.Terminal.textCaretPosition? physical 0 0 columns inactive).isNone)
        "unfocused field retained a live insertion anchor"

def main : IO Unit := do
  checkSemanticCaret
  expect (inputTail 0 "abcdef" == "" && ellipsize 0 "abcdef" == "")
    "zero-column field rendered text outside its terminal geometry"
  expect (inputTail 1 "abcdef" == "…" && ellipsize 1 "abcdef" == "…")
    "single-column field did not show its overflow indicator"
  expect (inputTail 5 "abcdefgh" == "…efgh")
    "editing did not keep the insertion end visible"
  expect (ellipsize 5 "abcdefgh" == "abcd…")
    "unfocused text did not keep its prefix visible"
  expect (inputTail 5 "日本語から末尾" == "…末尾")
    "CJK editing did not retain its two-column suffix"
  expect (ellipsize 5 "日本語から末尾" == "日本…")
    "CJK unfocused field did not retain its prefix"
  expect (inputTail 1 "界" == "…" && ellipsize 1 "界" == "…")
    "a double-width character overflowed the single-column field"
  expect (inputTail 16 "短い入力" == "短い入力")
    "fully visible input changed its text"
  expect (ellipsize 16 "短い入力" == "短い入力")
    "fully visible label changed its text"

  for columns in [0, 1, 2, 3, 4, 5, 7, 10, 24] do
    for original in ["", "abc", "abcdefghijklmnop", "日本語の長い入力末尾",
        "áb́", "猫🐸🐸と入力", "USD 123456789.00"] do
      let tail := inputTail columns original
      let head := ellipsize columns original
      expect (displayWidth tail ≤ columns && displayWidth head ≤ columns)
        s!"bounded field escaped {columns} columns for {original}"
      if displayWidth original ≤ columns then
        expect (tail == original && head == original)
          "fitting text changed during pure display projection"

  IO.println "TUI text fields: column bounds, UTF-8, CJK, tail and prefix display passed."
