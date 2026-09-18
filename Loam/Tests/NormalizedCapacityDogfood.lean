import Loam.CapacityEvidence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.NormalizedCapacityPersistence

open Loam
open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

/--
Read one existing legacy Capacity pair without mutating it, round-trip through
the candidate normalized document, and require byte-for-byte recovery of both
legacy streams.
-/
def main (args : List String) : IO Unit := do
  let [capacityPathText] := args
    | throw (IO.userError "supply path to legacy capacity.loam")
  let capacityPath := System.FilePath.mk capacityPathText
  let effectivePath := Loam.Persistence.capacityEffectivePathForMemory capacityPath

  let originalMovements ← IO.FS.readFile capacityPath
  let originalEffective ← IO.FS.readFile effectivePath

  let some movements := Loam.Persistence.decodeCapacityMemory? originalMovements
    | throw (IO.userError "legacy Capacity movement authority did not decode")
  let some effective := Loam.Persistence.decodeCapacityEffectiveMemory? originalEffective
    | throw (IO.userError "legacy Capacity effective evidence did not decode")
  let some evidence := CapacityEvidence.ofParts? movements effective
    | throw (IO.userError "legacy Capacity pair is not cross-family complete")

  let some normalized := Loam.Persistence.encodeNormalizedCapacity? evidence
    | throw (IO.userError "normalized Capacity encoder rejected canonical evidence")
  let some decoded := Loam.Persistence.decodeNormalizedCapacity? normalized
    | throw (IO.userError "normalized Capacity decoder rejected its own canonical image")

  expect (Loam.Persistence.encodeCapacityMemory? decoded.movements == some originalMovements)
    "normalized round-trip changed legacy Capacity movement bytes"
  expect (Loam.Persistence.encodeCapacityEffectiveMemory? decoded.effective == some originalEffective)
    "normalized round-trip changed legacy Capacity effective bytes"

  IO.println s!"Normalized Capacity dogfood: {decoded.movements.movements.length} movements round-trip exactly."
