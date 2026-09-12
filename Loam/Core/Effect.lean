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

Stable Effect identity is optional: `none` is an ordinary physical Effect that
is not independently referenced, while `some key` is a retained identity for
later evidence such as a Relation source. Locus, Measure, and Quantity remain
independent of whether durable identity was earned.

The sign has no built-in debit, credit, inflow, outflow, or accounting meaning.
-/
structure Effect where
  key : Option EffectKey
  locus : LocusId
  amount : SomeAmount

namespace Effect

/-- Construct one explicitly identified runtime effect. Existing keyed callers retain this API. -/
def ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) : Effect :=
  ⟨some key, locus, SomeAmount.ofQuantity measure quantity⟩

/-- Construct one ordinary runtime effect without allocating durable identity. -/
def ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) : Effect :=
  ⟨none, locus, SomeAmount.ofQuantity measure quantity⟩

/-- Promote one ordinary effect to an explicitly retained stable key. -/
def identify (effect : Effect) (key : EffectKey) : Effect :=
  { effect with key := some key }

/-- Recover the runtime measure coordinate without assigning valuation meaning. -/
def measure (effect : Effect) : MeasureId :=
  effect.amount.measure

/-- Recover the exact signed quantity. -/
def quantity (effect : Effect) : Quantity :=
  effect.amount.quantity

@[simp] theorem key_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).key = some key :=
  rfl

@[simp] theorem key_ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofAnonymousQuantity locus measure quantity).key = none :=
  rfl

@[simp] theorem locus_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).locus = locus :=
  rfl

@[simp] theorem locus_ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofAnonymousQuantity locus measure quantity).locus = locus :=
  rfl

@[simp] theorem measure_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).measure = measure :=
  rfl

@[simp] theorem measure_ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofAnonymousQuantity locus measure quantity).measure = measure :=
  rfl

@[simp] theorem quantity_ofQuantity
    (key : EffectKey) (locus : LocusId)
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity key locus measure quantity).quantity = quantity :=
  rfl

@[simp] theorem quantity_ofAnonymousQuantity
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    (ofAnonymousQuantity locus measure quantity).quantity = quantity :=
  rfl

@[simp] theorem coordinateIdentity_identify
    (effect : Effect) (key : EffectKey) :
    (identify effect key).locus = effect.locus :=
  rfl

@[simp] theorem measure_identify
    (effect : Effect) (key : EffectKey) :
    (identify effect key).measure = effect.measure :=
  rfl

@[simp] theorem quantity_identify
    (effect : Effect) (key : EffectKey) :
    (identify effect key).quantity = effect.quantity :=
  rfl

end Effect

end Loam.Core
