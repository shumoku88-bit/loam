import Loam.Tui.InputEdit

open Loam.Tui.Terminal
open Loam.Tui.InputEdit

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  expect (apply? (.input 'x') "a" == some "ax")
    "one-line input did not append a typed character"
  expect (apply? (.input '界') "a" == some "a界")
    "one-line input did not retain UTF-8 text"
  expect (apply? .backspace "a界" == some "a")
    "backspace did not remove the final input character"
  expect (apply? .backspace "" == some "")
    "backspace in an empty field changed the input"
  expect (apply? (.paste "日本語\r\nshould-not-appear") "a" == some "a日本語")
    "bracketed paste did not retain only the normalized first line"
  expect (apply? (.paste "meal\rignored") "" == some "meal")
    "carriage-return paste escaped a single-line field"
  expect (apply? (.paste "abc   \nignored") "prefix" == some "prefixabc")
    "single-line paste changed its existing trim policy"
  expect (apply? (.paste "") "abc" == some "abc")
    "empty paste changed the retained text"
  expect (apply? .tab "value" == none &&
    apply? .shiftTab "value" == none &&
    apply? .enter "value" == none &&
    apply? .escape "value" == none &&
    apply? .up "value" == none &&
    apply? .right "value" == none)
    "a focus, navigation or publication key was interpreted as text"
  let some edit := operation? (.paste "more\nignored")
    | throw (IO.userError "paste did not yield a shared edit operation")
  expect (edit "before-" == "before-more" &&
    edit "another-" == "another-more")
    "shared edit operation was not reusable on different active field values"
  IO.println "TUI input edit: UTF-8, backspace, single-line paste and non-text keys passed."
