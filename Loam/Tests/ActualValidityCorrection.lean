import Loam.Application.ActualValidityFrontier
import Loam.Core.ActualValidityHistory

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def event : EventId := ⟨"record-1"⟩
private def otherEvent : EventId := ⟨"record-2"⟩

private def fact (id date : String) : ActualValidityFact String :=
  { id := ⟨id⟩, event := event, validOn := date }

private def correction (id target replacement : String) : ActualValidityCorrection :=
  { id := ⟨id⟩, target := ⟨target⟩, replacement := ⟨replacement⟩ }

def main : IO Unit := do
  let original := fact "validity-1" "2026-09-03"
  let replacement := fact "validity-2" "2026-09-02"
  let secondReplacement := fact "validity-3" "2026-09-01"

  let firstHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, replacement]
      [correction "validity-correction-1" "validity-1" "validity-2"])
    "first date-correction history was not admitted"

  let firstCurrent ← requireSome
    (admittedActualValidityMemory? firstHistory)
    "first date-correction frontier failed closed"

  expect
    (ActualValidityMemory.findByEventId? firstCurrent event == some "2026-09-02")
    "first date correction did not select the replacement date"
  expect (firstHistory.facts.length == 2)
    "first date correction did not retain both temporal facts"

  let repeatedHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, replacement, secondReplacement]
      [correction "validity-correction-1" "validity-1" "validity-2",
       correction "validity-correction-2" "validity-2" "validity-3"])
    "repeated date-correction history was not admitted"

  let repeatedCurrent ← requireSome
    (admittedActualValidityMemory? repeatedHistory)
    "repeated date-correction frontier failed closed"

  expect
    (ActualValidityMemory.findByEventId? repeatedCurrent event == some "2026-09-01")
    "repeated date correction did not follow the explicit correction chain"
  expect (repeatedHistory.facts.length == 3)
    "repeated date correction did not preserve full fact provenance"
  expect (repeatedHistory.corrections.length == 2)
    "repeated date correction did not preserve both correction relations"

  let sibling := fact "validity-4" "2026-08-31"
  let siblingHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, replacement, sibling]
      [correction "validity-correction-1" "validity-1" "validity-2",
       correction "validity-correction-2" "validity-1" "validity-4"])
    "sibling raw date-correction history was not retained"

  expect
    ((admittedActualValidityMemory? siblingHistory).isNone)
    "sibling date corrections silently selected a winner"

  let otherFact : ActualValidityFact String :=
    { id := ⟨"validity-other"⟩, event := otherEvent, validOn := "2026-09-01" }
  let crossEventHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, otherFact]
      [correction "validity-correction-cross" "validity-1" "validity-other"])
    "cross-event raw correction history was not retained"

  expect
    ((admittedActualValidityMemory? crossEventHistory).isNone)
    "cross-event date correction was admitted as one current frontier"

  IO.println "Actual validity correction frontier succeeded."
