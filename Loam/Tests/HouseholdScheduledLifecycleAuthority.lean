import Loam.Authority.HouseholdAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.HouseholdPaths
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.Tests.HouseholdScheduledLifecycleAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

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

private def movement (amount : Int) : IO (BalancedMovement LocusId) :=
  requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"wallet"⟩, quantity := Quantity.ofQuanta (-amount) }
      , { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta amount }
      ])
    "Scheduled lifecycle movement fixture"

private def lifecycle
    (ids : List (String × String × Int)) : IO ScheduledLifecycleImage := do
  let occurrences ← ids.mapM fun (id, day, amount) => do
    let mv ← movement amount
    pure {
      id := ⟨id⟩
      scheduledOn := day
      movement := mv
    }
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? occurrences)
    "Scheduled lifecycle occurrence fixture"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "Scheduled lifecycle terminal fixture"
  pure { scheduled, terminals }

private def bodyOf
    (value : ScheduledLifecycleImage)
    (message : String) : IO String :=
  requireSome (encodeScheduledLifecycleImage? value) message

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household Scheduled lifecycle authority directory")
  let base := System.FilePath.mk rootText
  let legacyRoot := base / "legacy"
  let imageRoot := base / "image"
  let missingRoot := base / "missing"
  let malformedRoot := base / "malformed"
  for root in [legacyRoot, imageRoot, missingRoot, malformedRoot] do
    IO.FS.createDirAll root

  expect (Loam.HouseholdAuthority.knownSectionNames.contains "Scheduled")
    "HouseholdAuthority lost canonical Scheduled section name"

  let initial ← lifecycle [("scheduled-1", "2026-10-10", 500)]
  let initialBody ← bodyOf initial "initial Scheduled lifecycle did not encode"
  let legacyPath := Loam.HouseholdPaths.scheduled legacyRoot
  expect (← saveScheduledLifecycleImage? legacyPath initial)
    "legacy Scheduled lifecycle fixture did not save"

  let initialImage : Image := {
    sections := [
      { name := "Scheduled", body := initialBody },
      { name := "FutureEvidence", body := "FUTURE\t1\nopaque\n" }
    ]
  }
  let initialGeneration ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot initialImage)
    "initial Scheduled HouseholdImage did not install"

  let staleLegacy ← lifecycle [("legacy-only", "2026-01-01", 999)]
  let staleLegacyPath := Loam.HouseholdPaths.scheduled imageRoot
  expect (← saveScheduledLifecycleImage? staleLegacyPath staleLegacy)
    "stale legacy Scheduled lifecycle did not save"
  let frozenLegacy ← IO.FS.readFile staleLegacyPath

  let legacy ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadLegacyCurrent? legacyPath)
    "legacy Scheduled lifecycle did not load"
  let observed ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? imageRoot)
    "Household Scheduled lifecycle did not load"
  expect
    ((← bodyOf legacy "legacy Scheduled lifecycle did not re-encode") == initialBody)
    "legacy Scheduled lifecycle canonical meaning changed"
  expect
    ((← bodyOf observed.lifecycle "Household Scheduled lifecycle did not re-encode") ==
      initialBody)
    "Household Scheduled lifecycle canonical meaning changed"

  let proposed ← lifecycle [
    ("scheduled-1", "2026-10-10", 500),
    ("scheduled-2", "2026-11-10", 700)
  ]
  let proposedBody ← bodyOf proposed "proposed Scheduled lifecycle did not encode"
  let published ← requireOk
    (← Loam.ScheduledLifecycleAuthority.publishObserved? imageRoot observed proposed)
    "Household Scheduled lifecycle publication failed"

  expect
    (body? published.image "Scheduled" == some proposedBody)
    "Scheduled lifecycle publication did not replace Household section"
  expect
    (body? published.image "FutureEvidence" == some "FUTURE\t1\nopaque\n")
    "Scheduled lifecycle publication changed unknown Household evidence"
  expect ((← IO.FS.readFile staleLegacyPath) == frozenLegacy)
    "Household Scheduled publication mutated frozen legacy scheduled.loam"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)) ==
      initialGeneration.wire)
    "Scheduled lifecycle publication did not retain exact previous generation"

  expect
    (!(← Loam.ScheduledLifecycleAuthority.publishObserved?
      imageRoot observed initial).isOk)
    "stale Scheduled lifecycle generation was allowed to publish"

  let fresh ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? imageRoot)
    "fresh Household Scheduled lifecycle did not load"
  let previousBeforeNoop ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let noop ← requireOk
    (← Loam.ScheduledLifecycleAuthority.publishObserved?
      imageRoot fresh fresh.lifecycle)
    "Scheduled lifecycle no-op was refused"
  expect (noop.wire == fresh.generation.wire)
    "Scheduled lifecycle no-op returned a different generation"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)) ==
      previousBeforeNoop)
    "Scheduled lifecycle no-op rotated previous generation"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingRoot {
      sections := [{ name := "FutureEvidence", body := "opaque\n" }]
    })
    "missing Scheduled section HouseholdImage did not install"
  expect
    (!(← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? missingRoot).isOk)
    "missing Household Scheduled section became implicit empty lifecycle"

  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? {
      sections := [{ name := "Scheduled", body := "not-scheduled-lifecycle\n" }]
    })
    "malformed inner Scheduled HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoot) malformedWire
  expect
    (!(← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? malformedRoot).isOk)
    "malformed Household Scheduled lifecycle did not fail closed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedRoot)) == malformedWire)
    "failed Scheduled lifecycle read changed malformed HouseholdImage"

  IO.println
    "Household Scheduled lifecycle authority: required-section equivalence, stale-generation refusal, no-op stability, previous-generation retention, stale-legacy isolation, unknown preservation, and malformed fail-closed passed."

end Loam.Tests.HouseholdScheduledLifecycleAuthority

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdScheduledLifecycleAuthority.main args
