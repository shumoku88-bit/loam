import Init.Data.Order

namespace Loam.Core

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
  | dated (time : Time)
deriving Repr, DecidableEq

namespace RoutingEffective

variable {Time : Type}

/-- Initial routing precedes every dated routing coordinate. -/
def le [LE Time] : RoutingEffective Time → RoutingEffective Time → Prop
  | .initial, _ => True
  | .dated _, .initial => False
  | .dated left, .dated right => left ≤ right

instance [LE Time] : LE (RoutingEffective Time) where
  le := RoutingEffective.le

instance [LE Time] [decTime : DecidableRel (· ≤ · : Time → Time → Prop)] :
    DecidableRel (· ≤ · : RoutingEffective Time → RoutingEffective Time → Prop) :=
  fun left right =>
    match left, right with
    | .initial, _ => isTrue trivial
    | .dated _, .initial => isFalse id
    | .dated a, .dated b => decTime a b

/--
The routing-specific effective coordinates inherit a linear order from the
underlying dated coordinate, with `initial` as a distinct least element.
-/
instance [LE Time] [Std.IsLinearOrder Time] :
    Std.IsLinearOrder (RoutingEffective Time) where
  le_refl value := by
    cases value with
    | initial => trivial
    | dated time => exact Std.le_refl time
  le_trans left middle right hLeftMiddle hMiddleRight := by
    cases left with
    | initial => trivial
    | dated leftTime =>
        cases middle with
        | initial => exact False.elim hLeftMiddle
        | dated middleTime =>
            cases right with
            | initial => exact False.elim hMiddleRight
            | dated rightTime => exact Std.le_trans hLeftMiddle hMiddleRight
  le_antisymm left right hLeftRight hRightLeft := by
    cases left with
    | initial =>
        cases right with
        | initial => rfl
        | dated _ => exact False.elim hRightLeft
    | dated leftTime =>
        cases right with
        | initial => exact False.elim hLeftRight
        | dated rightTime =>
            have hTime : leftTime = rightTime := Std.le_antisymm hLeftRight hRightLeft
            cases hTime
            rfl
  le_total left right := by
    cases left with
    | initial => exact Or.inl trivial
    | dated leftTime =>
        cases right with
        | initial => exact Or.inr trivial
        | dated rightTime => exact Std.le_total

@[simp] theorem initial_le [LE Time] (value : RoutingEffective Time) :
    (RoutingEffective.initial : RoutingEffective Time) ≤ value := by
  trivial

@[simp] theorem dated_not_le_initial [LE Time] (time : Time) :
    ¬ ((RoutingEffective.dated time : RoutingEffective Time) ≤ .initial) := by
  intro h
  exact h

@[simp] theorem dated_le_dated [LE Time] (left right : Time) :
    ((RoutingEffective.dated left : RoutingEffective Time) ≤ .dated right) ↔ left ≤ right := by
  rfl

end RoutingEffective

end Loam.Core
