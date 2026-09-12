import Loam.Core.Event

namespace Loam.Tests.SparseEffectIdentityModel

open Loam.Core

set_option autoImplicit false

/--
Research-only candidate for the minimum production Effect shape implied by the
normalized Actual experiments.

`none` means the physical effect has no independently referenced identity.
`some key` means later retained evidence may name this exact effect.
-/
structure SparseEffect where
  key : Option EffectKey
  locus : LocusId
  amount : SomeAmount

namespace SparseEffect

/-- Construct one physical effect with optional durable identity. -/
def ofQuantity
    (key : Option EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) : SparseEffect :=
  ⟨key, locus, SomeAmount.ofQuantity measure quantity⟩

/-- The measure coordinate is independent of EffectKey presence. -/
def measure (effect : SparseEffect) : MeasureId :=
  effect.amount.measure

/-- The exact signed quantity is independent of EffectKey presence. -/
def quantity (effect : SparseEffect) : Quantity :=
  effect.amount.quantity

/-- Physical projection coordinate. -/
def coordinate (effect : SparseEffect) : EffectCoordinate :=
  ⟨effect.locus, effect.measure⟩

/-- Promote one previously anonymous effect to durable identity. -/
def identify (effect : SparseEffect) (key : EffectKey) : SparseEffect :=
  { effect with key := some key }

@[simp] theorem coordinate_identify
    (effect : SparseEffect) (key : EffectKey) :
    (identify effect key).coordinate = effect.coordinate :=
  rfl

@[simp] theorem quantity_identify
    (effect : SparseEffect) (key : EffectKey) :
    (identify effect key).quantity = effect.quantity :=
  rfl

end SparseEffect

/-- Only durable keys participate in the Event-local uniqueness law. -/
def keyedKeys (effects : List SparseEffect) : List EffectKey :=
  effects.filterMap SparseEffect.key

/--
Candidate Event law: anonymous effects may repeat freely; every retained stable
EffectKey remains unique inside its Event.
-/
structure SparseEvent where
  id : EventId
  effects : List SparseEffect
  keyNodup : (keyedKeys effects).Nodup

namespace SparseEvent

/-- Admit exactly when the retained stable EffectKeys are unique. -/
def ofEffects? (id : EventId) (effects : List SparseEffect) : Option SparseEvent :=
  if h : (keyedKeys effects).Nodup then
    some { id := id, effects := effects, keyNodup := h }
  else
    none

/-- Find only an effect that explicitly retained the requested stable key. -/
def findByKey? : List SparseEffect → EffectKey → Option SparseEffect
  | [], _ => none
  | effect :: rest, key =>
      if effect.key = some key then
        some effect
      else
        findByKey? rest key

/-- Physical quantity projection does not inspect EffectKey at all. -/
def quantityAtEffects
    (effects : List SparseEffect) (locus : LocusId) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    effects.foldr
      (fun effect total =>
        if effect.coordinate = ⟨locus, measure⟩ then
          effect.quantity.quanta + total
        else
          total)
      0

/-- Event-level physical quantity projection. -/
def quantityAt (event : SparseEvent) (locus : LocusId) (measure : MeasureId) : Quantity :=
  quantityAtEffects event.effects locus measure

/-- Multiple ordinary keyless effects are admissible, even at one coordinate. -/
theorem twoAnonymousSameCoordinateAdmitted
    (id : EventId) (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [SparseEffect.ofQuantity none locus measure left,
       SparseEffect.ofQuantity none locus measure right]).isSome = true := by
  simp [ofEffects?, keyedKeys, SparseEffect.ofQuantity]

/-- Reusing one retained stable key is still rejected. -/
theorem duplicateStableKeyRejected
    (id : EventId) (key : EffectKey)
    (leftLocus rightLocus : LocusId)
    (measure : MeasureId) (left right : Quantity) :
    ofEffects? id
      [SparseEffect.ofQuantity (some key) leftLocus measure left,
       SparseEffect.ofQuantity (some key) rightLocus measure right] = none := by
  simp [ofEffects?, keyedKeys, SparseEffect.ofQuantity]

/-- Distinct retained keys remain admissible at the same physical coordinate. -/
theorem distinctStableKeysSameCoordinateAdmitted
    (id : EventId) (leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [SparseEffect.ofQuantity (some leftKey) locus measure left,
       SparseEffect.ofQuantity (some rightKey) locus measure right]).isSome = true := by
  simp [ofEffects?, keyedKeys, SparseEffect.ofQuantity, hDifferent]

/-- An anonymous effect does not consume or collide with a retained key. -/
theorem anonymousAndStableKeyAdmitted
    (id : EventId) (key : EffectKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [SparseEffect.ofQuantity none locus measure left,
       SparseEffect.ofQuantity (some key) locus measure right]).isSome = true := by
  simp [ofEffects?, keyedKeys, SparseEffect.ofQuantity]

/-- Relation-style lookup skips anonymous effects and resolves the keyed source. -/
theorem findByKeySkipsAnonymous
    (key : EffectKey) (locus : LocusId) (measure : MeasureId)
    (anonymousQuantity keyedQuantity : Quantity) :
    findByKey?
      [SparseEffect.ofQuantity none locus measure anonymousQuantity,
       SparseEffect.ofQuantity (some key) locus measure keyedQuantity]
      key =
      some (SparseEffect.ofQuantity (some key) locus measure keyedQuantity) := by
  simp [findByKey?, SparseEffect.ofQuantity]

/-- An Event containing only anonymous effects cannot accidentally satisfy a key lookup. -/
theorem anonymousCannotResolveStableKey
    (key : EffectKey) (locus : LocusId) (measure : MeasureId)
    (quantity : Quantity) :
    findByKey?
      [SparseEffect.ofQuantity none locus measure quantity]
      key = none := by
  simp [findByKey?, SparseEffect.ofQuantity]

/-- Adding or changing optional identity cannot change physical quantity projection. -/
theorem quantityProjectionIgnoresIdentity
    (leftKey rightKey : Option EffectKey)
    (locus : LocusId) (measure : MeasureId)
    (quantity : Quantity) :
    quantityAtEffects
      [SparseEffect.ofQuantity leftKey locus measure quantity]
      locus measure =
    quantityAtEffects
      [SparseEffect.ofQuantity rightKey locus measure quantity]
      locus measure := by
  rfl

end SparseEvent

end Loam.Tests.SparseEffectIdentityModel
