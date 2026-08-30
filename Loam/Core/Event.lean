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

/-- The coordinate at which one event effect is observed. -/
structure EffectCoordinate where
  locus : LocusId
  measure : MeasureId
deriving Repr, DecidableEq

namespace Effect

/-- Project an effect onto its independent locus and measure coordinates. -/
def coordinate (effect : Effect) : EffectCoordinate :=
  ⟨effect.locus, effect.measure⟩

@[simp] theorem coordinate_ofQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity locus measure quantity).coordinate = ⟨locus, measure⟩ :=
  rfl

end Effect

/--
One event identity together with the effects observed for that event.

Within one event, each `(LocusId, MeasureId)` coordinate occurs at most once,
matching the earlier `Event -> Locus -> Measure -> lone Quantity` observation.
The list is only the current practical representation; its order carries no
built-in temporal, causal, priority, debit/credit, or posting-order meaning.

An event is not required here to contain an effect. Earlier observations also
left room for purpose-only or revision-only events, whose practical fields have
not yet been introduced.
-/
structure Event where
  id : EventId
  effects : List Effect
  coordinateNodup : (effects.map Effect.coordinate).Nodup

namespace Event

/--
Admit a runtime effect collection only when no locus/measure coordinate is
repeated within the event.
-/
def ofEffects? (id : EventId) (effects : List Effect) : Option Event :=
  if h : (effects.map Effect.coordinate).Nodup then
    some { id := id, effects := effects, coordinateNodup := h }
  else
    none

/-- An empty effect relation is not rejected at this layer. -/
@[simp] theorem ofEffects?_nil (id : EventId) :
    ofEffects? id [] = some { id := id, effects := [], coordinateNodup := by simp } := by
  simp [ofEffects?]

/-- One effect always has a unique coordinate within its event. -/
@[simp] theorem ofEffects?_singleton (id : EventId) (effect : Effect) :
    ofEffects? id [effect] =
      some { id := id, effects := [effect], coordinateNodup := by simp } := by
  simp [ofEffects?]

/-- Two effects at the same locus/measure coordinate cannot coexist separately. -/
@[simp] theorem ofEffects?_duplicateCoordinate
    (id : EventId) (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    ofEffects? id
      [Effect.ofQuantity locus measure left,
       Effect.ofQuantity locus measure right] = none := by
  simp [ofEffects?, Effect.coordinate]

end Event

end Loam.Core
