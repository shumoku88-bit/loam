import Loam.Core.Persistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩

private def sample : SomeAmount :=
  SomeAmount.ofQuantity yen (Quantity.ofQuanta (-1250))

private def sampleEvent? : Option Event :=
  Event.ofEffects? ⟨"event-1"⟩
    [Effect.ofQuantity ⟨"effect-a"⟩ ⟨"wallet"⟩ yen (Quantity.ofQuanta (-1000)),
     Effect.ofQuantity ⟨"effect-b"⟩ ⟨"wallet"⟩ yen (Quantity.ofQuanta (-250)),
     Effect.ofQuantity ⟨"effect-c"⟩ ⟨"bank"⟩ yen (Quantity.ofQuanta 1250)]

private def eventWire : String :=
  "LOAM-EVENT\t1\n" ++
  "event-1\n" ++
  "effect-a\twallet\tjpy\t-1000\n" ++
  "effect-b\twallet\tjpy\t-250\n" ++
  "effect-c\tbank\tjpy\t1250\n"

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

  match sampleEvent? with
  | none =>
      throw <| IO.userError "sample event failed identity admission"
  | some event =>
      expect (Persistence.encodeEvent? event == some eventWire)
        "event persistence encode changed the exact wire shape"

      match (Persistence.encodeEvent? event).bind Persistence.decodeEvent? with
      | none =>
          throw <| IO.userError "event persistence round-trip failed to decode"
      | some restored =>
          expect (restored.id.token == "event-1")
            "event persistence round-trip changed event identity"
          match restored.effects with
          | [left, middle, right] =>
              expect (left.key.token == "effect-a")
                "event persistence changed first effect identity"
              expect (middle.key.token == "effect-b")
                "event persistence changed second effect identity"
              expect (right.key.token == "effect-c")
                "event persistence changed third effect identity"
          | _ =>
              throw <| IO.userError "event persistence changed effect detail count"

          expect
            ((Event.quantityAt restored ⟨"wallet"⟩ yen).quanta == -1250)
            "event persistence changed the wallet/jpy projection"
          expect
            ((Event.quantityAt restored ⟨"bank"⟩ yen).quanta == 1250)
            "event persistence changed the bank/jpy projection"

      let path := System.FilePath.mk "/tmp/loam-event-persistence-test"
      expect (← Persistence.saveEvent? path event)
        "event persistence refused a representable event"
      match ← Persistence.loadEvent? path with
      | some restored =>
          expect
            ((Event.quantityAt restored ⟨"wallet"⟩ yen).quanta == -1250)
            "event save/load changed the wallet/jpy projection"
      | none =>
          throw <| IO.userError "event save/load failed to decode its own file"

  expect
    (Persistence.decodeEvent?
      ("LOAM-EVENT\t1\nevent-1\n" ++
       "same\twallet\tjpy\t-1\n" ++
       "same\tbank\tjpy\t1\n")).isNone
    "event persistence admitted duplicate effect identity"

  expect
    (Persistence.decodeEvent? "LOAM-EVENT\t2\nevent-1\n").isNone
    "event persistence accepted an unsupported version"
