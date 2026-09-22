import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.MovementWorldLoader
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

private def suspenseWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty suspense events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"food"⟩, ⟨"books"⟩, ⟨"suspense"⟩]
    | throw (IO.userError "suspense vocabulary")
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

private def suspenseEffects
    (booksAmount suspenseAmount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"suspense-source"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta (-5800))
  , Effect.ofQuantity ⟨"suspense-food"⟩ ⟨"food"⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta 1200)
  ] ++
  (if booksAmount = 0 then [] else
    [Effect.ofQuantity ⟨"suspense-books"⟩ ⟨"books"⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta booksAmount)]) ++
  (if suspenseAmount = 0 then [] else
    [Effect.ofQuantity ⟨"suspense-unresolved"⟩ ⟨"suspense"⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta suspenseAmount)])

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

  let .ok selected ← Loam.MovementWorldLoader.loadSelectedWorld? root
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

  let .ok world ← Loam.MovementWorldLoader.loadSelectedWorld? root
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

  -- A non-JPY single-Measure Actual uses the same correction semantics.
  let usdRoot := root / "usd-correction"
  IO.FS.createDirAll usdRoot
  let usdWorld ← emptyWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? usdRoot usdWorld
    | throw (IO.userError "initialize USD correction world")
  let usdRecord : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-08"
    description := some "USD before"
    effects := [
      Effect.ofQuantity ⟨"usd-1"⟩ ⟨"paypay"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-20)),
      Effect.ofQuantity ⟨"usd-2"⟩ ⟨"coffee"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 20)]
    relations := []
    discharges := []
    total := 20 }
  let .ok usdTarget ← Loam.MovementPublisher.publishDraft usdRoot.toString usdRecord
    | throw (IO.userError "publish USD correction target")
  let usdCorrection : Loam.CorrectionPublisher.Draft := {
    target := usdTarget
    effects := [
      Effect.ofQuantity ⟨"usd-new-1"⟩ ⟨"paypay"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-21)),
      Effect.ofQuantity ⟨"usd-new-2"⟩ ⟨"coffee"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 21)]
    description := some "USD after" }

  let crossMeasureCorrection : Loam.CorrectionPublisher.Draft := {
    target := usdTarget
    effects := [
      Effect.ofQuantity ⟨"ils-new-1"⟩ ⟨"paypay"⟩ ⟨"ils"⟩ (Quantity.ofQuanta (-21)),
      Effect.ofQuantity ⟨"ils-new-2"⟩ ⟨"coffee"⟩ ⟨"ils"⟩ (Quantity.ofQuanta 21)]
    description := some "not a correction" }
  let beforeCrossMeasureRefusal ← IO.FS.readFile (usdRoot / "actual.loam")
  let refusedCrossMeasure ← Loam.CorrectionPublisher.publishCorrection
    usdRoot.toString crossMeasureCorrection
  expect (!refusedCrossMeasure.isOk)
    "correction silently changed USD evidence into another Measure"
  expect ((← IO.FS.readFile (usdRoot / "actual.loam")) == beforeCrossMeasureRefusal)
    "cross-Measure correction refusal changed Actual authority"

  let .ok () ← Loam.CorrectionPublisher.publishCorrection usdRoot.toString usdCorrection
    | throw (IO.userError "balanced USD correction was refused")
  let .ok usdRecords ← Loam.ActualReview.loadRecordsFromActual usdRoot
    | throw (IO.userError "reload USD correction")
  let usdCurrent := Loam.ActualReview.select usdRecords (.day "2026-09-08")
  expect (usdCurrent.any fun record =>
      record.description == "USD after" &&
      record.event.effects.all fun effect => effect.measure == ⟨"usd"⟩)
    "USD correction did not preserve Measure identity"

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

  let relationRoot := root / "relation-source-guard"
  IO.FS.createDirAll relationRoot
  let retainedRelationWorld ← dischargeWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? relationRoot retainedRelationWorld
    | throw (IO.userError "publish Relation-source Actual world")
  let relationCorrection : Loam.CorrectionPublisher.Draft := {
    target := ⟨"actual-source"⟩
    effects := collectorLocalEffects "paypay" "coffee" 710
    description := some "corrected relation source" }
  let beforeRelationRefusal ← IO.FS.readFile (relationRoot / "actual.loam")
  let blockedRelation ← Loam.CorrectionPublisher.publishCorrection
    relationRoot.toString relationCorrection
  expect (!blockedRelation.isOk)
    "Relation source Event was accepted by the correction entrance before relation-correction semantics were qualified"
  expect ((← IO.FS.readFile (relationRoot / "actual.loam")) == beforeRelationRefusal)
    "refused Relation-source correction changed Actual authority"
  let .ok afterRelationBlocked ← Loam.ActualAuthority.loadActual? relationRoot
    | throw (IO.userError "reload Actual after refused Relation-source correction")
  expect (!(afterRelationBlocked.corrections.targetsEvent ⟨"actual-source"⟩))
    "refused Relation-source correction retained correction provenance"
  expect (afterRelationBlocked.relations.length == 1)
    "refused Relation-source correction changed retained relation evidence"

  -- A partially classified household purchase remains a normal balanced Movement.
  -- Later classification is expressed only through the existing Correction path.
  let suspenseRoot := root / "suspense-correction"
  IO.FS.createDirAll suspenseRoot
  let unresolvedWorld ← suspenseWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? suspenseRoot unresolvedWorld
    | throw (IO.userError "initialize suspense correction world")

  let unresolvedDraft : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-23"
    description := some "bulk purchase, partially unresolved"
    effects := suspenseEffects 0 4600
    relations := []
    discharges := []
    total := 5800 }
  let .ok unresolvedId ←
      Loam.MovementPublisher.publishDraft suspenseRoot.toString unresolvedDraft
    | throw (IO.userError "publish unresolved Movement")

  let partialDraft : Loam.CorrectionPublisher.Draft := {
    target := unresolvedId
    effects := suspenseEffects 2000 2600
    description := some "bulk purchase, partially classified" }
  let .ok () ←
      Loam.CorrectionPublisher.publishCorrection suspenseRoot.toString partialDraft
    | throw (IO.userError "publish partial suspense resolution")

  let .ok partialEvidence ← Loam.ActualAuthority.loadActual? suspenseRoot
    | throw (IO.userError "reload partial suspense correction")
  let some firstCorrection := partialEvidence.corrections.corrections.find?
      (fun correction => correction.target == unresolvedId)
    | throw (IO.userError "find partial suspense correction")
  let partialId := firstCorrection.replacement
  let some partialEvent := EventMemory.findById? partialEvidence.events partialId
    | throw (IO.userError "partial suspense replacement missing")

  expect (Event.quantityAt partialEvent ⟨"paypay"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta (-5800))
    "partial suspense correction changed physical source quantity"
  expect (Event.quantityAt partialEvent ⟨"food"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 1200)
    "partial suspense correction changed already-known food quantity"
  expect (Event.quantityAt partialEvent ⟨"books"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 2000)
    "partial suspense correction did not expose newly classified quantity"
  expect (Event.quantityAt partialEvent ⟨"suspense"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 2600)
    "partial suspense correction did not retain unresolved remainder"

  let resolvedDraft : Loam.CorrectionPublisher.Draft := {
    target := partialId
    effects := suspenseEffects 4600 0
    description := some "bulk purchase, fully classified" }
  let .ok () ←
      Loam.CorrectionPublisher.publishCorrection suspenseRoot.toString resolvedDraft
    | throw (IO.userError "publish full suspense resolution")

  let .ok resolvedEvidence ← Loam.ActualAuthority.loadActual? suspenseRoot
    | throw (IO.userError "reload resolved suspense correction")
  let some secondCorrection := resolvedEvidence.corrections.corrections.find?
      (fun correction => correction.target == partialId)
    | throw (IO.userError "find full suspense correction")
  let resolvedId := secondCorrection.replacement
  let some resolvedEvent := EventMemory.findById? resolvedEvidence.events resolvedId
    | throw (IO.userError "resolved suspense replacement missing")

  expect (resolvedEvidence.corrections.corrections.length == 2)
    "suspense resolution did not retain the two-step correction chain"
  expect ((EventMemory.findById? resolvedEvidence.events unresolvedId).isSome)
    "suspense resolution removed the original observation"
  expect ((EventMemory.findById? resolvedEvidence.events partialId).isSome)
    "suspense resolution removed the intermediate observation"
  expect (Event.quantityAt resolvedEvent ⟨"paypay"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta (-5800))
    "full suspense resolution changed physical source quantity"
  expect (Event.quantityAt resolvedEvent ⟨"food"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 1200)
    "full suspense resolution changed already-known food quantity"
  expect (Event.quantityAt resolvedEvent ⟨"books"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 4600)
    "full suspense resolution lost classified quantity"
  expect (Event.quantityAt resolvedEvent ⟨"suspense"⟩ ⟨"jpy"⟩ ==
      Quantity.ofQuanta 0)
    "full suspense resolution left unresolved quantity"

  let .ok suspenseRecords ← Loam.ActualReview.loadRecordsFromActual suspenseRoot
    | throw (IO.userError "reload suspense correction review")
  let suspenseCurrent := Loam.ActualReview.select suspenseRecords (.day "2026-09-23")
  expect (suspenseCurrent.length == 1)
    "resolved suspense day did not have exactly one current Actual"
  expect (suspenseCurrent.any fun record =>
      record.event.id == resolvedId &&
      record.description == "bulk purchase, fully classified" &&
      record.date == some "2026-09-23")
    "resolved suspense review did not expose the final replacement"
  expect (suspenseRecords.any fun record =>
      record.event.id == unresolvedId && !record.isCurrent)
    "original suspense Event disappeared instead of remaining historical"
  expect (suspenseRecords.any fun record =>
      record.event.id == partialId && !record.isCurrent)
    "partial suspense Event disappeared instead of remaining historical"

  IO.println "Correction Publisher: Actual re-read, Measure-preserving USD replacement, suspense partial/full resolution, cross-Measure refusal, sparse replacement identity, fail-closed policy, Relation-source/Discharge refusal, append-only relation, replacement and fresh review passed."
