import Loam.Persistence.CapacityEffectivePersistence

open Loam.Core
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

def main : IO Unit := do
  let memory ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-1"⟩, effectiveOn := "2026-08-17" },
       { movement := ⟨"capacity-2"⟩, effectiveOn := "2026-08-29" }])
    "valid Capacity effective evidence was rejected"

  let encoded ← requireSome
    (encodeCapacityEffectiveMemory? memory)
    "Capacity effective evidence did not encode"

  expect
    (encoded ==
      "LOAM-CAPACITY-EFFECTIVE\t1\n" ++
      "EFFECTIVE\tcapacity-1\t2026-08-17\n" ++
      "EFFECTIVE\tcapacity-2\t2026-08-29\n")
    "Capacity effective encoding changed unexpectedly"

  let decoded ← requireSome
    (decodeCapacityEffectiveMemory? encoded)
    "encoded Capacity effective evidence did not decode"
  expect (decoded.entries == memory.entries)
    "Capacity effective round-trip changed evidence"

  expect
    ((decodeCapacityEffectiveMemory?
      "LOAM-CAPACITY-EFFECTIVE\t1\nEFFECTIVE\tcapacity-1\t2026-02-29\n").isNone)
    "impossible calendar date was admitted"

  expect
    ((decodeCapacityEffectiveMemory?
      ("LOAM-CAPACITY-EFFECTIVE\t1\n" ++
       "EFFECTIVE\tcapacity-1\t2026-08-17\n" ++
       "EFFECTIVE\tcapacity-1\t2026-08-29\n")).isNone)
    "duplicate movement effective evidence was admitted"

  expect
    ((decodeCapacityEffectiveMemory?
      "LOAM-CAPACITY-EFFECTIVE\t2\n").isNone)
    "unsupported Capacity effective generation was admitted"

  IO.println "Capacity effective persistence qualification succeeded."
