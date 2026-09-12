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

  -- Collector-local keys on an ordinary movement must not become canonical identity.
  let ordinary : Loam.MovementAdmission.Draft := {
    validOn := "2026-09-12"
    description := some "ordinary"
    effects := [keyedEffect "temp-1" "cash" (-100), keyedEffect "temp-2" "food" 100]
    relations := []
    discharges := []
    total := 100
  }
  let .ok ordinaryReceipt ← Loam.MovementPublisher.publishDraft root.toString ordinary
    | throw (IO.userError "publish ordinary movement")
  let .ok afterOrdinary ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload ordinary movement")
  let ordinaryEvent ← requireSome (afterOrdinary.events.findById? ordinaryReceipt.eventId)
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
  let .ok relatedReceipt ← Loam.MovementPublisher.publishDraft root.toString related
    | throw (IO.userError "publish related movement")
  let .ok afterRelated ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload related movement")
  let relatedEvent ← requireSome (afterRelated.events.findById? relatedReceipt.eventId)
    "related event missing"
  expect (relatedEvent.effects.any fun effect => effect.key == some sourceKey)
    "relation source EffectKey was not retained"
  expect (relatedEvent.effects.any fun effect => effect.key.isNone)
    "unreferenced peer EffectKey was retained"
  expect (relatedEvent.effects.filterMap (fun effect => effect.key) == [sourceKey])
    "publication retained more EffectKeys than Relation semantics require"

  IO.println "Sparse Movement publication: anonymous ordinary Effects and relation-only key promotion passed."
