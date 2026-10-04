import Loam.HouseholdCommand
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tests.ActualWorldFixture

namespace Loam.Tests.HouseholdScheduledLifecycleCutover

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok value => pure value
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let events ← requireSome (EventMemory.ofEvents? []) "empty Actual events"
  let vocabulary ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"rent"⟩, ⟨"food"⟩])
    "Scheduled cutover Locus vocabulary"
  return {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

private def movement
    (fromLocus toLocus : String) (amount : Int) : IO (BalancedMovement LocusId) :=
  requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
      , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
      ])
    "Scheduled cutover balanced movement"

private def lifecycle
    (occurrences : List (ScheduledOccurrence String)) : IO ScheduledLifecycleImage := do
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? occurrences)
    "Scheduled cutover occurrence memory"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "Scheduled cutover terminal memory"
  return { scheduled, terminals }

private def publishHouseholdLifecycle
    (root : System.FilePath)
    (image : ScheduledLifecycleImage) : IO Unit := do
  let body ← requireSome
    (encodeScheduledLifecycleImage? image)
    "Scheduled cutover lifecycle did not encode"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "Scheduled" body)
    "Scheduled cutover Household fixture did not publish"
  pure ()

private def creationDraft
    (day fromLocus toLocus : String) (amount : Int) :
    IO Loam.ScheduledCreationPublisher.Draft := do
  let mv ← movement fromLocus toLocus amount
  return { scheduledOn := day, movement := mv }

private def replacementDraft
    (source : ScheduledId)
    (day fromLocus toLocus : String) (amount : Int) :
    IO Loam.ScheduledReplacementPublisher.Draft := do
  let mv ← movement fromLocus toLocus amount
  return { source, scheduledOn := day, movement := mv }

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household Scheduled cutover directory")
  let root := System.FilePath.mk rootText
  IO.FS.createDirAll root

  let world ← emptyWorld
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishWorld? root world)
    "initialize Scheduled cutover Actual/Locus fixture"

  let initial ← lifecycle []
  publishHouseholdLifecycle root initial

  let staleMovement ← movement "paypay" "food" 999
  let staleOccurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-99"⟩
    scheduledOn := "2026-01-01"
    movement := staleMovement
  }
  let staleLifecycle ← lifecycle [staleOccurrence]
  let legacyPath := Loam.HouseholdPaths.scheduled root
  expect (← saveScheduledLifecycleImage? legacyPath staleLifecycle)
    "install frozen legacy Scheduled lifecycle"
  let frozenLegacy ← IO.FS.readFile legacyPath

  let create ← creationDraft "2026-10-10" "paypay" "rent" 1000
  let created ← requireOk
    (← Loam.HouseholdCommand.createScheduled root create)
    "production Scheduled creation failed"
  expect (created.token == "scheduled-1")
    "production Scheduled creation consulted stale legacy identity space"

  let afterCreate ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root)
    "reload Household Scheduled after creation"
  expect ((afterCreate.scheduled.findById? created).isSome)
    "production Scheduled creation did not reach HouseholdImage"
  expect ((afterCreate.scheduled.findById? ⟨"scheduled-99"⟩).isNone)
    "stale legacy Scheduled occurrence leaked into HouseholdImage"
  expect ((← IO.FS.readFile legacyPath) == frozenLegacy)
    "production Scheduled creation changed frozen legacy scheduled.loam"

  let replace ← replacementDraft created "2026-11-10" "paypay" "food" 1200
  let _ ← requireOk
    (← Loam.HouseholdCommand.replaceScheduled root replace)
    "production Scheduled replacement failed"
  let afterReplace ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root)
    "reload Household Scheduled after replacement"
  let replacementId ← requireSome
    (afterReplace.terminals.replacementFor? created)
    "production replacement relation missing"
  expect (replacementId.token == "scheduled-2")
    "production replacement identity drifted"
  expect ((afterReplace.scheduled.findById? replacementId).isSome)
    "production replacement endpoint missing from HouseholdImage"
  expect ((← IO.FS.readFile legacyPath) == frozenLegacy)
    "production Scheduled replacement changed frozen legacy scheduled.loam"

  let _ ← requireOk
    (← Loam.HouseholdCommand.cancelScheduled root { scheduled := replacementId })
    "production Scheduled cancellation failed"
  let afterCancel ← requireOk
    (← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root)
    "reload Household Scheduled after cancellation"
  expect
    (afterCancel.terminals.terminals.any fun terminal =>
      terminal.source == replacementId && terminal.target.isNone)
    "production Scheduled cancellation did not reach HouseholdImage"
  expect ((← IO.FS.readFile legacyPath) == frozenLegacy)
    "production Scheduled cancellation changed frozen legacy scheduled.loam"

  let snapshot ← requireOk
    (← Loam.ScheduledReview.loadHouseholdEvidence root root)
    "production Scheduled review failed after cutover mutations"
  let open ← requireOk
    (Loam.ScheduledReview.currentOpenRecords snapshot)
    "production Scheduled frontier failed after cutover mutations"
  expect open.isEmpty
    "completed replacement/cancellation chain left a current-open occurrence"

  IO.println
    "Household Scheduled lifecycle cutover: production create/replace/cancel use HouseholdImage, stale legacy scheduled.loam stays frozen, and current-open review follows Household authority."

end Loam.Tests.HouseholdScheduledLifecycleCutover

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdScheduledLifecycleCutover.main args
