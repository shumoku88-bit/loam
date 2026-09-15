import Loam.Core.Event

namespace Loam.Observation255

open Loam.Core

set_option autoImplicit false

/-!
# Observation 255 — query granularity under sparse Effect identity

Observation 254 showed that balance and event-indexed aggregate views can both
forget retained history. Observation 166 had already established a different
boundary: `EventId` alone cannot name one Effect, while `(EventId, EffectKey)` is
the existing minimum durable coordinate when one Effect must be referenced.

This observation asks a narrower question directly against current Core:

> What information survives when optional Effect identity is erased, and what
> class of query therefore actually needs `EffectKey`?

No new production query API is proposed here. The local erasure and lookup
functions are proof instruments only.
-/

/-- Forget only optional durable Effect identity. Physical coordinates and quantity remain. -/
def eraseEffectIdentity (effect : Effect) : Effect :=
  { effect with key := none }

@[simp] theorem eraseEffectIdentity_key (effect : Effect) :
    (eraseEffectIdentity effect).key = none :=
  rfl

@[simp] theorem eraseEffectIdentity_locus (effect : Effect) :
    (eraseEffectIdentity effect).locus = effect.locus :=
  rfl

@[simp] theorem eraseEffectIdentity_measure (effect : Effect) :
    (eraseEffectIdentity effect).measure = effect.measure :=
  rfl

@[simp] theorem eraseEffectIdentity_quantity (effect : Effect) :
    (eraseEffectIdentity effect).quantity = effect.quantity :=
  rfl

@[simp] theorem eraseEffectIdentity_coordinate (effect : Effect) :
    (eraseEffectIdentity effect).coordinate = effect.coordinate :=
  rfl

/--
Erase every optional Effect key while preserving the Event identity and the
physical Effect list. The Event-local retained-key uniqueness proof becomes
trivial because no retained keys remain.
-/
def eraseEventEffectIdentity (event : Event) : Event :=
  { id := event.id
    effects := event.effects.map eraseEffectIdentity
    keyNodup := by
      induction event.effects with
      | nil => simp [retainedEffectKeys]
      | cons effect rest ih =>
          simp [retainedEffectKeys, eraseEffectIdentity, ih] }

@[simp] theorem eraseEventEffectIdentity_id (event : Event) :
    (eraseEventEffectIdentity event).id = event.id :=
  rfl

@[simp] theorem eraseEventEffectIdentity_effectCount (event : Event) :
    (eraseEventEffectIdentity event).effects.length = event.effects.length := by
  simp [eraseEventEffectIdentity]

@[simp] theorem eraseEventEffectIdentity_retainedKeys (event : Event) :
    retainedEffectKeys (eraseEventEffectIdentity event).effects = [] := by
  induction event.effects with
  | nil => simp [eraseEventEffectIdentity, retainedEffectKeys]
  | cons effect rest ih =>
      simp [eraseEventEffectIdentity, retainedEffectKeys, eraseEffectIdentity, ih]

private theorem quantityFold_eraseIdentity
    (effects : List Effect) (locus : LocusId) (measure : MeasureId) :
    (effects.map eraseEffectIdentity).foldr
        (fun effect total =>
          if effect.coordinate = ⟨locus, measure⟩ then
            effect.quantity.quanta + total
          else
            total)
        0 =
      effects.foldr
        (fun effect total =>
          if effect.coordinate = ⟨locus, measure⟩ then
            effect.quantity.quanta + total
          else
            total)
        0 := by
  induction effects with
  | nil => rfl
  | cons effect rest ih =>
      simp [ih]

/--
Event-level physical quantity queries do not require retained Effect identity.
Erasing every `EffectKey` leaves every `LocusId × MeasureId` quantity exactly
unchanged.
-/
theorem quantityAt_eraseEventEffectIdentity
    (event : Event) (locus : LocusId) (measure : MeasureId) :
    Event.quantityAt (eraseEventEffectIdentity event) locus measure =
      Event.quantityAt event locus measure := by
  unfold Event.quantityAt
  change
    Quantity.ofQuanta
        ((event.effects.map eraseEffectIdentity).foldr
          (fun effect total =>
            if effect.coordinate = ⟨locus, measure⟩ then
              effect.quantity.quanta + total
            else
              total)
          0) =
      Quantity.ofQuanta
        (event.effects.foldr
          (fun effect total =>
            if effect.coordinate = ⟨locus, measure⟩ then
              effect.quantity.quanta + total
            else
              total)
          0)
  rw [quantityFold_eraseIdentity]

/-- Research-only lookup by one retained Event-local Effect key. -/
def findByKey? : List Effect → EffectKey → Option Effect
  | [], _ => none
  | effect :: rest, key =>
      if effect.key = some key then
        some effect
      else
        findByKey? rest key

/-- Event identity scopes the key lookup; `EffectKey` is not promoted to global identity. -/
def findInEventByKey? (event : Event) (key : EffectKey) : Option Effect :=
  findByKey? event.effects key

private theorem findByKey?_eraseIdentity
    (effects : List Effect) (key : EffectKey) :
    findByKey? (effects.map eraseEffectIdentity) key = none := by
  induction effects with
  | nil => rfl
  | cons effect rest ih =>
      simp [findByKey?, ih]

/--
A query that asks for one durably named Effect genuinely depends on retained
Effect identity: after erasure no key lookup can resolve, even though EventId,
Effect multiplicity, coordinates, and quantities still survive.
-/
theorem findInEventByKey?_eraseEventEffectIdentity
    (event : Event) (key : EffectKey) :
    findInEventByKey? (eraseEventEffectIdentity event) key = none := by
  unfold findInEventByKey? eraseEventEffectIdentity
  exact findByKey?_eraseIdentity event.effects key

/-- A retained key resolves the selected Effect before identity erasure. -/
theorem keyedSingleton_resolves
    (id : EventId) (key : EffectKey)
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    findInEventByKey?
      { id := id
        effects := [Effect.ofQuantity key locus measure quantity]
        keyNodup := by simp [retainedEffectKeys] }
      key = some (Effect.ofQuantity key locus measure quantity) := by
  simp [findInEventByKey?, findByKey?]

/--
Identifying an ordinary Effect changes addressability but not its physical
coordinate or exact quantity. This is the intended pressure valve: durable
identity can be earned only when a later query needs to name the Effect.
-/
theorem identify_changes_reference_not_physical_observation
    (effect : Effect) (key : EffectKey) :
    (Effect.identify effect key).key = some key ∧
      (Effect.identify effect key).coordinate = effect.coordinate ∧
      (Effect.identify effect key).quantity = effect.quantity := by
  exact ⟨rfl, rfl, rfl⟩

end Loam.Observation255
