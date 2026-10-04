import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedCapacityPersistence
import Loam.Persistence.ScheduledRoutingPersistence

namespace Loam.Tests.TuiHouseholdCutoverFixture

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

private def replaceOrAppendBody
    (image : Image)
    (name body : String) : IO Image := do
  if contains image name then
    requireSome (replaceBody? image name body)
      ("PTY HouseholdImage section replacement failed: " ++ name)
  else
    requireSome
      (appendSection? image { name := name, body := body })
      ("PTY HouseholdImage section append failed: " ++ name)

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

private def installDynamicCapacity
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
  let candidate ← replaceOrAppendBody generation.image "Capacity" body
  let _ ← requireOk
    (← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["Capacity"] candidate)
    "PTY Household Capacity publication failed"
  pure ()


private def installDynamicScheduledRouting
    (root : System.FilePath)
    (effectiveOn : String) : IO Unit := do
  let history ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := {
           scheduled := ⟨"scheduled-1"⟩
           locus := (⟨"wifi"⟩ : LocusId) }
         effectiveOn := effectiveOn
         purpose := some ⟨"food"⟩ }])
    "PTY Scheduled routing history was rejected"
  let body ← requireSome
    (Loam.Persistence.encodeScheduledRoutingHistory? history)
    "PTY Scheduled routing history did not encode"
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "PTY HouseholdImage did not load"
  let candidate ← replaceOrAppendBody generation.image "ScheduledRouting" body
  let _ ← requireOk
    (← Loam.HouseholdAuthority.publishObserved?
      root generation.wire ["ScheduledRouting"] candidate)
    "PTY Household Scheduled routing publication failed"
  pure ()

/--
Install one outer-valid but semantically malformed cut-over section.

This deliberately bypasses semantic publication admission to create corruption
fixtures. The PTY caller snapshots and restores the complete HouseholdImage
bytes around each read-refusal assertion.
-/
private def installMalformed
    (root : System.FilePath)
    (name body : String) : IO Unit := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "PTY HouseholdImage did not load before corruption fixture"
  let candidate ← replaceOrAppendBody generation.image name body
  let wire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? candidate)
    "PTY malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) wire

def main (args : List String) : IO Unit := do
  match args with
  | [rootText, "set-capacity", effectiveOn] =>
      installDynamicCapacity (System.FilePath.mk rootText) effectiveOn
  | [rootText, "set-scheduled-routing", effectiveOn] =>
      installDynamicScheduledRouting (System.FilePath.mk rootText) effectiveOn
  | [rootText, "malform", "Capacity"] =>
      installMalformed
        (System.FilePath.mk rootText) "Capacity" "not-capacity-evidence\n"
  | [rootText, "malform", "Attention"] =>
      installMalformed
        (System.FilePath.mk rootText) "Attention" "not-attention-evidence\n"
  | _ =>
      throw (IO.userError
        "usage: TuiHouseholdCutoverFixture ROOT set-capacity EFFECTIVE_ON | ROOT set-scheduled-routing EFFECTIVE_ON | ROOT malform Capacity|Attention")

end Loam.Tests.TuiHouseholdCutoverFixture

def main (args : List String) : IO Unit :=
  Loam.Tests.TuiHouseholdCutoverFixture.main args
