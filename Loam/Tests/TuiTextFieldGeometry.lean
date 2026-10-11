import Loam.Tui.Layout

open Loam.Tui.Layout

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

def main : IO Unit := do
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
        "a\u0301b\u0301", "猫🐸🐸と入力", "USD 123456789.00"] do
      let tail := inputTail columns original
      let head := ellipsize columns original
      expect (displayWidth tail ≤ columns && displayWidth head ≤ columns)
        s!"bounded field escaped {columns} columns for {original}"
      if displayWidth original ≤ columns then
        expect (tail == original && head == original)
          "fitting text changed during pure display projection"

  IO.println "TUI text fields: column bounds, UTF-8, CJK, tail and prefix display passed."
