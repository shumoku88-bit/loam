import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.MovementPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def keyedEffect (key locus : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quantity)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let vocabulary ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"cash"⟩, ⟨"food"⟩]) "vocabulary"
  return {
    events := { events := [], idNodup := by simp }
    validity := { facts := [], factRefNodup := by simp, corrections := [], correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk path
  let world ← emptyWorld
  let .ok () ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "initialize Actual authority")

  -- Admission itself owns collector-local Effect-key canonicalization. Two ordinary
  -- Effects may reuse one temporary collector handle when no Relation earns that
  -- identity; preview and production therefore see the same canonical draft shape.
  let duplicateTemporaryKey : EffectKey := ⟨"temp-shared"⟩
  let duplicateTemporary : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "preview canonicalization"
    effects := [
      Effect.ofQuantity duplicateTemporaryKey ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100)),
      Effect.ofQuantity duplicateTemporaryKey ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)]
    relations := []
    discharges := []
    total := 100
  }
  let .ok previewAdmitted := Loam.MovementAdmission.admit? world duplicateTemporary
    | throw (IO.userError "admission did not canonicalize duplicate temporary EffectKeys")
  let previewEvent ← requireSome
    (previewAdmitted.world.events.findById? previewAdmitted.eventId)
    "admitted preview event missing"
  expect (previewEvent.effects.all fun effect => effect.key.isNone)
    "admission retained collector-local EffectKey without Relation evidence"

  -- Conversely, explicit Relation evidence earns stable source identity inside the
  -- same pure admission boundary; canonicalization must not erase that source key.
  let earnedKey : EffectKey := ⟨"temp-earned"⟩
  let earnedIdentity : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "earned identity"
    effects := [
      Effect.ofQuantity earnedKey ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100),
      keyedEffect "temp-unearned" "cash" (-100)]
    relations := [{
      sourceEffect := earnedKey
      debtor := .external ⟨"friend-preview"⟩
      creditor := .household
      quantity := Quantity.ofQuanta 50 }]
    discharges := []
    total := 100
  }
  let .ok earnedAdmitted := Loam.MovementAdmission.admit? world earnedIdentity
    | throw (IO.userError "admission erased relation-earned Effect identity")
  let earnedEvent ← requireSome
    (earnedAdmitted.world.events.findById? earnedAdmitted.eventId)
    "relation-earned preview event missing"
  expect (earnedEvent.effects.any fun effect => effect.key == some earnedKey)
    "admission did not retain Relation source EffectKey"
  expect (earnedEvent.effects.filterMap (fun effect => effect.key) == [earnedKey])
    "admission retained more EffectKeys than Relation semantics require"

  -- G2-011: the retained knownPositive Relation gate remains the authoritative
  -- refusal after the redundant whole-Event source-resolution pass is removed.
  -- A RelationDraft naming no Effect in the Movement must still fail closed.
  let missingSource : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "missing relation source"
    effects := [
      keyedEffect "temp-left" "cash" (-100),
      keyedEffect "temp-right" "food" 100]
    relations := [{
      sourceEffect := ⟨"temp-missing"⟩
      debtor := .external ⟨"friend-missing"⟩
      creditor := .household
      quantity := Quantity.ofQuanta 50 }]
    discharges := []
    total := 100
  }
  match Loam.MovementAdmission.admit? world missingSource with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Relation with missing source Effect was admitted")

  -- Collector-local keys on an ordinary movement must not become canonical identity.
  let ordinary : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "ordinary"
    effects := [keyedEffect "temp-1" "cash" (-100), keyedEffect "temp-2" "food" 100]
    relations := []
    discharges := []
    total := 100
  }
  let .ok ordinaryEventId ← Loam.MovementPublisher.publishDraft root.toString ordinary
    | throw (IO.userError "publish ordinary movement")
  let .ok afterOrdinary ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload ordinary movement")
  let ordinaryEvent ← requireSome (afterOrdinary.events.findById? ordinaryEventId)
    "ordinary event missing"
  expect (ordinaryEvent.effects.all fun effect => effect.key.isNone)
    "unreferenced collector key became canonical EffectKey"

  -- A key named by Relation evidence is promoted, while its peer stays anonymous.
  let sourceKey : EffectKey := ⟨"temp-source"⟩
  let related : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "related"
    effects := [
      Effect.ofQuantity sourceKey ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100),
      keyedEffect "temp-peer" "cash" (-100)]
    relations := [{
      sourceEffect := sourceKey
      debtor := .external ⟨"friend"⟩
      creditor := .household
      quantity := Quantity.ofQuanta 50 }]
    discharges := []
    total := 100
  }
  let .ok relatedEventId ← Loam.MovementPublisher.publishDraft root.toString related
    | throw (IO.userError "publish related movement")
  let .ok afterRelated ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload related movement")
  let relatedEvent ← requireSome (afterRelated.events.findById? relatedEventId)
    "related event missing"
  expect (relatedEvent.effects.any fun effect => effect.key == some sourceKey)
    "relation source EffectKey was not retained"
  expect (relatedEvent.effects.any fun effect => effect.key.isNone)
    "unreferenced peer EffectKey was retained"
  expect (relatedEvent.effects.filterMap (fun effect => effect.key) == [sourceKey])
    "publication retained more EffectKeys than Relation semantics require"

  IO.println "Sparse Movement publication: admission canonicalization, relation-earned identity, missing-source refusal, anonymous ordinary Effects and relation-only key promotion passed."