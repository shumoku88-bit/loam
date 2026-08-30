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
One exact quantity effect at one locus.

`Effect` keeps the three practical coordinates observed so far separate:
where the change is observed (`LocusId`), what kind of quantity it is
(`MeasureId` inside `SomeAmount`), and how much changed (`Quantity`).

The sign has no built-in debit, credit, inflow, outflow, or accounting meaning.
-/
structure Effect where
  locus : LocusId
  amount : SomeAmount

namespace Effect

/-- Construct one runtime effect from its three explicit coordinates. -/
def ofQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) : Effect :=
  ⟨locus, SomeAmount.ofQuantity measure quantity⟩

/-- Recover the runtime measure coordinate without assigning valuation meaning. -/
def measure (effect : Effect) : MeasureId :=
  effect.amount.measure

/-- Recover the exact signed quantity. -/
def quantity (effect : Effect) : Quantity :=
  effect.amount.quantity

@[simp] theorem locus_ofQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity locus measure quantity).locus = locus :=
  rfl

@[simp] theorem measure_ofQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity locus measure quantity).measure = measure :=
  rfl

@[simp] theorem quantity_ofQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity locus measure quantity).quantity = quantity :=
  rfl

end Effect

end Loam.Core
