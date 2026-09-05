import Loam.Persistence.OpenRelationPersistence

open Loam.Core
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def rel
    (id event effect : String)
    (debtor creditor : RelationEndpoint)
    (quantity : Int) : RelationUnit :=
  {
    id := ⟨id⟩
    sourceEvent := ⟨event⟩
    sourceEffect := ⟨effect⟩
    debtor := debtor
    creditor := creditor
    quantity := Quantity.ofQuanta quantity
  }

private def friend : RelationEndpoint := .external ⟨"friend-α☕"⟩
private def merchant : RelationEndpoint := .external ⟨"merchant:01"⟩

private def receivable : RelationUnit :=
  rel "relation-1" "trip" "travel" friend .household 400

private def payable : RelationUnit :=
  rel "relation-2" "purchase" "effect-2" .household merchant 250

private def rawZero : RelationUnit :=
  rel "raw-zero" "future-event" "future-effect" friend .household 0

private def rawNegative : RelationUnit :=
  rel "raw-negative" "missing-event" "missing-effect" .household merchant (-75)

private def duplicateShape : RelationUnit :=
  rel "relation-1" "other-event" "other-effect" .household merchant 10

def main : IO Unit := do
  -- 1. Adjacent path and empty stream shape.
  let memoryPath := System.FilePath.mk "household.events"
  expect
    ((openRelationUnitPathForEventMemory memoryPath).toString = "household.events.relations")
    "RelationUnit adjacent path was not <event-memory>.relations"

  expect
    (encodeOpenRelationUnits? [] = some "LOAM-RELATION-UNIT-MEMORY\t1\n")
    "Empty RelationUnit stream wire shape changed"

  match decodeOpenRelationUnits? "LOAM-RELATION-UNIT-MEMORY\t1\n" with
  | some rows => expect rows.isEmpty "Empty RelationUnit stream decoded non-empty"
  | none => throw <| IO.userError "Empty RelationUnit stream failed to decode"

  -- 2. Both semantic directions and opaque endpoint punctuation round-trip.
  let normalRows := [receivable, payable]
  let normalWire ← match encodeOpenRelationUnits? normalRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Valid RelationUnit rows failed to encode"

  expect
    (normalWire =
      "LOAM-RELATION-UNIT-MEMORY\t1\n" ++
      "RELATION\trelation-1\ttrip\ttravel\tE\tfriend-α☕\tH\t\t400\n" ++
      "RELATION\trelation-2\tpurchase\teffect-2\tH\t\tE\tmerchant:01\t250\n")
    "RelationUnit wire representation changed"

  match decodeOpenRelationUnits? normalWire with
  | some rows => expect (rows == normalRows) "Normal RelationUnit rows failed exact round-trip"
  | none => throw <| IO.userError "Normal RelationUnit wire failed to decode"

  -- 3. Persistence is raw: zero, negative, and not-yet-present source coordinates survive.
  let rawRows := [rawZero, rawNegative]
  let rawWire ← match encodeOpenRelationUnits? rawRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Raw zero/negative RelationUnit rows failed to encode"

  match decodeOpenRelationUnits? rawWire with
  | some rows =>
      expect (rows == rawRows)
        "Raw zero/negative or orphan RelationUnit coordinates did not survive round-trip"
  | none => throw <| IO.userError "Raw zero/negative RelationUnit wire failed to decode"

  -- 4. Duplicate identity remains visible raw evidence for Application fail-closed admission.
  let duplicateRows := [receivable, duplicateShape]
  let duplicateWire ← match encodeOpenRelationUnits? duplicateRows with
    | some wire => pure wire
    | none => throw <| IO.userError "Duplicate raw RelationUnit identities failed syntax encode"
  match decodeOpenRelationUnits? duplicateWire with
  | some rows =>
      expect (rows == duplicateRows)
        "Persistence silently discarded duplicate RelationUnit identity"
  | none => throw <| IO.userError "Persistence consumed Application duplicate-identity authority"

  -- 5. Fail-closed syntax checks.
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t2\n").isNone
    "Unsupported RelationUnit persistence version was admitted"
  expect
    (decodeOpenRelationUnits?
      "WRONG\t1\n").isNone
    "Wrong RelationUnit persistence header was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tH\t\tE\td\t1").isNone
    "Missing trailing newline was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tH\t\tE\td\n").isNone
    "Malformed RelationUnit column count was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tX\t\tE\td\t1\n").isNone
    "Unknown endpoint kind was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tH\tnot-empty\tE\td\t1\n").isNone
    "Household endpoint with identity token was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tE\t\tH\t\t1\n").isNone
    "External endpoint with empty identity token was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\t\tb\tc\tE\td\tH\t\t1\n").isNone
    "Empty RelationUnit identity token was admitted"
  expect
    (decodeOpenRelationUnits?
      "LOAM-RELATION-UNIT-MEMORY\t1\nRELATION\ta\tb\tc\tE\td\tH\t\tnot-an-int\n").isNone
    "Non-integer RelationUnit quantity was admitted"

  let badExternal := rel "bad-endpoint" "event" "effect"
    (.external ⟨"bad\tid"⟩) .household 1
  expect (encodeOpenRelationUnits? [badExternal]).isNone
    "External identity containing tab was encoded"

  let badRelationId := rel "bad\nid" "event" "effect" friend .household 1
  expect (encodeOpenRelationUnits? [badRelationId]).isNone
    "RelationUnit identity containing newline was encoded"

  -- 6. Filesystem round-trip through sibling staging + rename.
  let tmpDir := System.FilePath.mk "scratch/test-open-relation-persistence"
  IO.FS.createDirAll tmpDir
  let tmpFile := tmpDir / "memory.relations"

  let saveOk ← saveOpenRelationUnits? tmpFile (normalRows ++ rawRows ++ duplicateRows)
  expect saveOk "Failed to save raw RelationUnit stream"

  let loaded ← match ← loadOpenRelationUnits? tmpFile with
    | some rows => pure rows
    | none => throw <| IO.userError "Failed to load saved raw RelationUnit stream"
  expect (loaded == normalRows ++ rawRows ++ duplicateRows)
    "Filesystem RelationUnit round-trip changed retained rows"

  IO.FS.removeFile tmpFile
  IO.FS.removeDirAll tmpDir

  IO.println "All open relation persistence tests passed."
