import Loam.Core.Persistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩

private def sample : SomeAmount :=
  SomeAmount.ofQuantity yen (Quantity.ofQuanta (-1250))

def main : IO Unit := do
  expect
    (Persistence.encode? sample == some "LOAM-AMOUNT\t1\njpy\t-1250\n")
    "persistence encode changed the exact wire shape"

  match (Persistence.encode? sample).bind Persistence.decode? with
  | some amount =>
      expect (amount.measure.token == "jpy")
        "persistence round-trip changed measure identity"
      expect (amount.quantity.quanta == -1250)
        "persistence round-trip changed exact quanta"
  | none =>
      throw <| IO.userError "persistence round-trip failed to decode"

  expect
    (Persistence.decode? "LOAM-AMOUNT\t2\njpy\t-1250\n").isNone
    "persistence accepted an unsupported version"

  expect
    (Persistence.encode?
      (SomeAmount.ofQuantity ⟨"jp\ty"⟩ (Quantity.ofQuanta 1))).isNone
    "persistence accepted an ambiguous measure token"
