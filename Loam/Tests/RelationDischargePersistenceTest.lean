import Loam.Persistence.RelationDischargePersistence

open Loam.Core
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def discharge
    (event target : String) (quantity : Int) : RelationDischarge :=
  {
    event := ⟨event⟩
    target := ⟨target⟩
    quantity := Quantity.ofQuanta quantity
  }

private def partialDischarge : RelationDischarge :=
  discharge "receipt-1" "relation-1" 400

private def remainder : RelationDischarge :=
  discharge "receipt-2" "relation-1" 600

private def rawZero : RelationDischarge :=
  discharge "future-event" "relation-2" 0

private def rawNegative : RelationDischarge :=
  discharge "missing-event" "missing-relation" (-25)

private def duplicatePair : RelationDischarge :=
  discharge "receipt-1" "relation-1" 300

def main : IO Unit := do
  -- 1. Adjacent path and empty stream shape.
  let memoryPath := System.FilePath.mk "household.events"
  expect
    ((relationDischargePathForEventMemory memoryPath).toString =
      "household.events.discharges")
    "RelationDischarge adjacent path was not <event-memory>.discharges"

  expect
    (encodeRelationDischarges? [] =
      some "LOAM-RELATION-DISCHARGE-MEMORY\t1\n")
    "Empty RelationDischarge stream wire shape changed"

  match decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\n" with
  | some rows => expect rows.isEmpty "Empty discharge stream decoded non-empty"
  | none => throw <| IO.userError "Empty discharge stream failed to decode"

  -- 2. Exact quantified discharge rows round-trip.
  let normalRows := [partialDischarge, remainder]
  let normalWire ← match encodeRelationDischarges? normalRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Valid discharge rows failed to encode"

  expect
    (normalWire =
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\n" ++
      "DISCHARGE\treceipt-1\trelation-1\t400\n" ++
      "DISCHARGE\treceipt-2\trelation-1\t600\n")
    "RelationDischarge wire representation changed"

  match decodeRelationDischarges? normalWire with
  | some rows => expect (rows == normalRows) "Normal discharge rows failed exact round-trip"
  | none => throw <| IO.userError "Normal discharge wire failed to decode"

  -- 3. Persistence is raw: unresolved references and non-positive values survive.
  let rawRows := [rawZero, rawNegative]
  let rawWire ← match encodeRelationDischarges? rawRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Raw discharge rows failed syntax encode"

  match decodeRelationDischarges? rawWire with
  | some rows =>
      expect (rows == rawRows)
        "Raw orphan/zero/negative discharge provenance changed during round-trip"
  | none => throw <| IO.userError "Raw discharge wire failed to decode"

  -- 4. Duplicate Event/target correspondence remains visible for Application fail-closed admission.
  let duplicateRows := [partialDischarge, duplicatePair]
  let duplicateWire ← match encodeRelationDischarges? duplicateRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Duplicate raw discharge pair failed syntax encode"
  match decodeRelationDischarges? duplicateWire with
  | some rows =>
      expect (rows == duplicateRows)
        "Persistence silently normalized duplicate discharge correspondence"
  | none => throw <| IO.userError "Persistence consumed Application duplicate-pair authority"

  -- 5. Fail-closed syntax checks.
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t2\n").isNone
    "Unsupported discharge persistence version was admitted"
  expect
    (decodeRelationDischarges?
      "WRONG\t1\n").isNone
    "Wrong discharge persistence header was admitted"
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\nDISCHARGE\ta\tb\t1").isNone
    "Missing trailing newline was admitted"
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\nDISCHARGE\ta\tb\n").isNone
    "Malformed discharge column count was admitted"
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\nDISCHARGE\t\tb\t1\n").isNone
    "Empty later Event identity was admitted"
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\nDISCHARGE\ta\t\t1\n").isNone
    "Empty target RelationUnit identity was admitted"
  expect
    (decodeRelationDischarges?
      "LOAM-RELATION-DISCHARGE-MEMORY\t1\nDISCHARGE\ta\tb\tnot-an-int\n").isNone
    "Non-integer discharge quantity was admitted"

  let badEvent := discharge "bad\tevent" "relation" 1
  expect (encodeRelationDischarges? [badEvent]).isNone
    "Event identity containing tab was encoded"

  let badTarget := discharge "event" "bad\nrelation" 1
  expect (encodeRelationDischarges? [badTarget]).isNone
    "RelationUnit identity containing newline was encoded"

  -- 6. Filesystem round-trip through sibling staging + rename.
  let tmpDir := System.FilePath.mk "scratch/test-relation-discharge-persistence"
  IO.FS.createDirAll tmpDir
  let tmpFile := tmpDir / "memory.discharges"

  let retained := normalRows ++ rawRows ++ duplicateRows
  let saveOk ← saveRelationDischarges? tmpFile retained
  expect saveOk "Failed to save raw RelationDischarge stream"

  let loaded ← match ← loadRelationDischarges? tmpFile with
    | some rows => pure rows
    | none => throw <| IO.userError "Failed to load saved raw RelationDischarge stream"
  expect (loaded == retained)
    "Filesystem RelationDischarge round-trip changed retained rows"

  IO.FS.removeFile tmpFile
  IO.FS.removeDirAll tmpDir

  IO.println "All relation discharge persistence tests passed."
