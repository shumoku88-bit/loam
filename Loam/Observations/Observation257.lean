import Loam.Core.EventCorrection
import Loam.Observations.Observation255

namespace Loam.Observation257

open Loam.Core

set_option autoImplicit false

/-!
# Observation 257 — correction change explanation without Effect lineage

Observation 256 showed that `EventCorrection` does not determine cross-Event
Effect continuity. This observation asks whether a weaker and more practical
question already closes over retained physical evidence:

> At one `LocusId × MeasureId` coordinate, what exact quantity changed between
> the original Event and the replacement Event?

The observation deliberately does not pair Effects across Events. It compares
only the two already-retained Event projections.
-/

/-- Exact signed change at one physical coordinate: replacement minus original. -/
def quantityDeltaQuanta
    (original replacement : Event)
    (locus : LocusId) (measure : MeasureId) : Int :=
  (Event.quantityAt replacement locus measure).quanta -
    (Event.quantityAt original locus measure).quanta

/-- A display-oriented row for one queried coordinate. Research-only. -/
structure CoordinateDelta where
  coordinate : EffectCoordinate
  before : Quantity
  after : Quantity
  deltaQuanta : Int
deriving Repr, DecidableEq

/-- Project one coordinate into before / after / exact signed delta. -/
def deltaAt
    (original replacement : Event)
    (locus : LocusId) (measure : MeasureId) : CoordinateDelta :=
  let before := Event.quantityAt original locus measure
  let after := Event.quantityAt replacement locus measure
  { coordinate := ⟨locus, measure⟩
    before := before
    after := after
    deltaQuanta := after.quanta - before.quanta }

/-- `deltaAt` and the scalar delta agree by construction. -/
@[simp] theorem deltaAt_deltaQuanta
    (original replacement : Event)
    (locus : LocusId) (measure : MeasureId) :
    (deltaAt original replacement locus measure).deltaQuanta =
      quantityDeltaQuanta original replacement locus measure :=
  rfl

/--
Sparse Effect identity is irrelevant to coordinate change explanation.
Erasing every optional EffectKey on both Events leaves the exact delta unchanged.
-/
theorem quantityDeltaQuanta_eraseEffectIdentity
    (original replacement : Event)
    (locus : LocusId) (measure : MeasureId) :
    quantityDeltaQuanta
        (Loam.Observation255.eraseEventEffectIdentity original)
        (Loam.Observation255.eraseEventEffectIdentity replacement)
        locus measure =
      quantityDeltaQuanta original replacement locus measure := by
  unfold quantityDeltaQuanta
  rw [Loam.Observation255.quantityAt_eraseEventEffectIdentity]
  rw [Loam.Observation255.quantityAt_eraseEventEffectIdentity]

/-- The full before / after / delta row is likewise independent of EffectKey. -/
theorem deltaAt_eraseEffectIdentity
    (original replacement : Event)
    (locus : LocusId) (measure : MeasureId) :
    deltaAt
        (Loam.Observation255.eraseEventEffectIdentity original)
        (Loam.Observation255.eraseEventEffectIdentity replacement)
        locus measure =
      deltaAt original replacement locus measure := by
  unfold deltaAt
  rw [Loam.Observation255.quantityAt_eraseEventEffectIdentity]
  rw [Loam.Observation255.quantityAt_eraseEventEffectIdentity]

/--
If two candidate replacement Events have the same physical quantity at the
queried coordinate, they necessarily give the same correction delta there.
No Effect pairing premise is required.
-/
theorem delta_eq_of_replacement_quantity_eq
    (original left right : Event)
    (locus : LocusId) (measure : MeasureId)
    (hSame : Event.quantityAt left locus measure =
      Event.quantityAt right locus measure) :
    quantityDeltaQuanta original left locus measure =
      quantityDeltaQuanta original right locus measure := by
  simp [quantityDeltaQuanta, hSame]

/-! ## Concrete correction witness -/

private def originalEventId : EventId := ⟨"o257-original"⟩
private def replacementEventId : EventId := ⟨"o257-replacement"⟩
private def leftKey : EffectKey := ⟨"o257-left"⟩
private def rightKey : EffectKey := ⟨"o257-right"⟩
private def cash : LocusId := ⟨"o257-cash"⟩
private def food : LocusId := ⟨"o257-food"⟩
private def yen : MeasureId := ⟨"o257-yen"⟩

private def originalEvent : Event :=
  { id := originalEventId
    effects :=
      [ Effect.ofQuantity leftKey cash yen (Quantity.ofQuanta (-1000))
      , Effect.ofQuantity rightKey food yen (Quantity.ofQuanta 1000) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

/-- Candidate world A: local keys stay on the same physical coordinates. -/
private def replacementAligned : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofQuantity leftKey cash yen (Quantity.ofQuanta (-800))
      , Effect.ofQuantity rightKey food yen (Quantity.ofQuanta 800) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

/-- Candidate world B: identical physical replacement, but Event-local keys swap. -/
private def replacementSwapped : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofQuantity rightKey cash yen (Quantity.ofQuanta (-800))
      , Effect.ofQuantity leftKey food yen (Quantity.ofQuanta 800) ]
    keyNodup := by simp [retainedEffectKeys, leftKey, rightKey] }

private def correction : EventCorrection :=
  { target := originalEventId
    replacement := replacementEventId }

private def alignedMemory : EventMemory :=
  { events := [originalEvent, replacementAligned]
    idNodup := by
      simp [originalEvent, replacementAligned, originalEventId, replacementEventId] }

private def swappedMemory : EventMemory :=
  { events := [originalEvent, replacementSwapped]
    idNodup := by
      simp [originalEvent, replacementSwapped, originalEventId, replacementEventId] }

/-- The same EventCorrection closes over the aligned world. -/
theorem correction_projects_aligned :
    EventCorrection.project? alignedMemory correction =
      some { correction := correction
             original := originalEvent
             effective := replacementAligned } := by
  simp [EventCorrection.project?, alignedMemory, correction,
    originalEvent, replacementAligned, originalEventId, replacementEventId,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-- The same EventCorrection also closes over the key-swapped world. -/
theorem correction_projects_swapped :
    EventCorrection.project? swappedMemory correction =
      some { correction := correction
             original := originalEvent
             effective := replacementSwapped } := by
  simp [EventCorrection.project?, swappedMemory, correction,
    originalEvent, replacementSwapped, originalEventId, replacementEventId,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-- Both worlds explain the cash coordinate as an exact +200 quanta change. -/
theorem cash_delta_aligned :
    quantityDeltaQuanta originalEvent replacementAligned cash yen = 200 := by
  simp [quantityDeltaQuanta, originalEvent, replacementAligned, cash, food, yen,
    Event.quantityAt, Effect.coordinate, leftKey, rightKey]

theorem cash_delta_swapped :
    quantityDeltaQuanta originalEvent replacementSwapped cash yen = 200 := by
  simp [quantityDeltaQuanta, originalEvent, replacementSwapped, cash, food, yen,
    Event.quantityAt, Effect.coordinate, leftKey, rightKey]

/-- Both worlds explain the food coordinate as an exact -200 quanta change. -/
theorem food_delta_aligned :
    quantityDeltaQuanta originalEvent replacementAligned food yen = -200 := by
  simp [quantityDeltaQuanta, originalEvent, replacementAligned, cash, food, yen,
    Event.quantityAt, Effect.coordinate, leftKey, rightKey]

theorem food_delta_swapped :
    quantityDeltaQuanta originalEvent replacementSwapped food yen = -200 := by
  simp [quantityDeltaQuanta, originalEvent, replacementSwapped, cash, food, yen,
    Event.quantityAt, Effect.coordinate, leftKey, rightKey]

/--
The selected coordinate-delta explanation is identical even though the local
EffectKey-to-coordinate assignment differs across the two replacement worlds.
This is the intended boundary: physical correction change is explainable without
inventing cross-Event Effect lineage.
-/
theorem selected_coordinate_deltas_ignore_lineage_choice :
    quantityDeltaQuanta originalEvent replacementAligned cash yen =
        quantityDeltaQuanta originalEvent replacementSwapped cash yen ∧
      quantityDeltaQuanta originalEvent replacementAligned food yen =
        quantityDeltaQuanta originalEvent replacementSwapped food yen := by
  exact ⟨cash_delta_aligned.trans cash_delta_swapped.symm,
    food_delta_aligned.trans food_delta_swapped.symm⟩

/-!
Observation boundary:

* coordinate-level before / after / exact delta needs no EffectKey and no lineage;
* EventCorrection still supplies the explicit original -> replacement Event edge;
* equal coordinate deltas do not recover which Effect became which Effect;
* internal Effect rearrangements that cancel at one coordinate can remain hidden
  by this projection, exactly as expected from the information-loss results of
  Observations 254–256.

A production cross-Event Effect correspondence is therefore not earned merely to
explain ordinary physical correction changes.
-/

end Loam.Observation257
