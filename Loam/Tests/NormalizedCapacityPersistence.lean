import Loam.CapacityEvidence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.NormalizedCapacityPersistence

open Loam
open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def legacyMovements : String :=
  "LOAM-CAPACITY-MEMORY\t1\n" ++
  "MOVEMENT\tcapacity-1\tjpy\n" ++
  "CHANGE\tUNALLOCATED\t-39000\n" ++
  "CHANGE\tPURPOSE\tfood\t39000\n" ++
  "MOVEMENT\tcapacity-2\tjpy\n" ++
  "CHANGE\tPURPOSE\tfood\t-3000\n" ++
  "CHANGE\tPURPOSE\tstock\t1180\n" ++
  "CHANGE\tPURPOSE\tliving\t1820\n"

private def legacyEffective : String :=
  "LOAM-CAPACITY-EFFECTIVE\t1\n" ++
  "EFFECTIVE\tcapacity-1\t2026-08-17\n" ++
  "EFFECTIVE\tcapacity-2\t2026-09-08\n"

private def expectedNormalized : String :=
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
  let some movements := Loam.Persistence.decodeCapacityMemory? legacyMovements
    | throw (IO.userError "legacy Capacity movement fixture did not decode")
  let some effective := Loam.Persistence.decodeCapacityEffectiveMemory? legacyEffective
    | throw (IO.userError "legacy Capacity effective fixture did not decode")
  let some evidence := CapacityEvidence.ofParts? movements effective
    | throw (IO.userError "complete legacy Capacity pair was not admitted")

  let some normalized := Loam.Persistence.encodeNormalizedCapacity? evidence
    | throw (IO.userError "normalized Capacity encoder rejected admitted evidence")
  expect (normalized == expectedNormalized)
    "normalized Capacity text did not match the one-document candidate"

  let some decoded := Loam.Persistence.decodeNormalizedCapacity? normalized
    | throw (IO.userError "normalized Capacity text did not decode")
  expect (Loam.Persistence.encodeCapacityMemory? decoded.movements == some legacyMovements)
    "normalized round-trip changed Capacity movement evidence"
  expect (Loam.Persistence.encodeCapacityEffectiveMemory? decoded.effective == some legacyEffective)
    "normalized round-trip changed Capacity effective evidence"

  let some orphanEffective := CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-9"⟩, effectiveOn := "2026-09-09" }]
    | throw (IO.userError "orphan effective fixture construction failed")
  expect ((CapacityEvidence.ofParts? movements orphanEffective).isNone)
    "CapacityEvidence admitted orphan effective evidence"

  let missingDate :=
    "LOAM-NORMALIZED-CAPACITY\t1\n" ++
    "MOVEMENT\tcapacity-1\t2026-02-30\tjpy\n" ++
    "CHANGE\tUNALLOCATED\t-1\n" ++
    "CHANGE\tPURPOSE\tfood\t1\n" ++
    "ENDMOVEMENT\n"
  expect ((Loam.Persistence.decodeNormalizedCapacity? missingDate).isNone)
    "normalized Capacity admitted an impossible effective date"

  IO.println "Normalized Capacity: legacy pair -> aggregate -> single document -> aggregate preserves both retained meanings."
