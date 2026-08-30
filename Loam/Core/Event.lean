import Loam.Core.Effect

namespace Loam.Core

set_option autoImplicit false

/--
Stable identity for one observed event.

The token is an opaque identity for equality and later persistence. It does not
encode time, event kind, purpose, settlement state, or any accounting role.
-/
structure EventId where
  token : String
deriving Repr, DecidableEq

/-- The projection coordinate at which one event effect is observed. -/
structure EffectCoordinate where
  locus : LocusId
  measure : MeasureId
deriving Repr, DecidableEq

namespace Effect

/-- Project an effect onto its independent locus and measure coordinates. -/
def coordinate (effect : Effect) : EffectCoordinate :=
  ⟨effect.locus, effect.measure⟩

@[simp] theorem coordinate_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).coordinate = ⟨locus, measure⟩ :=
  rfl

end Effect

/--
One event identity together with the effects observed for that event.

Effect identity is preserved independently of the `(LocusId, MeasureId)`
projection. Distinct effects may therefore share the same locus and measure,
while each `EffectKey` occurs at most once within the event.

The list is only the current practical representation; its order carries no
built-in temporal, causal, priority, debit/credit, or posting-order meaning.

An event is not required here to contain an effect. Earlier observations also
left room for purpose-only or revision-only events, whose practical fields have
not yet been introduced.
-/
structure Event where
  id : EventId
  effects : List Effect
  keyNodup : (effects.map Effect.key).Nodup

namespace Event

/--
Admit a runtime effect collection only when no effect key is repeated within
the event. Locus/measure coordinates are projections, not effect identity.
-/
def ofEffects? (id : EventId) (effects : List Effect) : Option Event :=
  if h : (effects.map Effect.key).Nodup then
    some { id := id, effects := effects, keyNodup := h }
  else
    none

/--
Project an event onto one locus/measure coordinate and sum every matching exact
quantity. Effect identity and the original effect list remain intact; this is a
read-only aggregate projection. A coordinate with no matching effect projects
to exact zero.
-/
def quantityAt (event : Event) (locus : LocusId) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    event.effects.foldr
      (fun effect total =>
        if effect.coordinate = ⟨locus, measure⟩ then
          effect.quantity.quanta + total
        else
          total)
      0

/-- An empty effect relation is not rejected at this layer. -/
@[simp] theorem ofEffects?_nil (id : EventId) :
    ofEffects? id [] = some { id := id, effects := [], keyNodup := by simp } := by
  simp [ofEffects?]

/-- One effect always has a unique key within its event. -/
@[simp] theorem ofEffects?_singleton (id : EventId) (effect : Effect) :
    ofEffects? id [effect] =
      some { id := id, effects := [effect], keyNodup := by simp } := by
  simp [ofEffects?]

/-- Reusing one effect key is rejected even when the projected coordinates differ. -/
@[simp] theorem ofEffects?_duplicateKey
    (id : EventId) (key : EffectKey)
    (leftLocus rightLocus : LocusId)
    (leftMeasure rightMeasure : MeasureId)
    (left right : Quantity) :
    ofEffects? id
      [Effect.ofQuantity key leftLocus leftMeasure left,
       Effect.ofQuantity key rightLocus rightMeasure right] = none := by
  simp [ofEffects?]

/-- Distinct effect keys may coexist at the same locus/measure coordinate. -/
theorem ofEffects?_sameCoordinate_distinctKeys_isSome
    (id : EventId) (leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [Effect.ofQuantity leftKey locus measure left,
       Effect.ofQuantity rightKey locus measure right]).isSome = true := by
  simp [ofEffects?, hDifferent]

/-- A coordinate with no effects projects to exact zero. -/
@[simp] theorem quantityAt_empty
    (id : EventId) (locus : LocusId) (measure : MeasureId) :
    quantityAt { id := id, effects := [], keyNodup := by simp } locus measure = 0 := by
  rfl

/-- Distinct effects at one coordinate contribute additively to its projection. -/
theorem quantityAt_sameCoordinate_two
    (id : EventId) (leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    quantityAt
      { id := id,
        effects :=
          [Effect.ofQuantity leftKey locus measure left,
           Effect.ofQuantity rightKey locus measure right],
        keyNodup := by simp [hDifferent] }
      locus measure = Quantity.ofQuanta (left.quanta + right.quanta) := by
  simp [quantityAt]

/-- An effect at another locus does not contribute to the queried coordinate. -/
theorem quantityAt_otherLocus_zero
    (id : EventId) (key : EffectKey)
    (effectLocus queryLocus : LocusId)
    (hDifferent : effectLocus ≠ queryLocus)
    (measure : MeasureId) (quantity : Quantity) :
    quantityAt
      { id := id,
        effects := [Effect.ofQuantity key effectLocus measure quantity],
        keyNodup := by simp }
      queryLocus measure = 0 := by
  simp [quantityAt, Effect.coordinate, hDifferent]
  rfl

end Event

end Loam.Core
