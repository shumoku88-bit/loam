import Loam.Core.Quantity

namespace Loam.Core

set_option autoImplicit false

/--
Stable identity for a kind of quantity.

The token is intended for equality and later persistence. It is not a display
name and carries no built-in currency, commodity, valuation, or dimensional
semantics.
-/
structure MeasureId where
  token : String
deriving Repr, DecidableEq

/--
An exact quantity whose measure is carried at the type level.

Two `Amount` values can use the same typed arithmetic only when Lean knows that
they have the same `MeasureId` index.
-/
structure Amount (measure : MeasureId) where
  quantity : Quantity
deriving Repr, DecidableEq

namespace Amount

/-- Lift an exact quantity into one already-known measure. -/
def ofQuantity {measure : MeasureId} (quantity : Quantity) : Amount measure :=
  ⟨quantity⟩

/-- Exact addition inside one measure index. -/
def add {measure : MeasureId}
    (left right : Amount measure) : Amount measure :=
  ofQuantity (left.quantity + right.quantity)

instance {measure : MeasureId} : Add (Amount measure) :=
  ⟨add⟩

@[simp] theorem quantity_ofQuantity
    {measure : MeasureId} (quantity : Quantity) :
    (ofQuantity (measure := measure) quantity).quantity = quantity :=
  rfl

@[simp] theorem quantity_add
    {measure : MeasureId} (left right : Amount measure) :
    (left + right).quantity = left.quantity + right.quantity :=
  rfl

end Amount

/--
A quantity arriving from a runtime boundary, where its measure is data rather
than a statically known index.

This is the existential boundary used by parsers, persistence, and other
external inputs before measure equality has been checked.
-/
abbrev SomeAmount := Sigma Amount

namespace SomeAmount

/-- Package a runtime measure identity with an exact quantity. -/
def ofQuantity (measure : MeasureId) (quantity : Quantity) : SomeAmount :=
  ⟨measure, Amount.ofQuantity quantity⟩

/-- Recover the runtime measure identity. -/
def measure (amount : SomeAmount) : MeasureId :=
  amount.1

/-- Recover the exact quantity without assigning any cross-measure meaning. -/
def quantity (amount : SomeAmount) : Quantity :=
  amount.2.quantity

/--
Add two runtime amounts only after their measure identities are shown equal.

The equality proof transports the right value into the left value's typed
`Amount` world. A mismatch has no typed addition path and returns `none`.
-/
def add? (left right : SomeAmount) : Option SomeAmount :=
  match left, right with
  | ⟨leftMeasure, leftAmount⟩, ⟨rightMeasure, rightAmount⟩ =>
      if h : leftMeasure = rightMeasure then
        let alignedRight : Amount leftMeasure := h.symm ▸ rightAmount
        some ⟨leftMeasure, leftAmount + alignedRight⟩
      else
        none

@[simp] theorem measure_ofQuantity
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity measure quantity).measure = measure :=
  rfl

@[simp] theorem quantity_ofQuantity
    (measure : MeasureId) (quantity : Quantity) :
    (ofQuantity measure quantity).quantity = quantity :=
  rfl

/-- Runtime values with the same measure enter ordinary typed addition. -/
@[simp] theorem add?_sameMeasure
    (measure : MeasureId) (left right : Amount measure) :
    add? ⟨measure, left⟩ ⟨measure, right⟩ =
      some ⟨measure, left + right⟩ := by
  simp [add?]

/-- Distinct runtime measure identities cannot enter typed addition. -/
@[simp] theorem add?_differentMeasure
    {leftMeasure rightMeasure : MeasureId}
    (hDifferent : leftMeasure ≠ rightMeasure)
    (left : Amount leftMeasure) (right : Amount rightMeasure) :
    add? ⟨leftMeasure, left⟩ ⟨rightMeasure, right⟩ = none := by
  simp [add?, hDifferent]

end SomeAmount

end Loam.Core
