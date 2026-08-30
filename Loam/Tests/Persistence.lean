import Loam.Persistence

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

private def secondEvent? : Option Event :=
  Event.ofEffects? ⟨"event-2"⟩
    [Effect.ofQuantity ⟨"effect-d"⟩ ⟨"wallet"⟩ yen (Quantity.ofQuanta (-500))]

private def sampleMemory? : Option EventMemory := do
  let first ← sampleEvent?
  let second ← secondEvent?
  EventMemory.ofEvents? [first, second]

private def eventWire : String :=
  "LOAM-EVENT\t1\n" ++
  "event-1\n" ++
  "effect-a\twallet\tjpy\t-1000\n" ++
  "effect-b\twallet\tjpy\t-250\n" ++
  "effect-c\tbank\tjpy\t1250\n"

private def eventMemoryWire : String :=
  "LOAM-EVENT-MEMORY\t1\n" ++
  "EVENT\tevent-1\n" ++
  "EFFECT\teffect-a\twallet\tjpy\t-1000\n" ++
  "EFFECT\teffect-b\twallet\tjpy\t-250\n" ++
  "EFFECT\teffect-c\tbank\tjpy\t1250\n" ++
  "EVENT\tevent-2\n" ++
  "EFFECT\teffect-d\twallet\tjpy\t-500\n"

def main : IO Unit := do
  expect
    (Loam.Persistence.encode? sample == some "LOAM-AMOUNT\t1\njpy\t-1250\n")
    "persistence encode changed the exact wire shape"

  match (Loam.Persistence.encode? sample).bind Loam.Persistence.decode? with
  | some amount =>
      expect (amount.measure.token == "jpy")
        "persistence round-trip changed measure identity"
      expect (amount.quantity.quanta == -1250)
        "persistence round-trip changed exact quanta"
  | none =>
      throw <| IO.userError "persistence round-trip failed to decode"

  expect
    (Loam.Persistence.decode? "LOAM-AMOUNT\t2\njpy\t-1250\n").isNone
    "persistence accepted an unsupported version"

  expect
    (Loam.Persistence.encode?
      (SomeAmount.ofQuantity ⟨"jp\ty"⟩ (Quantity.ofQuanta 1))).isNone
    "persistence accepted an ambiguous measure token"

  match sampleEvent? with
  | none =>
      throw <| IO.userError "sample event failed identity admission"
  | some event =>
      expect (Loam.Persistence.encodeEvent? event == some eventWire)
        "event persistence encode changed the exact wire shape"

      match (Loam.Persistence.encodeEvent? event).bind Loam.Persistence.decodeEvent? with
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
      expect (← Loam.Persistence.saveEvent? path event)
        "event persistence refused a representable event"
      match ← Loam.Persistence.loadEvent? path with
      | some restored =>
          expect
            ((Event.quantityAt restored ⟨"wallet"⟩ yen).quanta == -1250)
            "event save/load changed the wallet/jpy projection"
      | none =>
          throw <| IO.userError "event save/load failed to decode its own file"

  expect
    (Loam.Persistence.decodeEvent?
      ("LOAM-EVENT\t1\nevent-1\n" ++
       "same\twallet\tjpy\t-1\n" ++
       "same\tbank\tjpy\t1\n")).isNone
    "event persistence admitted duplicate effect identity"

  expect
    (Loam.Persistence.decodeEvent? "LOAM-EVENT\t2\nevent-1\n").isNone
    "event persistence accepted an unsupported version"

  match sampleMemory? with
  | none =>
      throw <| IO.userError "sample Event memory failed identity admission"
  | some memory =>
      expect (Loam.Persistence.encodeEventMemory? memory == some eventMemoryWire)
        "Event-memory persistence changed the exact wire shape"

      match (Loam.Persistence.encodeEventMemory? memory).bind Loam.Persistence.decodeEventMemory? with
      | none =>
          throw <| IO.userError "Event-memory round-trip failed to decode"
      | some restored =>
          match restored.events with
          | [first, second] =>
              expect (first.id.token == "event-1")
                "Event-memory round-trip changed first represented Event identity"
              expect (second.id.token == "event-2")
                "Event-memory round-trip changed second represented Event identity"
          | _ =>
              throw <| IO.userError "Event-memory round-trip changed Event count"

      let path := System.FilePath.mk "/tmp/loam-event-memory-persistence-test"
      expect (← Loam.Persistence.saveEventMemory? path memory)
        "Event-memory persistence refused representable Events"
      match ← Loam.Persistence.loadEventMemory? path with
      | some restored =>
          expect (restored.events.length == 2)
            "Event-memory save/load changed Event count"
      | none =>
          throw <| IO.userError "Event-memory save/load failed to decode its own file"

  expect
    ((Loam.Persistence.encodeEventMemory?
      { events := [], idNodup := by simp }) ==
      some "LOAM-EVENT-MEMORY\t1\n")
    "empty Event memory changed its exact wire shape"

  match Loam.Persistence.decodeEventMemory? "LOAM-EVENT-MEMORY\t1\n" with
  | some memory =>
      expect memory.events.isEmpty
        "empty Event-memory persistence restored phantom Events"
  | none =>
      throw <| IO.userError "empty Event memory failed to decode"

  expect
    (Loam.Persistence.decodeEventMemory?
      ("LOAM-EVENT-MEMORY\t1\n" ++
       "EVENT\tevent-1\n" ++
       "EVENT\tevent-1\n")).isNone
    "Event-memory persistence admitted duplicate Event identity"

  expect
    (Loam.Persistence.decodeEventMemory?
      ("LOAM-EVENT-MEMORY\t1\n" ++
       "EVENT\tevent-1\n" ++
       "EFFECT\tsame\twallet\tjpy\t-1\n" ++
       "EFFECT\tsame\tbank\tjpy\t1\n")).isNone
    "Event-memory persistence admitted duplicate Effect identity"

  match Loam.Persistence.decodeEventMemory?
      ("LOAM-EVENT-MEMORY\t1\n" ++
       "EVENT\tevent-2\n" ++
       "EFFECT\teffect-d\twallet\tjpy\t-500\n" ++
       "EVENT\tevent-1\n" ++
       "EFFECT\teffect-a\twallet\tjpy\t-1000\n") with
  | some reordered =>
      match reordered.events with
      | [first, second] =>
          expect (first.id.token == "event-2" && second.id.token == "event-1")
            "Event-memory decoder failed to retain representation order"
      | _ =>
          throw <| IO.userError "reordered Event memory changed Event count"
  | none =>
      throw <| IO.userError "Event-memory decoder rejected a different storage order"

  expect
    (Loam.Persistence.decodeEventMemory? "LOAM-EVENT-MEMORY\t2\n").isNone
    "Event-memory persistence accepted an unsupported version"

  expect
    (Loam.Persistence.decodeEventMemory?
      "LOAM-EVENT-MEMORY\t1\nEVENT\tevent-1").isNone
    "Event-memory persistence accepted a missing trailing newline"
