import Init.Data.Order

namespace Loam.Core

open Std (le_refl le_trans le_antisymm le_total)

set_option autoImplicit false

/-!
# Routing-specific effective coordinate

Observation 156 showed that historical routing can observe a distinction between
an assertion effective before every dated coordinate and an assertion effective
from the earliest ordinary date. Encoding the former as a fabricated date loses
that distinction.

`RoutingEffective` is deliberately routing-specific. It is not a general time
ontology and does not change the time carried by Actual validity or Scheduled
occurrences.
-/

/-- One historical-routing effective coordinate: initial, or effective from `Time`. -/
inductive RoutingEffective (Time : Type) where
  | initial
  | from (time : Time)
deriving Repr, DecidableEq

namespace RoutingEffective

/-- Initial routing precedes every dated routing coordinate. -/
def le [LE Time] : RoutingEffective Time → RoutingEffective Time → Prop
  | .initial, _ => True
  | .from _, .initial => False
  | .from left, .from right => left ≤ right

instance [LE Time] : LE (RoutingEffective Time) where
  le := RoutingEffective.le

instance [LE Time] [DecidableRel (· ≤ · : Time → Time → Prop)] :
    DecidableRel (· ≤ · : RoutingEffective Time → RoutingEffective Time → Prop) :=
  fun left right =>
    match left, right with
    | .initial, _ => isTrue trivial
    | .from _, .initial => isFalse id
    | .from a, .from b => inferInstance

/--
The routing-specific effective coordinates inherit a linear order from the
underlying dated coordinate, with `initial` as a distinct least element.
-/
instance [LE Time] [Std.IsLinearOrder Time] :
    Std.IsLinearOrder (RoutingEffective Time) where
  le_refl value := by
    cases value with
    | initial => trivial
    | from time => exact le_refl time
  le_trans left middle right hLeftMiddle hMiddleRight := by
    cases left with
    | initial => trivial
    | from leftTime =>
        cases middle with
        | initial => exact False.elim hLeftMiddle
        | from middleTime =>
            cases right with
            | initial => exact False.elim hMiddleRight
            | from rightTime => exact le_trans hLeftMiddle hMiddleRight
  le_antisymm left right hLeftRight hRightLeft := by
    cases left with
    | initial =>
        cases right with
        | initial => rfl
        | from _ => exact False.elim hRightLeft
    | from leftTime =>
        cases right with
        | initial => exact False.elim hLeftRight
        | from rightTime =>
            have hTime : leftTime = rightTime := le_antisymm hLeftRight hRightLeft
            cases hTime
            rfl
  le_total left right := by
    cases left with
    | initial => exact Or.inl trivial
    | from leftTime =>
        cases right with
        | initial => exact Or.inr trivial
        | from rightTime => exact le_total leftTime rightTime

@[simp] theorem initial_le [LE Time] (value : RoutingEffective Time) :
    (RoutingEffective.initial : RoutingEffective Time) ≤ value := by
  trivial

@[simp] theorem from_not_le_initial [LE Time] (time : Time) :
    ¬ ((RoutingEffective.from time : RoutingEffective Time) ≤ .initial) := by
  intro h
  exact h

@[simp] theorem from_le_from [LE Time] (left right : Time) :
    ((RoutingEffective.from left : RoutingEffective Time) ≤ .from right) ↔ left ≤ right := by
  rfl

end RoutingEffective

end Loam.Core
