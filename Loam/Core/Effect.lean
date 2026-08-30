import Loam.Core.Measure

namespace Loam.Core

set_option autoImplicit false

/--
Stable identity for where a quantity effect is observed.

The token is an opaque identity for equality and later persistence. It is not a
display name and carries no built-in account, ownership, custody, or accounting
role semantics.
-/
structure LocusId where
  token : String
deriving Repr, DecidableEq

/--
Stable key for one observed effect within an event.

The key exists so later overlays can refer back to one effect without using
list position or its locus/measure projection as identity. It carries no
built-in purpose, ordering, settlement, or accounting meaning.
-/
structure EffectKey where
  token : String
deriving Repr, DecidableEq

/--
One exact quantity effect at one locus.

`Effect` keeps stable effect identity separate from the three practical
coordinates observed so far: where the change is observed (`LocusId`), what
kind of quantity it is (`MeasureId` inside `SomeAmount`), and how much changed
(`Quantity`).

The sign has no built-in debit, credit, inflow, outflow, or accounting meaning.
-/
structure Effect where
  key : EffectKey
  locus : LocusId
  amount : SomeAmount

namespace Effect

/-- Construct one runtime effect from its stable key and three explicit coordinates. -/
def ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) : Effect :=
  ⟨key, locus, SomeAmount.ofQuantity measure quantity⟩

/-- Recover the runtime measure coordinate without assigning valuation meaning. -/
def measure (effect : Effect) : MeasureId :=
  effect.amount.measure

/-- Recover the exact signed quantity. -/
def quantity (effect : Effect) : Quantity :=
  effect.amount.quantity

@[simp] theorem key_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).key = key :=
  rfl

@[simp] theorem locus_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).locus = locus :=
  rfl

@[simp] theorem measure_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).measure = measure :=
  rfl

@[simp] theorem quantity_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).quantity = quantity :=
  rfl

end Effect

end Loam.Core
