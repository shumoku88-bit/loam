import Loam.Tests.ActualWorldFixture
import Loam.Publisher.ScheduledReplacementPublisher
import Loam.Review.ScheduledReview
import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Authority.HouseholdAuthority

import Lean.Elab.Tactic.Omega

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"smbc"⟩, ⟨"rent"⟩, ⟨"food"⟩]
    | throw (IO.userError "vocabulary")
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
    locusAdmission := vocabulary }

private def movementForMeasure?
    (measure : MeasureId)
    (fromLocus toLocus : String) (amount : Int) :
    Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? measure
    [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]

private def movement? (fromLocus toLocus : String) (amount : Int) :
    Option (BalancedMovement LocusId) :=
  movementForMeasure? ⟨"jpy"⟩ fromLocus toLocus amount

private def occurrenceForMeasure
    (measure : MeasureId)
    (id day fromLocus toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let some movement := movementForMeasure? measure fromLocus toLocus amount
    | throw (IO.userError "scheduled movement")
  return { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def occurrence
    (id day fromLocus toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) :=
  occurrenceForMeasure ⟨"jpy"⟩ id day fromLocus toLocus amount

private def lifecycleFromScheduled
    (scheduled : ScheduledMemory String) : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty terminal memory")
  return { scheduled, terminals }

private def publishLifecycle
    (root : System.FilePath)
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage) : IO Unit := do
  let some body := Loam.Persistence.encodeScheduledLifecycleImage? lifecycle
    | throw (IO.userError "encode Household Scheduled lifecycle fixture")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" body
    | throw (IO.userError "publish Household Scheduled lifecycle fixture")
  pure ()

private def replacementMovementForMeasure
    (measure : MeasureId)
    (fromLocus toLocus : String) (amount : Int) : BalancedMovement LocusId := {
  measure := measure
  changes :=
    [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]
  balanced := by
    simp [movementTotalQuanta]
    omega
}

private def replacementMovement
    (fromLocus toLocus : String) (amount : Int) : BalancedMovement LocusId :=
  replacementMovementForMeasure ⟨"jpy"⟩ fromLocus toLocus amount

private def replacementDraftForMeasure
    (measure : MeasureId)
    (source day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledReplacementPublisher.Draft := {
  source := ⟨source⟩
  scheduledOn := day
  movement := replacementMovementForMeasure measure fromLocus toLocus amount
}

private def replacementDraft
    (source day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledReplacementPublisher.Draft :=
  replacementDraftForMeasure ⟨"jpy"⟩ source day fromLocus toLocus amount

private def hasScheduled
    (records : List (ScheduledOccurrence String)) (id : ScheduledId) : Bool :=
  records.any fun record => decide (record.id = id)

private def replacementCount (memory : ScheduledTerminalMemory) : Nat :=
  (memory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) => some (terminal.source, successor)
    | _ => none).length

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir

  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")

  let s1 ← occurrence "scheduled-1" "2026-09-10" "paypay" "rent" 1000
  let s2 ← occurrence "scheduled-2" "2026-09-11" "smbc" "rent" 3000
  let s3 ← occurrence "scheduled-3" "2026-09-12" "paypay" "food" 400
  let usd : MeasureId := ⟨"usd"⟩
  let s4 ← occurrenceForMeasure usd "scheduled-4" "2026-09-12" "paypay" "food" 450
  let some scheduledMemory := ScheduledMemory.ofOccurrences? [s1, s2, s3, s4]
    | throw (IO.userError "scheduled memory")
  let lifecycle0 ← lifecycleFromScheduled scheduledMemory
  publishLifecycle root lifecycle0

  let beforeUnapproved ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let unapproved ← Loam.ScheduledReplacementPublisher.publishHousehold
    root
    (replacementDraft "scheduled-1" "2026-09-13" "paypay" "coffee" 1000)
  expect (!unapproved.isOk)
    "Scheduled replacement admitted an Effect on a Locus outside current LocusAdmission"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == beforeUnapproved)
    "refused unapproved-Locus Scheduled replacement changed lifecycle authority"

  let beforeInvalid ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let invalid ← Loam.ScheduledReplacementPublisher.publishHousehold
    root
    (replacementDraft "scheduled-1" "2026-02-29" "paypay" "rent" 1000)
  expect (!invalid.isOk) "impossible replacement date was admitted"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == beforeInvalid)
    "refused replacement changed the lifecycle authority"

  let .ok () ← Loam.ScheduledReplacementPublisher.publishHousehold
      root
      (replacementDraft "scheduled-1" "2026-09-13" "paypay" "rent" 1100)
    | throw (IO.userError "publish fresh Scheduled replacement")

  let .ok retained ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle after replacement")
  let some replacementId :=
      ScheduledTerminalMemory.replacementFor? retained.terminals ⟨"scheduled-1"⟩
    | throw (IO.userError "find replacement endpoint from canonical lifecycle relation")
  expect (replacementCount retained.terminals == 1)
    "fresh replacement relation was not retained exactly once"
  expect (ScheduledTerminalMemory.replacementFor?
      retained.terminals ⟨"scheduled-1"⟩ == some replacementId)
    "fresh replacement relation lost its endpoints"
  expect ((ScheduledMemory.findById? retained.scheduled replacementId).isSome)
    "replacement endpoint was not published in the same lifecycle image"

  let .ok afterFresh ← Loam.ScheduledReview.loadHouseholdEvidence root root
    | throw (IO.userError "reload replacement-aware Scheduled review")
  let .ok oldDayEvidence := Loam.ScheduledReview.dayEvidence afterFresh "2026-09-10"
    | throw (IO.userError "Scheduled day evidence refused valid replacement source day")
  let .ok newDayEvidence := Loam.ScheduledReview.dayEvidence afterFresh "2026-09-13"
    | throw (IO.userError "Scheduled day evidence refused valid replacement target day")
  let oldDay := Loam.ScheduledReview.explicitDueRecords oldDayEvidence
  let newDay := Loam.ScheduledReview.explicitDueRecords newDayEvidence
  expect (!hasScheduled oldDay ⟨"scheduled-1"⟩)
    "replaced source stayed current-open"
  expect (hasScheduled newDay replacementId)
    "replacement occurrence did not become current-open"
  expect ((ScheduledMemory.findById? afterFresh.scheduled ⟨"scheduled-1"⟩).isSome)
    "append-only replacement rewrote the source occurrence"

  let beforeStale ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let stale ← Loam.ScheduledReplacementPublisher.publishHousehold
    root
    (replacementDraft "scheduled-1" "2026-09-14" "paypay" "rent" 1200)
  expect (!stale.isOk) "already-replaced source accepted another replacement"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == beforeStale)
    "stale replacement changed the complete lifecycle image"

  let brokenRelation : ScheduledTerminal := {
    source := ⟨"scheduled-2"⟩
    target := some (.scheduled ⟨"missing-endpoint"⟩) }
  let some brokenRelations := retained.terminals.add? brokenRelation
    | throw (IO.userError "construct malformed replacement graph fixture")
  let brokenLifecycle := { retained with terminals := brokenRelations }
  publishLifecycle root brokenLifecycle
  let brokenRead ← Loam.ScheduledReview.loadHouseholdEvidence root root
  expect (!brokenRead.isOk)
    "missing replacement endpoint did not make complete lifecycle read fail closed"
  let noAutoHeal ← Loam.ScheduledReplacementPublisher.publishHousehold
    root
    (replacementDraft "scheduled-2" "2026-09-14" "smbc" "rent" 3100)
  expect (!noAutoHeal.isOk)
    "replacement publisher auto-healed an externally malformed lifecycle image"
  publishLifecycle root retained

  let .ok _ ← Loam.ScheduledTerminalPublisher.publishHouseholdCancellation
      root { scheduled := ⟨"scheduled-3"⟩ }
    | throw (IO.userError "cancel stale-source fixture")
  let cancelledReplacement ← Loam.ScheduledReplacementPublisher.publishHousehold
    root
    (replacementDraft "scheduled-3" "2026-09-15" "paypay" "food" 400)
  expect (!cancelledReplacement.isOk)
    "cancelled Scheduled identity accepted a replacement"

  let .ok finalLifecycle ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload final lifecycle")
  expect (replacementCount finalLifecycle.terminals == 1)
    "stale or malformed refusal changed replacement relation count"
  let .ok () ← Loam.ScheduledReplacementPublisher.publishHousehold
      root
      (replacementDraftForMeasure usd "scheduled-4" "2026-09-16" "paypay" "food" 475)
    | throw (IO.userError "publish USD Scheduled replacement")
  let .ok afterUsd ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root
    | throw (IO.userError "reload lifecycle after USD replacement")
  let some usdReplacementId :=
      ScheduledTerminalMemory.replacementFor? afterUsd.terminals ⟨"scheduled-4"⟩
    | throw (IO.userError "find USD replacement endpoint")
  let some usdReplacement := ScheduledMemory.findById? afterUsd.scheduled usdReplacementId
    | throw (IO.userError "USD replacement occurrence missing")
  expect (usdReplacement.movement.measure == usd)
    "Scheduled replacement rewrote a non-JPY movement as JPY"
  expect (replacementCount afterUsd.terminals == 2)
    "USD replacement relation was not retained exactly once"

  IO.println "Scheduled Replacement Publisher: Locus admission, one-image publication, append-only provenance, malformed-world refusal and terminal refusal passed."