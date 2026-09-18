import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualReversalPublisher
import Loam.ActualValidityPublisher
import Loam.Application.ActualValidityFrontier
import Loam.CorrectionPublisher
import Loam.Persistence.ScheduledLifecyclePersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyLifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty Scheduled terminal memory")
  return { scheduled, terminals }

private def completedLifecycle
    (actual : EventId) : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some movement := BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-700) }
      , { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 700 } ]
    | throw (IO.userError "Scheduled completion movement")
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-completed"⟩
    scheduledOn := "2026-09-07"
    movement := movement }
  let some scheduled := ScheduledMemory.ofOccurrences? [occurrence]
    | throw (IO.userError "Scheduled completion memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals?
      [{ source := occurrence.id, target := some (.actual actual) }]
    | throw (IO.userError "Scheduled completion terminal")
  return { scheduled, terminals }

private def initialWorld : IO Loam.MovementAdmission.World := do
  let effects :=
    [ Effect.ofQuantity ⟨"actual-1-effect-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-700))
    , Effect.ofQuantity ⟨"actual-1-effect-2"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 700)
    ]
  let some event := Event.ofEffects? ⟨"actual-1"⟩ effects
    | throw (IO.userError "initial Event")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "initial Event memory")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"food"⟩]
    | throw (IO.userError "initial Locus vocabulary")
  return {
    events := events
    validity := {
      facts := [.base event.id "2026-09-07"]
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def dischargeWorld : IO Loam.MovementAdmission.World := do
  let sourceEffects :=
    [ Effect.ofQuantity ⟨"source-effect"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-700))
    , Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 700)
    ]
  let dischargeEffects :=
    [ Effect.ofAnonymousQuantity ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 400)
    , Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-400))
    ]
  let some source := Event.ofEffects? ⟨"actual-source"⟩ sourceEffects
    | throw (IO.userError "Relation source Event")
  let some dischargeEvent := Event.ofEffects? ⟨"actual-1"⟩ dischargeEffects
    | throw (IO.userError "Relation discharge Event")
  let some events := EventMemory.ofEvents? [source, dischargeEvent]
    | throw (IO.userError "Relation discharge Event memory")
  let relation : RelationUnit := {
    id := ⟨"relation-1"⟩
    sourceEvent := source.id
    sourceEffect := ⟨"source-effect"⟩
    debtor := .external ⟨"friend"⟩
    creditor := .household
    quantity := Quantity.ofQuanta 700 }
  let discharge : RelationDischarge := {
    event := dischargeEvent.id
    target := relation.id
    quantity := Quantity.ofQuanta 400 }
  let some validity := ActualValidityHistory.ofParts?
      [
        .base source.id "2026-09-06",
        .base dischargeEvent.id "2026-09-07"
      ] []
    | throw (IO.userError "Relation discharge validity history")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"food"⟩]
    | throw (IO.userError "Relation discharge Locus vocabulary")
  return {
    events := events
    validity := validity
    descriptions := .empty
    relations := [relation]
    discharges := [discharge]
    locusAdmission := vocabulary }

private def quantityFor (event : Event) (locus : String) : Int :=
  event.effects.foldl
    (fun total effect => if effect.locus.token = locus then total + effect.quantity.quanta else total)
    0

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let scheduledFile := dataDir / "scheduled.loam"

  let world ← initialWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "publish initial Actual world")
  let lifecycle ← emptyLifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle)
    "publish explicit empty Scheduled lifecycle"

  let draft : Loam.ActualReversalPublisher.Draft := {
    target := ⟨"actual-1"⟩
    validOn := "2026-09-08" }
  let .ok () ← Loam.ActualReversalPublisher.publishReversal
      scheduledFile.toString root.toString draft
    | throw (IO.userError "publish Actual reversal")

  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  let relation ←
    match actualEvidence.reversals.findByTarget? draft.target with
    | some relation => pure relation
    | none => throw (IO.userError "reversal provenance relation missing")

  let .ok fresh ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload selected Actual world")
  let target ←
    match EventMemory.findById? fresh.events draft.target with
    | some event => pure event
    | none => throw (IO.userError "target Actual disappeared after reversal")
  let inverse ←
    match EventMemory.findById? fresh.events relation.reversal with
    | some event => pure event
    | none => throw (IO.userError "canonical reversal endpoint was not retained")
  expect (quantityFor target "paypay" + quantityFor inverse "paypay" == 0)
    "reversal did not exactly cancel target PayPay quantity"
  expect (quantityFor target "food" + quantityFor inverse "food" == 0)
    "reversal did not exactly cancel target food quantity"
  expect (fresh.events.events.length == 2)
    "reversal rewrote the target instead of retaining both Actual Events"

  let .ok () ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := draft.target, validOn := "2026-09-06" }
    | throw (IO.userError "date correction of reversal target was refused")
  let .ok () ← Loam.ActualValidityPublisher.publishDate
      root.toString { target := relation.reversal, validOn := "2026-09-09" }
    | throw (IO.userError "date correction of reversal endpoint was refused")
  let .ok afterDateCorrection ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Actual after reversal date corrections")
  let relationAfterDate ←
    match afterDateCorrection.reversals.findByTarget? draft.target with
    | some retained => pure retained
    | none => throw (IO.userError "date correction removed reversal provenance")
  expect (relationAfterDate == relation)
    "date correction changed reversal provenance endpoints"
  let targetAfterDate ←
    match EventMemory.findById? afterDateCorrection.events draft.target with
    | some event => pure event
    | none => throw (IO.userError "date correction removed reversal target")
  let inverseAfterDate ←
    match EventMemory.findById? afterDateCorrection.events relation.reversal with
    | some event => pure event
    | none => throw (IO.userError "date correction removed reversal endpoint")
  expect (ActualReversal.exactPhysicalInverse? targetAfterDate.effects inverseAfterDate.effects)
    "date correction invalidated exact physical inverse provenance"
  let currentDates := Loam.Application.actualValidityFrontierFacts afterDateCorrection.validity
  let targetDate := currentDates.find? fun fact => decide (fact.event = draft.target)
  let inverseDate := currentDates.find? fun fact => decide (fact.event = relation.reversal)
  expect (targetDate.any fun fact => fact.validOn == "2026-09-06")
    "date correction did not move the reversal target occurrence date"
  expect (inverseDate.any fun fact => fact.validOn == "2026-09-09")
    "date correction did not move the reversal endpoint occurrence date"

  let correctionEffects :=
    [ Effect.ofQuantity ⟨"corrected-1"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-710))
    , Effect.ofQuantity ⟨"corrected-2"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 710) ]
  let correctTarget ← Loam.CorrectionPublisher.publishCorrection
    root.toString {
      target := draft.target, effects := correctionEffects, description := none }
  expect (!correctTarget.isOk)
    "Correction changed a Reversal target and invalidated exact inverse provenance"
  let correctInverse ← Loam.CorrectionPublisher.publishCorrection
    root.toString {
      target := relation.reversal, effects := correctionEffects, description := none }
  expect (!correctInverse.isOk)
    "Correction changed a Reversal inverse and invalidated exact inverse provenance"

  let second ← Loam.ActualReversalPublisher.publishReversal
    scheduledFile.toString root.toString draft
  expect (!second.isOk)
    "a second reversal of the same Actual was not rejected"

  let reverseAgain : Loam.ActualReversalPublisher.Draft := {
    target := relation.reversal
    validOn := "2026-09-08" }
  let reverseAgainResult ← Loam.ActualReversalPublisher.publishReversal
    scheduledFile.toString root.toString reverseAgain
  expect (!reverseAgainResult.isOk)
    "reversal-of-reversal chain was admitted before its semantics were qualified"

  let dischargeRoot := dataDir / "relation-discharge-guard"
  IO.FS.createDirAll dischargeRoot
  let dischargeScheduledFile := dischargeRoot / "scheduled.loam"
  let retainedDischargeWorld ← dischargeWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? dischargeRoot retainedDischargeWorld
    | throw (IO.userError "publish Relation-discharge Actual world")
  let dischargeLifecycle ← emptyLifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage?
      dischargeScheduledFile dischargeLifecycle)
    "publish empty lifecycle for Relation-discharge reversal guard"
  let blockedDischarge ← Loam.ActualReversalPublisher.publishReversal
    dischargeScheduledFile.toString dischargeRoot.toString draft
  expect (!blockedDischarge.isOk)
    "Relation-discharge Event was accepted by the reversal entrance before discharge reversal semantics were qualified"
  let .ok afterDischargeBlocked ← Loam.ActualAuthority.loadActual? dischargeRoot
    | throw (IO.userError "reload Actual after refused Relation-discharge reversal")
  expect ((afterDischargeBlocked.reversals.findByTarget? draft.target).isNone)
    "refused Relation-discharge reversal retained a reversal relation"
  expect (afterDischargeBlocked.events.events.length == 2)
    "refused Relation-discharge reversal mutated retained Event memory"

  let completionRoot := dataDir / "scheduled-completion-guard"
  IO.FS.createDirAll completionRoot
  let completionScheduledFile := completionRoot / "scheduled.loam"
  let completionWorld ← initialWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? completionRoot completionWorld
    | throw (IO.userError "publish Scheduled-completion Actual world")
  let completionLifecycle ← completedLifecycle ⟨"actual-1"⟩
  expect (← Loam.Persistence.saveScheduledLifecycleImage?
      completionScheduledFile completionLifecycle)
    "publish Scheduled completion provenance"
  let blocked ← Loam.ActualReversalPublisher.publishReversal
    completionScheduledFile.toString completionRoot.toString draft
  expect (!blocked.isOk)
    "Scheduled-completion Actual was accepted by the reversal entrance"
  let .ok afterBlocked ← Loam.ActualAuthority.loadActual? completionRoot
    | throw (IO.userError "reload Actual after refused Scheduled-completion reversal")
  expect (afterBlocked.events.events.length == 1)
    "refused Scheduled-completion reversal mutated Actual Event memory"
  expect ((afterBlocked.reversals.findByTarget? draft.target).isNone)
    "refused Scheduled-completion reversal retained a reversal relation"

  IO.println "Actual reversal publisher: retained target + exact inverse + explicit provenance + date-correction independence + cross-writer Correction refusal + Relation-discharge refusal + Scheduled-completion refusal + fail-closed repeat passed."
