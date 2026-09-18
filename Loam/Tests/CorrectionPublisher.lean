import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.ActualReview
import Loam.CorrectionPublisher
import Loam.MovementPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"coffee"⟩, ⟨"books"⟩]
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

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def collectorLocalEffects
    (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"collector-temp"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"collector-temp"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def dischargeWorld : IO Loam.MovementAdmission.World := do
  let sourceEffects :=
    [ Effect.ofQuantity ⟨"source-effect"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-700))
    , Effect.ofAnonymousQuantity ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 700)
    ]
  let dischargeEffects :=
    [ Effect.ofAnonymousQuantity ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 400)
    , Effect.ofAnonymousQuantity ⟨"coffee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-400))
    ]
  let some source := Event.ofEffects? ⟨"actual-source"⟩ sourceEffects
    | throw (IO.userError "Relation source Event")
  let some dischargeEvent := Event.ofEffects? ⟨"actual-discharge"⟩ dischargeEffects
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
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"coffee"⟩]
    | throw (IO.userError "Relation discharge Locus vocabulary")
  return {
    events := events
    validity := validity
    descriptions := .empty
    relations := [relation]
    discharges := [discharge]
    locusAdmission := vocabulary }

private def recordDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-07"
  description := some "before"
  effects := effects "paypay" "coffee" 640
  relations := []
  discharges := []
  total := 640 }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let initial ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")
  let .ok recorded ← Loam.MovementPublisher.publishDraft root.toString recordDraft
    | throw (IO.userError "record target fixture")

  let correctionDraft : Loam.CorrectionPublisher.Draft := {
    target := recorded
    effects := collectorLocalEffects "paypay" "coffee" 650
    description := some "after" }

  let unbalanced : Loam.CorrectionPublisher.Draft := {
    correctionDraft with effects := correctionDraft.effects.take 1 }
  let refusedUnbalanced ← Loam.CorrectionPublisher.publishCorrection
    root.toString unbalanced
  expect (!refusedUnbalanced.isOk) "unbalanced correction replacement was admitted"

  let .ok selected ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload selected world")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root
      { selected with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "publish closed Locus policy")
  let beforeRefusal ← IO.FS.readFile (root / "actual.loam")
  let refusedPolicy ← Loam.CorrectionPublisher.publishCorrection
    root.toString correctionDraft
  expect (!refusedPolicy.isOk) "correction bypassed current Locus new-write policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeRefusal)
    "Locus-policy refusal changed Actual authority"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root selected
    | throw (IO.userError "restore Locus policy")

  let .ok () ← Loam.CorrectionPublisher.publishCorrection
      root.toString correctionDraft
    | throw (IO.userError "publish correction")

  let .ok actualEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload actual authority")
  let some correction := actualEvidence.corrections.corrections.find?
      (fun correction => correction.target == recorded)
    | throw (IO.userError "find correction relation for target")
  let replacementId := correction.replacement

  expect (actualEvidence.corrections.corrections.length == 1) "correction relation count changed"
  expect (actualEvidence.corrections.corrections.any fun correction =>
      correction.target == recorded && correction.replacement == replacementId)
    "published correction relation lost its endpoints"

  let .ok world ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload corrected Actual")
  expect ((EventMemory.findById? world.events recorded).isSome)
    "append-only correction rewrote the original Event"
  let some replacementEvent := EventMemory.findById? world.events replacementId
    | throw (IO.userError "replacement Event is absent from Actual authority")
  expect (replacementEvent.effects.all fun effect => effect.key.isNone)
    "correction retained collector-local Effect identity without relation evidence"

  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "reload correction-aware Actual review")
  let current := Loam.ActualReview.select records (.day "2026-09-07")
  expect (current.length == 1) "corrected day did not have exactly one current Actual"
  expect (current.any fun record =>
      record.event.id == replacementId && record.description == "after" &&
        record.date == some "2026-09-07" &&
        record.event.effects.map (fun effect => effect.quantity.quanta) == [-650, 650])
    "current Actual did not expose replacement quantity/date/description evidence"
  expect (records.any fun record => record.event.id == recorded && !record.isCurrent)
    "original Event disappeared instead of remaining retained and non-current"

  let staleRetry ← Loam.CorrectionPublisher.publishCorrection
    root.toString correctionDraft
  expect (!staleRetry.isOk) "already-completed correction target was accepted again"

  let dischargeRoot := root / "relation-discharge-guard"
  IO.FS.createDirAll dischargeRoot
  let retainedDischargeWorld ← dischargeWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? dischargeRoot retainedDischargeWorld
    | throw (IO.userError "publish Relation-discharge Actual world")
  let dischargeCorrection : Loam.CorrectionPublisher.Draft := {
    target := ⟨"actual-discharge"⟩
    effects := collectorLocalEffects "paypay" "coffee" 410
    description := some "corrected discharge occurrence" }
  let beforeDischargeRefusal ← IO.FS.readFile (dischargeRoot / "actual.loam")
  let blockedDischarge ← Loam.CorrectionPublisher.publishCorrection
    dischargeRoot.toString dischargeCorrection
  expect (!blockedDischarge.isOk)
    "Relation-discharge Event was accepted by the correction entrance before discharge correction semantics were qualified"
  expect ((← IO.FS.readFile (dischargeRoot / "actual.loam")) == beforeDischargeRefusal)
    "refused Relation-discharge correction changed Actual authority"
  let .ok afterDischargeBlocked ← Loam.ActualAuthority.loadActual? dischargeRoot
    | throw (IO.userError "reload Actual after refused Relation-discharge correction")
  expect (!(afterDischargeBlocked.corrections.targetsEvent ⟨"actual-discharge"⟩))
    "refused Relation-discharge correction retained correction provenance"
  expect (afterDischargeBlocked.discharges.length == 1)
    "refused Relation-discharge correction changed retained discharge evidence"

  IO.println "Correction Publisher: Actual re-read, sparse replacement identity, fail-closed policy, Relation-discharge refusal, append-only relation, replacement and fresh review passed."
