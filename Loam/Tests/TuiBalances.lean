import Loam.Tui.Balances

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def coordinate (locus : String) : EffectCoordinate :=
  ⟨⟨locus⟩, ⟨"jpy"⟩⟩

private def exactRow
    (locus : String) (quanta : Int) : Loam.RoleBalanceReview.Row :=
  {
    coordinate := coordinate locus
    role := .asset
    quantity := Quantity.ofQuanta quanta
  }

def main : IO Unit := do
  let snapshot : Loam.RoleBalanceReview.Snapshot := {
    rows := [exactRow "wallet" 70]
    unresolvedRoles := [{
      coordinate := coordinate "cash"
      quantity := Quantity.ofQuanta 0
    }]
    knownPresentBalances := [{
      coordinate := coordinate "wifi-debt"
      role := some .liability
    }]
    unsupportedBalances := [{
      coordinate := coordinate "mystery"
      role := none
    }]
  }
  let selection :=
    [coordinate "wallet", coordinate "cash", coordinate "wifi-debt",
      coordinate "mystery", coordinate "wallet"]
  let state := Loam.Tui.Balances.initial snapshot selection
  let text := widgetText (Loam.Tui.Balances.view state)

  expect (state.rows.length == 4) "duplicate balance-view row was not normalized"
  expect (contains "Balances / Current" text) "Balances heading missing"
  expect (contains "wallet" text && contains "70 jpy" text) "exact classified balance missing"
  expect (contains "cash" text && contains "0 jpy" text)
    "exact balance with unresolved AccountingRole was hidden"
  expect (contains "wifi-debt" text && contains "present, amount unknown" text)
    "known-present amount-unknown balance was collapsed to unsupported"
  expect (contains "mystery" text && contains "unsupported" text)
    "unsupported selected balance was hidden"
  expect (contains "not an Account taxonomy" text) "neutral Locus boundary missing"
  expect (contains "balance-view order only" text) "presentation-order boundary missing"

  match Loam.Tui.Balances.update state true with
  | .back => pure ()
  | _ => throw (IO.userError "Balances back intent failed")

  let emptyText :=
    widgetText
      (Loam.Tui.Balances.view
        (Loam.Tui.Balances.initial snapshot []))
  expect (contains "No balances are selected" emptyText) "empty balance-view message missing"

  IO.println
    "TUI Balances: selected exact, amount-unknown, unsupported and neutral Locus states passed."
