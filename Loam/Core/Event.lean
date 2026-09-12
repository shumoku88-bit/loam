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

@[simp] theorem coordinate_ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofAnonymousQuantity locus measure quantity).coordinate = ⟨locus, measure⟩ :=
  rfl

end Effect

/-- Retained stable Effect keys, excluding ordinary anonymous Effects. -/
@[simp] def retainedEffectKeys (effects : List Effect) : List EffectKey :=
  effects.filterMap Effect.key

@[simp] theorem retainedEffectKeys_singleton_nodup (effect : Effect) :
    (retainedEffectKeys [effect]).Nodup := by
  cases h : effect.key <;> simp [retainedEffectKeys, h]

@[simp] theorem filterMap_singleton_nodup {α β : Type _} (f : α → Option β) (x : α) :
    (List.filterMap f [x]).Nodup := by
  cases h : f x <;> simp [List.filterMap, h]

/--
One event identity together with the effects observed for that event.

Effect identity is preserved only when independently referenced. Distinct
ordinary Effects may therefore remain anonymous, including multiple Effects at
the same locus/measure coordinate. Every retained `EffectKey` occurs at most
once within the event.

The list is only the current practical representation; its order carries no
built-in temporal, causal, priority, debit/credit, or posting-order meaning.

An event is not required here to contain an effect. Earlier observations also
left room for purpose-only or revision-only events, whose practical fields have
not yet been introduced.
-/
structure Event where
  id : EventId
  effects : List Effect
  keyNodup : (retainedEffectKeys effects).Nodup

namespace Event

/--
Admit a runtime effect collection only when no retained stable EffectKey is
repeated within the event. Anonymous Effects do not consume identity slots.
Locus/measure coordinates remain projections, not effect identity.
-/
def ofEffects? (id : EventId) (effects : List Effect) : Option Event :=
  if h : (retainedEffectKeys effects).Nodup then
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

private theorem quantityFold_perm
    {left right : List Effect}
    (hPerm : left.Perm right)
    (locus : LocusId) (measure : MeasureId) :
    left.foldr
        (fun effect total =>
          if effect.coordinate = ⟨locus, measure⟩ then
            effect.quantity.quanta + total
          else
            total)
        0 =
      right.foldr
        (fun effect total =>
          if effect.coordinate = ⟨locus, measure⟩ then
            effect.quantity.quanta + total
          else
            total)
        0 := by
  induction hPerm with
  | nil => rfl
  | cons effect h ih =>
      simp only [List.foldr_cons]
      rw [ih]
  | swap x y rest =>
      simp only [List.foldr_cons]
      by_cases hx : x.coordinate = ⟨locus, measure⟩
      <;> by_cases hy : y.coordinate = ⟨locus, measure⟩
      <;> simp [hx, hy, Int.add_comm, Int.add_left_comm]
  | trans hLeft hRight ihLeft ihRight =>
      exact ihLeft.trans ihRight

/--
The quantity projection is invariant under permutation of the represented
Effects. List position therefore cannot change the observed quantity at a
locus/measure coordinate.
-/
theorem quantityAt_perm
    (left right : Event)
    (hPerm : left.effects.Perm right.effects)
    (locus : LocusId) (measure : MeasureId) :
    quantityAt left locus measure = quantityAt right locus measure := by
  simpa [quantityAt] using
    congrArg Quantity.ofQuanta (quantityFold_perm hPerm locus measure)

/-- An empty effect relation is not rejected at this layer. -/
@[simp] theorem ofEffects?_nil (id : EventId) :
    ofEffects? id [] = some { id := id, effects := [], keyNodup := by simp [retainedEffectKeys] } := by
  simp [ofEffects?, retainedEffectKeys]

/-- One effect is always admissible, whether anonymous or explicitly keyed. -/
@[simp] theorem ofEffects?_singleton (id : EventId) (effect : Effect) :
    (ofEffects? id [effect]).isSome = true := by
  cases h : effect.key <;> simp [ofEffects?, retainedEffectKeys, h]

/-- Reusing one retained effect key is rejected even when coordinates differ. -/
@[simp] theorem ofEffects?_duplicateKey
    (id : EventId) (key : EffectKey)
    (leftLocus rightLocus : LocusId)
    (leftMeasure rightMeasure : MeasureId)
    (left right : Quantity) :
    ofEffects? id
      [Effect.ofQuantity key leftLocus leftMeasure left,
       Effect.ofQuantity key rightLocus rightMeasure right] = none := by
  simp [ofEffects?, retainedEffectKeys]

/-- Distinct retained effect keys may coexist at the same locus/measure coordinate. -/
theorem ofEffects?_sameCoordinate_distinctKeys_isSome
    (id : EventId) (leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [Effect.ofQuantity leftKey locus measure left,
       Effect.ofQuantity rightKey locus measure right]).isSome = true := by
  simp [ofEffects?, retainedEffectKeys, hDifferent]

/-- Multiple anonymous Effects may coexist at the same coordinate. -/
theorem ofEffects?_sameCoordinate_anonymous_isSome
    (id : EventId) (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (ofEffects? id
      [Effect.ofAnonymousQuantity locus measure left,
       Effect.ofAnonymousQuantity locus measure right]).isSome = true := by
  simp [ofEffects?, retainedEffectKeys, Effect.ofAnonymousQuantity]

/-- A coordinate with no effects projects to exact zero. -/
@[simp] theorem quantityAt_empty
    (id : EventId) (locus : LocusId) (measure : MeasureId) :
    quantityAt { id := id, effects := [], keyNodup := by simp [retainedEffectKeys] } locus measure = 0 := by
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
        keyNodup := by simp [retainedEffectKeys, hDifferent] }
      locus measure = Quantity.ofQuanta (left.quanta + right.quanta) := by
  simp [quantityAt]

/-- Anonymous effects participate in physical quantity exactly like keyed Effects. -/
theorem quantityAt_sameCoordinate_anonymous_two
    (id : EventId) (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    quantityAt
      { id := id,
        effects :=
          [Effect.ofAnonymousQuantity locus measure left,
           Effect.ofAnonymousQuantity locus measure right],
        keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }
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
        keyNodup := by simp [retainedEffectKeys] }
      queryLocus measure = 0 := by
  simp [quantityAt, Effect.coordinate, hDifferent]
  rfl

end Event

end Loam.Core
