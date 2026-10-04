import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.Tests.TuiHouseholdCapacityFixture

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def change
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def movement
    (id : String)
    (purpose : String)
    (quanta : Int) : IO CapacityMovement := do
  let balanced ← requireSome
    (BalancedMovement.ofChanges? (⟨"jpy"⟩ : MeasureId)
      [change .unallocated (-quanta), change (.purpose ⟨purpose⟩) quanta])
    "PTY Capacity movement was not balanced"
  pure { id := ⟨id⟩, movement := balanced }

private def replaceCapacityBody
    (image : Image)
    (body : String) : IO Image := do
  if contains image "Capacity" then
    requireSome (replaceBody? image "Capacity" body)
      "PTY Capacity section replacement failed"
  else
    requireSome
      (appendSection? image { name := "Capacity", body := body })
      "PTY Capacity section append failed"

private def installDynamic
    (root : System.FilePath)
    (effectiveOn : String) : IO Unit := do
  let food ← movement "capacity-pty-food" "food" 100
  let stock ← movement "capacity-pty-stock" "stock" 50
  let movements ← requireSome
    (CapacityMemory.ofMovements? [food, stock])
    "PTY Capacity memory was rejected"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [ { movement := food.id, effectiveOn := effectiveOn }
      , { movement := stock.id, effectiveOn := effectiveOn } ])
    "PTY Capacity effective memory was rejected"
  let evidence ← requireSome
    (Loam.CapacityEvidence.ofParts? movements effective)
    "PTY Capacity evidence was rejected"
  let body ← requireSome
    (Loam.Persistence.encodeNormalizedCapacity? evidence)
    "PTY Capacity evidence did not encode"

  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "PTY HouseholdImage did not load"
  let candidate ← replaceCapacityBody generation.image body
  let _ ← requireOk
    (← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["Capacity"] candidate)
    "PTY Household Capacity publication failed"
  pure ()

/--
Install an outer-valid but semantically malformed Capacity body.

This is deliberately a corruption fixture. The caller snapshots/restores the
whole HouseholdImage bytes around the read-refusal assertion.
-/
private def installMalformed (root : System.FilePath) : IO Unit := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "PTY HouseholdImage did not load before corruption fixture"
  let candidate ← replaceCapacityBody generation.image "not-capacity-evidence\n"
  let wire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? candidate)
    "PTY malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) wire

def main (args : List String) : IO Unit := do
  match args with
  | [rootText, "set", effectiveOn] =>
      installDynamic (System.FilePath.mk rootText) effectiveOn
  | [rootText, "malform"] =>
      installMalformed (System.FilePath.mk rootText)
  | _ =>
      throw (IO.userError
        "usage: TuiHouseholdCapacityFixture ROOT set EFFECTIVE_ON | ROOT malform")

end Loam.Tests.TuiHouseholdCapacityFixture

def main (args : List String) : IO Unit :=
  Loam.Tests.TuiHouseholdCapacityFixture.main args
