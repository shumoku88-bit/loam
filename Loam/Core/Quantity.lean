namespace Loam.Core

set_option autoImplicit false

/--
An exact signed quantity expressed in indivisible quanta.

`Quantity` deliberately wraps Lean's unbounded `Int` rather than a machine
integer or floating-point value. The sign has no built-in accounting or
physical meaning: later domain types may restrict quantities to nonnegative
holdings, attach a measure, or interpret a quantity as a change.

This module intentionally contains no division, ratio, rounding, commodity,
or monetary policy.
-/
structure Quantity where
  quanta : Int
deriving Repr, DecidableEq

namespace Quantity

/-- Construct an exact quantity from an integer number of quanta. -/
def ofQuanta (quanta : Int) : Quantity :=
  ⟨quanta⟩

/-- The quantity containing no quanta. -/
def zero : Quantity :=
  ofQuanta 0

/-- Exact addition of two quantities. -/
def add (left right : Quantity) : Quantity :=
  ofQuanta (left.quanta + right.quanta)

/-- Exact additive inverse. -/
def neg (quantity : Quantity) : Quantity :=
  ofQuanta (-quantity.quanta)

/-- Exact subtraction. -/
def sub (left right : Quantity) : Quantity :=
  ofQuanta (left.quanta - right.quanta)

instance : Zero Quantity := ⟨zero⟩
instance : Add Quantity := ⟨add⟩
instance : Neg Quantity := ⟨neg⟩
instance : Sub Quantity := ⟨sub⟩

@[simp] theorem quanta_ofQuanta (quanta : Int) :
    (ofQuanta quanta).quanta = quanta :=
  rfl

@[simp] theorem ofQuanta_quanta (quantity : Quantity) :
    ofQuanta quantity.quanta = quantity := by
  cases quantity
  rfl

@[simp] theorem quanta_zero :
    (0 : Quantity).quanta = 0 :=
  rfl

@[simp] theorem quanta_add (left right : Quantity) :
    (left + right).quanta = left.quanta + right.quanta :=
  rfl

@[simp] theorem quanta_neg (quantity : Quantity) :
    (-quantity).quanta = -quantity.quanta :=
  rfl

@[simp] theorem quanta_sub (left right : Quantity) :
    (left - right).quanta = left.quanta - right.quanta :=
  rfl

end Quantity
end Loam.Core
