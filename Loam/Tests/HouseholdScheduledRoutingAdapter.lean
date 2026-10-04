import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Authority.ScheduledRoutingAuthority
import Loam.Publisher.ScheduledRoutingPublisher
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence

namespace Loam.Tests.HouseholdScheduledRoutingAdapter

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok value => pure value
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def movement? : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-700) }
    , { coordinate := ⟨"groceries"⟩, quantity := Quantity.ofQuanta 500 }
    , { coordinate := ⟨"coffee"⟩, quantity := Quantity.ofQuanta 200 }
    ]

private def lifecycle : IO ScheduledLifecycleImage := do
  let movement ← requireSome movement? "Scheduled routing fixture movement"
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-1"⟩
    scheduledOn := "2026-09-15"
    movement := movement
  }
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [occurrence])
    "Scheduled routing fixture memory"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "Scheduled routing fixture terminals"
  pure { scheduled, terminals }

private def householdBody
    (root : System.FilePath) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "HouseholdImage did not load"
  requireSome
    (body? generation.image "ScheduledRouting")
    "HouseholdImage ScheduledRouting section missing"

private def sameStatus
    (left right : ScheduledRoutingHistory String)
    (subject : ScheduledRoutingSubject)
    (day : String) : Bool :=
  decide (left.statusAt subject day = right.statusAt subject day)

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household Scheduled routing adapter directory")
  let base := System.FilePath.mk rootText
  let legacyRoot := base / "legacy"
  let imageRoot := base / "image"
  let missingRoot := base / "missing"
  let malformedRoot := base / "malformed"
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll missingRoot
  IO.FS.createDirAll malformedRoot

  let lifecycleImage ← lifecycle
  let legacyScheduled := Loam.HouseholdPaths.scheduled legacyRoot
  let imageScheduled := Loam.HouseholdPaths.scheduled imageRoot
  expect (← saveScheduledLifecycleImage? legacyScheduled lifecycleImage)
    "legacy Scheduled lifecycle did not publish"
  expect (← saveScheduledLifecycleImage? imageScheduled lifecycleImage)
    "Household adapter Scheduled lifecycle did not publish"

  let emptyBody := scheduledRoutingHeader ++ "\n"
  let legacyRouting := Loam.HouseholdPaths.scheduledRouting legacyRoot
  IO.FS.writeFile legacyRouting emptyBody

  let initialImage : Image := {
    sections := [
      { name := "ScheduledRouting", body := emptyBody },
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot initialImage)
    "initial HouseholdImage installation failed"

  -- A stale but valid legacy file beside the HouseholdImage must remain isolated.
  let imageLegacyRouting := Loam.HouseholdPaths.scheduledRouting imageRoot
  IO.FS.writeFile imageLegacyRouting <|
    scheduledRoutingHeader ++ "\n" ++
    "ROUTE\tscheduled-1\tgroceries\tFROM\t2026-09-01\tMANAGED\tlegacy-only\n"
  let frozenLegacyBefore ← IO.FS.readFile imageLegacyRouting

  let groceries : ScheduledRoutingSubject := {
    scheduled := ⟨"scheduled-1"⟩
    locus := ⟨"groceries"⟩
  }
  let coffee : ScheduledRoutingSubject := {
    scheduled := ⟨"scheduled-1"⟩
    locus := ⟨"coffee"⟩
  }

  let managed : Loam.ScheduledRoutingPublisher.Draft := {
    subject := groceries
    effectiveOn := "2026-09-06"
    target := .managed ⟨"food"⟩
  }
  let _ ← requireOk
    (← Loam.ScheduledRoutingPublisher.publish
      legacyRouting.toString legacyScheduled.toString managed)
    "legacy managed Scheduled route failed"
  let _ ← requireOk
    (← Loam.ScheduledRoutingPublisher.publishHousehold
      imageRoot imageScheduled.toString managed)
    "Household managed Scheduled route failed"

  let firstLegacyBody ← IO.FS.readFile legacyRouting
  expect ((← householdBody imageRoot) == firstLegacyBody)
    "first Scheduled routing canonical bytes differ across storage topology"

  let unmanaged : Loam.ScheduledRoutingPublisher.Draft := {
    subject := coffee
    effectiveOn := "2026-09-06"
    target := .unmanaged
  }
  let _ ← requireOk
    (← Loam.ScheduledRoutingPublisher.publish
      legacyRouting.toString legacyScheduled.toString unmanaged)
    "legacy unmanaged Scheduled route failed"
  let _ ← requireOk
    (← Loam.ScheduledRoutingPublisher.publishHousehold
      imageRoot imageScheduled.toString unmanaged)
    "Household unmanaged Scheduled route failed"

  let secondLegacyBody ← IO.FS.readFile legacyRouting
  expect ((← householdBody imageRoot) == secondLegacyBody)
    "second Scheduled routing canonical bytes differ across storage topology"

  let legacyHistory ← requireOk
    (← Loam.ScheduledRoutingAuthority.loadLegacyCurrent? legacyRouting)
    "legacy Scheduled routing did not load"
  let imageHistory ← requireOk
    (← Loam.ScheduledRoutingAuthority.loadHouseholdCurrent? imageRoot)
    "Household Scheduled routing did not load"
  expect (sameStatus legacyHistory imageHistory groceries "2026-09-06")
    "managed status differs across storage topology"
  expect (sameStatus legacyHistory imageHistory coffee "2026-09-06")
    "unmanaged status differs across storage topology"
  expect (sameStatus legacyHistory imageHistory groceries "2026-09-05")
    "pre-effective status differs across storage topology"

  let current ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "updated HouseholdImage disappeared"
  expect
    (body? current.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "Scheduled routing update changed unknown future evidence"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "Household Scheduled routing adapter mutated legacy scheduled-routing.loam"

  let previousWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let previous ← requireSome
    (Loam.Persistence.HouseholdImage.decode? previousWire)
    "previous HouseholdImage did not decode"
  expect (body? previous "ScheduledRouting" == some firstLegacyBody)
    "previous HouseholdImage did not retain prior Scheduled routing generation"

  let beforeRefusal := current.wire
  match ← Loam.ScheduledRoutingPublisher.publishHousehold
      imageRoot imageScheduled.toString managed with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "duplicate Household Scheduled route unexpectedly succeeded")
  let afterRefusal ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "HouseholdImage disappeared after duplicate refusal"
  expect (afterRefusal.wire == beforeRefusal)
    "refused Household Scheduled route changed HouseholdImage"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "refused Household Scheduled route changed frozen legacy evidence"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingRoot {
      sections := [{ name := "Securities", body := "opaque\n" }]
    })
    "missing-section HouseholdImage installation failed"
  expect
    (!(← Loam.ScheduledRoutingAuthority.loadHouseholdCurrent? missingRoot).isOk)
    "missing Household ScheduledRouting section became implicit empty history"

  let malformedImage : Image := {
    sections := [{ name := "ScheduledRouting", body := "not-scheduled-routing\n" }]
  }
  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? malformedImage)
    "malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoot) malformedWire
  expect
    (!(← Loam.ScheduledRoutingAuthority.loadHouseholdCurrent? malformedRoot).isOk)
    "malformed Household Scheduled routing did not fail closed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedRoot)) ==
      malformedWire)
    "malformed Household Scheduled routing read changed authority"

  IO.println
    "Household Scheduled routing adapter: canonical byte/status equivalence, required-section semantics, frozen-legacy isolation, previous-generation retention, refusal, and unknown preservation passed."

end Loam.Tests.HouseholdScheduledRoutingAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdScheduledRoutingAdapter.main args
