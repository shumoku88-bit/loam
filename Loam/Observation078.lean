import Loam.Core.EventMemory

namespace Loam.Observation078

open Loam.Core

set_option autoImplicit false

/--
A run-local rekeying changes only Effect identity. The observed locus, measure,
and exact quantity remain untouched.
-/
private def rekeyEffect (newKey : EffectKey) (effect : Effect) : Effect :=
  { effect with key := newKey }

@[simp] private theorem rekeyEffect_coordinate
    (newKey : EffectKey) (effect : Effect) :
    (rekeyEffect newKey effect).coordinate = effect.coordinate := by
  rfl

@[simp] private theorem rekeyEffect_quantity
    (newKey : EffectKey) (effect : Effect) :
    (rekeyEffect newKey effect).quantity = effect.quantity := by
  rfl

/--
The Event identifier is not observed by `Event.quantityAt`.

This is a general theorem, not a bounded witness: replacing only Event identity
cannot change any locus/measure quantity projection.
-/
theorem quantityAt_ignores_event_id
    (event : Event) (newId : EventId)
    (locus : LocusId) (measure : MeasureId) :
    Event.quantityAt { event with id := newId } locus measure =
      Event.quantityAt event locus measure := by
  rfl

/--
For one Effect, replacing only the Effect key cannot change its quantity
projection. This representative theorem keeps the Event admissible on both
sides and therefore exercises the actual Practical Core constructor shape.
-/
theorem quantityAt_single_effect_ignores_identity
    (oldId newId : EventId)
    (oldKey newKey : EffectKey)
    (effectLocus queryLocus : LocusId)
    (effectMeasure queryMeasure : MeasureId)
    (quantity : Quantity) :
    Event.quantityAt
        { id := oldId,
          effects :=
            [Effect.ofQuantity oldKey effectLocus effectMeasure quantity],
          keyNodup := by simp }
        queryLocus queryMeasure =
      Event.quantityAt
        { id := newId,
          effects :=
            [Effect.ofQuantity newKey effectLocus effectMeasure quantity],
          keyNodup := by simp }
        queryLocus queryMeasure := by
  simp [Event.quantityAt, Effect.coordinate]

/--
Two distinct Effects can be given different run-local keys without changing the
observed quantity. The keys only need to remain distinct enough for Event
admission during this run.
-/
theorem quantityAt_two_effects_ignores_identity
    (oldId newId : EventId)
    (oldLeftKey oldRightKey newLeftKey newRightKey : EffectKey)
    (hOldKeys : oldLeftKey ≠ oldRightKey)
    (hNewKeys : newLeftKey ≠ newRightKey)
    (leftLocus rightLocus queryLocus : LocusId)
    (leftMeasure rightMeasure queryMeasure : MeasureId)
    (leftQuantity rightQuantity : Quantity) :
    Event.quantityAt
        { id := oldId,
          effects :=
            [Effect.ofQuantity oldLeftKey leftLocus leftMeasure leftQuantity,
             Effect.ofQuantity oldRightKey rightLocus rightMeasure rightQuantity],
          keyNodup := by simp [hOldKeys] }
        queryLocus queryMeasure =
      Event.quantityAt
        { id := newId,
          effects :=
            [Effect.ofQuantity newLeftKey leftLocus leftMeasure leftQuantity,
             Effect.ofQuantity newRightKey rightLocus rightMeasure rightQuantity],
          keyNodup := by simp [hNewKeys] }
        queryLocus queryMeasure := by
  simp [Event.quantityAt, Effect.coordinate]

/--
The same identity-insensitivity survives the recorded-memory aggregation for a
single Event. A fresh run-local EventId and fresh run-local EffectKey do not
change the recorded quantity answer.
-/
theorem quantityAtRecorded_singleton_ignores_identity
    (oldId newId : EventId)
    (oldKey newKey : EffectKey)
    (effectLocus queryLocus : LocusId)
    (effectMeasure queryMeasure : MeasureId)
    (quantity : Quantity) :
    EventMemory.quantityAtRecorded
        { events :=
            [{ id := oldId,
               effects :=
                 [Effect.ofQuantity oldKey effectLocus effectMeasure quantity],
               keyNodup := by simp }],
          idNodup := by simp }
        queryLocus queryMeasure =
      EventMemory.quantityAtRecorded
        { events :=
            [{ id := newId,
               effects :=
                 [Effect.ofQuantity newKey effectLocus effectMeasure quantity],
               keyNodup := by simp }],
          idNodup := by simp }
        queryLocus queryMeasure := by
  simp

/--
Identity-sensitive operations remain outside the stateless-shadow allowance.
Looking up an old stable EventId after replacing that identity does not find the
renamed Event.

This negative boundary is why a run-local identity must never be persisted,
used for correction/reconciliation continuity, or presented as imported stable
identity.
-/
theorem findById_observes_identity
    (oldId newId : EventId)
    (hDifferent : oldId ≠ newId)
    (key : EffectKey)
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    let oldEvent : Event :=
      { id := oldId,
        effects := [Effect.ofQuantity key locus measure quantity],
        keyNodup := by simp }
    let newEvent : Event :=
      { id := newId,
        effects := [Effect.ofQuantity key locus measure quantity],
        keyNodup := by simp }
    EventMemory.findById?
        { events := [oldEvent], idNodup := by simp }
        oldId = some oldEvent ∧
      EventMemory.findById?
        { events := [newEvent], idNodup := by simp }
        oldId = none := by
  dsimp
  constructor
  · simp
  · exact EventMemory.findById?_singleton_other _ _ hDifferent.symm

end Loam.Observation078
