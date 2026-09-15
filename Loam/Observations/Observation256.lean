import Loam.ActualReview
import Loam.Application.OpenRelationFrontier
import Loam.Observations.Observation255

namespace Loam.Observation256

open Loam.Core

set_option autoImplicit false

/-!
# Observation 256 — concrete register/history query granularity

Observation 255 proved that optional Effect identity can be erased without
changing Event identity, Effect multiplicity, or any physical quantity
projection. This observation asks the next practical question:

> Which concrete register/history questions already close over existing LOAM
> evidence, and where does a stronger identity relation actually become
> necessary?

No production Register type is proposed. The local row projection and fixtures
below are proof instruments only.
-/

/-- One visible physical Effect cell for a register-shaped review row. -/
structure RegisterEffect where
  locus : LocusId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
A register-shaped projection of the information already exposed by
`ActualReview.Record`.

EffectKey is deliberately absent: this row answers what happened at the visible
physical level, not which Effect is durably addressable by another fact.
-/
structure RegisterRow where
  event : EventId
  date : Option String
  description : String
  replacement : Option EventId
  isCurrent : Bool
  effects : List RegisterEffect
deriving Repr, DecidableEq

private def registerEffect (effect : Effect) : RegisterEffect :=
  { locus := effect.locus
    measure := effect.measure
    quantity := effect.quantity }

@[simp] private theorem registerEffect_eraseEffectIdentity (effect : Effect) :
    registerEffect (Loam.Observation255.eraseEffectIdentity effect) =
      registerEffect effect := by
  rfl

/-- Build one register-shaped row from the existing correction-aware review answer. -/
def registerRow (record : Loam.ActualReview.Record) : RegisterRow :=
  { event := record.event.id
    date := record.date
    description := record.description
    replacement := record.replacement
    isCurrent := record.isCurrent
    effects := record.event.effects.map registerEffect }

/-- Erase only optional Effect identity inside one existing review record. -/
def eraseRecordEffectIdentity
    (record : Loam.ActualReview.Record) : Loam.ActualReview.Record :=
  { record with
    event := Loam.Observation255.eraseEventEffectIdentity record.event }

/--
Q1/Q4 boundary: a physical register row is invariant under EffectKey erasure.
The Event, date, description, correction link, currentness, Effect multiplicity,
and every visible physical Effect remain available.
-/
theorem registerRow_eraseEffectIdentity
    (record : Loam.ActualReview.Record) :
    registerRow (eraseRecordEffectIdentity record) = registerRow record := by
  cases record with
  | mk event date description replacement isCurrent =>
      simp [registerRow, eraseRecordEffectIdentity,
        Loam.Observation255.eraseEventEffectIdentity, List.map_map]

/-- The existing textual Effect rendering also ignores optional durable identity. -/
theorem effectText_eraseEffectIdentity (effect : Effect) :
    Loam.ActualReview.effectText (Loam.Observation255.eraseEffectIdentity effect) =
      Loam.ActualReview.effectText effect := by
  rfl

/-! ## Q2 — exact Relation source lookup genuinely needs EffectKey -/

private def relationEventId : EventId := ⟨"o256-relation-event"⟩
private def relationEffectKey : EffectKey := ⟨"o256-relation-effect"⟩
private def relationLocus : LocusId := ⟨"o256-cash"⟩
private def relationMeasure : MeasureId := ⟨"o256-jpy"⟩

private def relationSourceEffect : Effect :=
  Effect.ofQuantity relationEffectKey relationLocus relationMeasure (Quantity.ofQuanta (-10))

private def relationSourceEvent : Event :=
  { id := relationEventId
    effects := [relationSourceEffect]
    keyNodup := by simp [retainedEffectKeys, relationSourceEffect] }

private def relationMemory : EventMemory :=
  { events := [relationSourceEvent]
    idNodup := by simp }

private def relationUnit : RelationUnit :=
  { id := ⟨"o256-relation-unit"⟩
    sourceEvent := relationEventId
    sourceEffect := relationEffectKey
    debtor := .external ⟨"o256-external"⟩
    creditor := .household
    quantity := Quantity.ofQuanta 10 }

/-- The production relation resolver reaches the exact keyed source Effect. -/
theorem relationSource_resolves :
    Loam.Application.relationSourceEffect? relationMemory relationUnit =
      some relationSourceEffect := by
  simp [Loam.Application.relationSourceEffect?, relationMemory, relationUnit,
    relationSourceEvent, relationSourceEffect, relationEventId, relationEffectKey,
    EventMemory.findById?, FiniteKeyed.findBy?]

private def erasedRelationMemory : EventMemory :=
  { events := [Loam.Observation255.eraseEventEffectIdentity relationSourceEvent]
    idNodup := by simp }

/--
The same RelationUnit no longer resolves after Effect identity is erased. This
is the concrete query class that pays for `(EventId, EffectKey)`.
-/
theorem relationSource_fails_afterEffectIdentityErasure :
    Loam.Application.relationSourceEffect? erasedRelationMemory relationUnit = none := by
  simp [Loam.Application.relationSourceEffect?, erasedRelationMemory, relationUnit,
    relationSourceEvent, relationSourceEffect, relationEventId, relationEffectKey,
    Loam.Observation255.eraseEventEffectIdentity,
    Loam.Observation255.eraseEffectIdentity,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-! ## Q3 — EventCorrection does not define cross-Event Effect continuity -/

private def originalEventId : EventId := ⟨"o256-original"⟩
private def replacementEventId : EventId := ⟨"o256-replacement"⟩
private def leftKey : EffectKey := ⟨"o256-left"⟩
private def rightKey : EffectKey := ⟨"o256-right"⟩
private def cashLocus : LocusId := ⟨"o256-cash-locus"⟩
private def goodsLocus : LocusId := ⟨"o256-goods-locus"⟩
private def yen : MeasureId := ⟨"o256-yen"⟩

private def originalEvent : Event :=
  { id := originalEventId
    effects :=
      [ Effect.ofQuantity leftKey cashLocus yen (Quantity.ofQuanta (-1))
      , Effect.ofQuantity rightKey goodsLocus yen (Quantity.ofQuanta 1) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

/-- One valid replacement reuses the two local keys on the same physical sides. -/
private def replacementAligned : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofQuantity leftKey cashLocus yen (Quantity.ofQuanta (-1))
      , Effect.ofQuantity rightKey goodsLocus yen (Quantity.ofQuanta 1) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

/--
Another valid replacement has exactly the same physical Effects but swaps the
Event-local keys. Nothing in EventCorrection forbids this because the correction
edge joins Events, not Effects.
-/
private def replacementSwapped : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofQuantity rightKey cashLocus yen (Quantity.ofQuanta (-1))
      , Effect.ofQuantity leftKey goodsLocus yen (Quantity.ofQuanta 1) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

private def movementCorrection : EventCorrection :=
  { target := originalEventId
    replacement := replacementEventId }

/-- Both candidate replacements have the same physical cash observation. -/
theorem correctionCandidates_sameCashQuantity :
    Event.quantityAt replacementAligned cashLocus yen =
      Event.quantityAt replacementSwapped cashLocus yen := by
  rfl

/-- Both candidate replacements have the same physical goods observation. -/
theorem correctionCandidates_sameGoodsQuantity :
    Event.quantityAt replacementAligned goodsLocus yen =
      Event.quantityAt replacementSwapped goodsLocus yen := by
  rfl

/-- In the aligned replacement, the left key names the cash Effect. -/
theorem alignedLeftKey_namesCash :
    Loam.Observation255.findInEventByKey? replacementAligned leftKey =
      some (Effect.ofQuantity leftKey cashLocus yen (Quantity.ofQuanta (-1))) := by
  simp [Loam.Observation255.findInEventByKey?, Loam.Observation255.findByKey?,
    replacementAligned, leftKey, rightKey]

/-- In the swapped replacement, the same local key names the goods Effect. -/
theorem swappedLeftKey_namesGoods :
    Loam.Observation255.findInEventByKey? replacementSwapped leftKey =
      some (Effect.ofQuantity leftKey goodsLocus yen (Quantity.ofQuanta 1)) := by
  simp [Loam.Observation255.findInEventByKey?, Loam.Observation255.findByKey?,
    replacementSwapped, leftKey, rightKey]

private def alignedCorrectionMemory : EventMemory :=
  { events := [originalEvent, replacementAligned]
    idNodup := by simp [originalEvent, replacementAligned, originalEventId, replacementEventId] }

private def swappedCorrectionMemory : EventMemory :=
  { events := [originalEvent, replacementSwapped]
    idNodup := by simp [originalEvent, replacementSwapped, originalEventId, replacementEventId] }

/-- The same Event-level correction edge closes over the aligned replacement world. -/
theorem correction_projects_aligned :
    EventCorrection.project? alignedCorrectionMemory movementCorrection =
      some { correction := movementCorrection
             original := originalEvent
             effective := replacementAligned } := by
  simp [EventCorrection.project?, alignedCorrectionMemory, movementCorrection,
    originalEvent, replacementAligned, originalEventId, replacementEventId,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-- The same Event-level correction edge also closes over the swapped-key world. -/
theorem correction_projects_swapped :
    EventCorrection.project? swappedCorrectionMemory movementCorrection =
      some { correction := movementCorrection
             original := originalEvent
             effective := replacementSwapped } := by
  simp [EventCorrection.project?, swappedCorrectionMemory, movementCorrection,
    originalEvent, replacementSwapped, originalEventId, replacementEventId,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-!
The paired witnesses above classify the concrete query:

* "show this Event and its physical Effects" closes below Effect identity;
* "show the exact Effect referenced by this Relation" requires EventId + EffectKey;
* "which Effect after correction is the same Effect as before correction?" is
  not determined by EventCorrection plus Event-local EffectKey reuse;
* a correction-aware occurrence-date register can be projected from
  `ActualReview.Record`, but capture/arrival order is not thereby recovered.

The last boundary follows the existing Core law that EventMemory list position is
representation only, while `ActualReview` orders review selections from retained
occurrence date and EventId rather than treating storage position as chronology.
-/

end Loam.Observation256
