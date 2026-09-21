import Loam.CapacityEvidence
import Loam.Persistence.NormalizedCapacityPersistence

open Loam
open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def normalizedFixture : String :=
  "LOAM-NORMALIZED-CAPACITY\t1\n" ++
  "MOVEMENT\tcapacity-1\t2026-08-17\tjpy\n" ++
  "CHANGE\tUNALLOCATED\t-39000\n" ++
  "CHANGE\tPURPOSE\tfood\t39000\n" ++
  "ENDMOVEMENT\n" ++
  "MOVEMENT\tcapacity-2\t2026-09-08\tjpy\n" ++
  "CHANGE\tPURPOSE\tfood\t-3000\n" ++
  "CHANGE\tPURPOSE\tstock\t1180\n" ++
  "CHANGE\tPURPOSE\tliving\t1820\n" ++
  "ENDMOVEMENT\n"

def main : IO Unit := do
  let some decoded := Loam.Persistence.decodeNormalizedCapacity? normalizedFixture
    | throw (IO.userError "normalized Capacity fixture did not decode")

  expect (decoded.movements.movements.length == 2)
    "normalized Capacity decoded wrong movement count"
  expect (decoded.effective.entries.length == 2)
    "normalized Capacity decoded wrong effective count"
  expect (decoded.effective.findByMovementId? ⟨"capacity-1"⟩ == some "2026-08-17")
    "normalized Capacity decoded wrong effective date for capacity-1"
  expect (decoded.effective.findByMovementId? ⟨"capacity-2"⟩ == some "2026-09-08")
    "normalized Capacity decoded wrong effective date for capacity-2"

  let some reencoded := Loam.Persistence.encodeNormalizedCapacity? decoded
    | throw (IO.userError "normalized Capacity encoder rejected decoded evidence")
  expect (reencoded == normalizedFixture)
    "normalized Capacity round-trip was not idempotent"

  let some orphanEffective := CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-9"⟩, effectiveOn := "2026-09-09" }]
    | throw (IO.userError "orphan effective fixture construction failed")
  expect ((CapacityEvidence.ofParts? decoded.movements orphanEffective).isNone)
    "CapacityEvidence admitted orphan effective evidence"

  let missingDate :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-1\t2026-02-30\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-1\n" ++
    "CHANGE\tPURPOSE\tfood\t1\n" ++
    "ENDMOVEMENT\n"
  expect ((Loam.Persistence.decodeNormalizedCapacity? missingDate).isNone)
    "normalized Capacity admitted an impossible effective date"

  let badHeader :=
    "LOAM-CAPACITY-MEMORY\t1\n" ++
    "MOVEMENT\tcapacity-1\t2026-08-17\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-1\n" ++
    "CHANGE\tPURPOSE\tfood\t1\n" ++
    "ENDMOVEMENT\n"
  expect ((Loam.Persistence.decodeNormalizedCapacity? badHeader).isNone)
    "normalized Capacity admitted legacy header"

  let unbalanced :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-1\t2026-08-17\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-100\n" ++
    "CHANGE\tPURPOSE\tfood\t90\n" ++
    "ENDMOVEMENT\n"
  expect ((Loam.Persistence.decodeNormalizedCapacity? unbalanced).isNone)
    "normalized Capacity admitted unbalanced movement"

  let multiMovementFixture :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-a\t2026-08-01\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-100\n" ++
    "CHANGE\tPURPOSE\tfood\t100\n" ++
    "ENDMOVEMENT\n" ++
    "MOVEMENT\tcapacity-b\t2026-08-02\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-200\n" ++
    "CHANGE\tPURPOSE\tfood\t200\n" ++
    "ENDMOVEMENT\n" ++
    "MOVEMENT\tcapacity-c\t2026-08-03\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-300\n" ++
    "CHANGE\tPURPOSE\tfood\t300\n" ++
    "ENDMOVEMENT\n"
  let some multiDecoded := Loam.Persistence.decodeNormalizedCapacity? multiMovementFixture
    | throw (IO.userError "multi-movement fixture failed to decode")
  let movementIds := multiDecoded.movements.movements.map (·.id.token)
  expect (movementIds == ["capacity-a", "capacity-b", "capacity-c"])
    "normalized Capacity decoding did not preserve input wire order"

  IO.println "Normalized Capacity: single document -> aggregate -> encode/decode round trip preserves both retained meanings and fails closed."
