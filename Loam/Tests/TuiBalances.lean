import Loam.Tui.Balances

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def row (locus : String) (quanta : Int) : Loam.BalanceReview.Row :=
  {
    coordinate := ⟨⟨locus⟩, ⟨"jpy"⟩⟩
    quantity := Quantity.ofQuanta quanta
  }


def main : IO Unit := do
  let state := Loam.Tui.Balances.initial { rows := [row "wallet" 70, row "cash" 0] }
  let text := widgetText (Loam.Tui.Balances.view state)
  expect (contains "Balances / Current" text) "Balances heading missing"
  expect (contains "wallet: 70 jpy" text) "nonzero balance missing"
  expect (contains "cash: 0 jpy" text) "explicit zero balance was hidden"
  expect (contains "not an Account taxonomy" text) "neutral Locus boundary missing"
  expect (contains "balance-view order only" text) "presentation-order boundary missing"

  match Loam.Tui.Balances.update state true with
  | .back => pure ()
  | _ => throw (IO.userError "Balances back intent failed")

  let emptyText := widgetText (Loam.Tui.Balances.view (Loam.Tui.Balances.initial { rows := [] }))
  expect (contains "No balances are selected" emptyText) "empty balance-view message missing"

  IO.println "TUI Balances: selected current quantities, explicit zero and neutral Locus boundary passed."
