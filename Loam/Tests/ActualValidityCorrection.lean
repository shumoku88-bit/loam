import Loam.Application.ActualValidityFrontier
import Loam.Core.ActualValidityHistory
import Loam.Persistence.ActualValidityPersistence

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

private def revision (id date : String) : ActualValidityFact String :=
  .revision ⟨id⟩ event date

private def correction
    (target : ActualValidityRef) (replacement : String) : ActualValidityCorrection :=
  { target := target, replacement := ⟨replacement⟩ }

def main : IO Unit := do
  let original : ActualValidityFact String := .base event "2026-09-03"
  let replacement := revision "validity-2" "2026-09-02"
  let secondReplacement := revision "validity-3" "2026-09-01"

  let firstHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, replacement]
      [correction (.root event) "validity-2"])
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
      [correction (.root event) "validity-2",
       correction (.revision ⟨"validity-2"⟩) "validity-3"])
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

  let currentWire :=
    "LOAM-ACTUAL-VALIDITY-HISTORY\t3\n" ++
    "BASE\trecord-1\t2026-09-03\n" ++
    "REVISION\tvalidity-2\trecord-1\t2026-09-02\n" ++
    "REVISION\tvalidity-3\trecord-1\t2026-09-01\n" ++
    "CORRECTION\tROOT\trecord-1\tvalidity-2\n" ++
    "CORRECTION\tREVISION\tvalidity-2\tvalidity-3\n"
  expect
    (Loam.Persistence.encodeActualValidityHistory? repeatedHistory == some currentWire)
    "current validity persistence did not use endpoint-only V3 correction rows"

  let legacyWire :=
    "LOAM-ACTUAL-VALIDITY-HISTORY\t2\n" ++
    "BASE\trecord-1\t2026-09-03\n" ++
    "REVISION\tvalidity-2\trecord-1\t2026-09-02\n" ++
    "CORRECTION\tlegacy-correction-1\tROOT\trecord-1\tvalidity-2\n"
  let legacyHistory ← requireSome
    (Loam.Persistence.decodeActualValidityHistory? legacyWire)
    "legacy V2 validity history no longer decoded"
  let legacyCurrent ← requireSome
    (admittedActualValidityMemory? legacyHistory)
    "legacy V2 validity history no longer admitted after decoding"
  expect
    (ActualValidityMemory.findByEventId? legacyCurrent event == some "2026-09-02")
    "legacy V2 correction token changed the decoded current date"

  let sibling := revision "validity-4" "2026-08-31"
  let siblingHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, replacement, sibling]
      [correction (.root event) "validity-2",
       correction (.root event) "validity-4"])
    "sibling raw date-correction history was not retained"

  expect
    ((admittedActualValidityMemory? siblingHistory).isNone)
    "sibling date corrections silently selected a winner"

  let otherFact : ActualValidityFact String :=
    .revision ⟨"validity-other"⟩ otherEvent "2026-09-01"
  let crossEventHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [original, otherFact]
      [correction (.root event) "validity-other"])
    "cross-event raw correction history was not retained"

  expect
    ((admittedActualValidityMemory? crossEventHistory).isNone)
    "cross-event date correction was admitted as one current frontier"

  IO.println "Actual validity correction frontier succeeded."
