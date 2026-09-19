import Loam.Core.MovementOperationEvidence
import Loam.Core.EventMemory
import Loam.Core.Event

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def requireNone {α : Type} (value : Option α) (message : String) : IO Unit :=
  match value with
  | some _ => throw <| IO.userError message
  | none => pure ()

def main : IO Unit := do
  let op1 : MovementOperationId := ⟨"op-1"⟩
  let op2 : MovementOperationId := ⟨"op-2"⟩
  let op3 : MovementOperationId := ⟨"op-3"⟩

  let ev1 : EventId := ⟨"ev-1"⟩
  let ev2 : EventId := ⟨"ev-2"⟩
  let ev3 : EventId := ⟨"ev-3"⟩
  let evUnknown : EventId := ⟨"ev-unknown"⟩

  let event1 ← requireSome (Event.ofEffects? ev1 []) "setup event1"
  let event2 ← requireSome (Event.ofEffects? ev2 []) "setup event2"
  let event3 ← requireSome (Event.ofEffects? ev3 []) "setup event3"
  let knownEvents ← requireSome (EventMemory.ofEvents? [event1, event2, event3]) "setup knownEvents"

  -- 1. ofEntries? が正常な one-to-one mapping を受理する
  let entry1 : MovementOperationEvidence := { operation := op1, event := ev1 }
  let entry2 : MovementOperationEvidence := { operation := op2, event := ev2 }
  let mem ← requireSome
    (MovementOperationEvidenceMemory.ofEntries? [entry1, entry2])
    "1. ofEntries? should admit valid one-to-one mappings"

  -- 2. add? が新しい operation → Event mapping を追加できる
  let entry3 : MovementOperationEvidence := { operation := op3, event := ev3 }
  let memWith3 ← requireSome
    (mem.add? entry3)
    "2. add? should admit a distinct operation -> event mapping"

  -- 3. findEvent? が operation → Event を返す
  expect (memWith3.findEvent? op1 == some ev1) "3a. findEvent? op1 should return ev1"
  expect (memWith3.findEvent? op2 == some ev2) "3b. findEvent? op2 should return ev2"
  expect (memWith3.findEvent? op3 == some ev3) "3c. findEvent? op3 should return ev3"
  expect (memWith3.findEvent? ⟨"op-missing"⟩ == none) "3d. findEvent? missing should return none"

  -- 4. findOperation? が Event → operation を返す
  expect (memWith3.findOperation? ev1 == some op1) "4a. findOperation? ev1 should return op1"
  expect (memWith3.findOperation? ev2 == some op2) "4b. findOperation? ev2 should return op2"
  expect (memWith3.findOperation? ev3 == some op3) "4c. findOperation? ev3 should return op3"
  expect (memWith3.findOperation? ⟨"ev-missing"⟩ == none) "4d. findOperation? missing should return none"

  -- 5. 両方向lookupが同じmappingについて整合する
  for entry in memWith3.entries do
    expect (memWith3.findEvent? entry.operation == some entry.event)
      s!"5a. round-trip findEvent? mismatch for operation {entry.operation.token}"
    expect (memWith3.findOperation? entry.event == some entry.operation)
      s!"5b. round-trip findOperation? mismatch for event {entry.event.token}"

  -- 6. referencesOnlyKnownEvents が全Event既知なら true
  expect (memWith3.referencesOnlyKnownEvents knownEvents == true)
    "6. referencesOnlyKnownEvents should be true when all events are known"

  -- 7. ofEntriesAgainst? が既知Eventだけのmappingを受理する
  let memAgainst ← requireSome
    (MovementOperationEvidenceMemory.ofEntriesAgainst? knownEvents [entry1, entry2, entry3])
    "7. ofEntriesAgainst? should admit mappings with only known events"
  expect (memAgainst.entries.length == 3) "7b. ofEntriesAgainst? retained entries count mismatch"

  -- 8. 同じ MovementOperationId が複数Eventを指す candidate を ofEntries? が拒否する
  let dupOpEntries := [entry1, { operation := op1, event := ev2 }]
  requireNone
    (MovementOperationEvidenceMemory.ofEntries? dupOpEntries)
    "8. ofEntries? should reject duplicate operation candidate"

  -- 9. 異なるoperationが同じEventを所有する candidate を拒否する
  let dupEvEntries := [entry1, { operation := op2, event := ev1 }]
  requireNone
    (MovementOperationEvidenceMemory.ofEntries? dupEvEntries)
    "9. ofEntries? should reject duplicate event ownership candidate"

  -- 10. add? でも operation重複を拒否する
  requireNone
    (mem.add? { operation := op1, event := ev3 })
    "10. add? should reject duplicate operation"

  -- 11. add? でも Event重複を拒否する
  requireNone
    (mem.add? { operation := op3, event := ev1 })
    "11. add? should reject duplicate event"

  -- 12. referencesOnlyKnownEvents が未知Event参照を false にする
  let memWithUnknown ← requireSome
    (mem.add? { operation := op3, event := evUnknown })
    "setup: add? mapping with unknown event"
  expect (memWithUnknown.referencesOnlyKnownEvents knownEvents == false)
    "12. referencesOnlyKnownEvents should be false when an event is unknown"

  -- 13. ofEntriesAgainst? が未知Event参照を拒否する
  requireNone
    (MovementOperationEvidenceMemory.ofEntriesAgainst? knownEvents memWithUnknown.entries)
    "13a. ofEntriesAgainst? should reject entries referencing unknown events"

  -- 13b. ofEntriesAgainst? が重複entriesも拒否することを確認
  requireNone
    (MovementOperationEvidenceMemory.ofEntriesAgainst? knownEvents dupOpEntries)
    "13b. ofEntriesAgainst? should reject duplicate operation candidate"
  requireNone
    (MovementOperationEvidenceMemory.ofEntriesAgainst? knownEvents dupEvEntries)
    "13c. ofEntriesAgainst? should reject duplicate event candidate"

  IO.println "All MovementOperationEvidence tests passed successfully!"
