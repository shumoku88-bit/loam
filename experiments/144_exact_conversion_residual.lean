import Init.Data.Nat.Div.Lemmas

namespace Observation144

set_option autoImplicit false

/-!
Observation 144 keeps conversion arithmetic neutral.

`numerator / denominator` is only an experiment-local exact relation between
indivisible source and target quanta. `whole` is the whole target-quanta answer
obtained by natural-number division; `residual` retains the otherwise-discarded
scaled remainder.
-/

/-- Whole target quanta visible after integer conversion. -/
def whole (source numerator denominator : Nat) : Nat :=
  (source * numerator) / denominator

/-- Exact scaled remainder not represented by `whole`. -/
def residual (source numerator denominator : Nat) : Nat :=
  (source * numerator) % denominator

/--
The whole target quantity plus its retained residual reconstructs the exact
scaled source quantity. No rounding residue disappears.
-/
theorem exact_conversion
    (source numerator denominator : Nat) :
    denominator * whole source numerator denominator +
        residual source numerator denominator =
      source * numerator := by
  exact Nat.div_add_mod (source * numerator) denominator

/-- For a positive denominator, one conversion residual is strictly bounded. -/
theorem residual_lt_denominator
    (source numerator denominator : Nat)
    (hPositive : 0 < denominator) :
    residual source numerator denominator < denominator := by
  exact Nat.mod_lt (source * numerator) hPositive

/--
Splitting a source quantity cannot change the exact scaled result when both
whole target quanta and residuals are retained.

The visible whole target quantities alone need not compose. The theorem keeps
all remainder information, so the split and aggregate paths are equal before
any later normalization or placement choice.
-/
theorem split_preserves_exact_scaled_quantity
    (left right numerator denominator : Nat) :
    denominator *
          (whole left numerator denominator + whole right numerator denominator) +
        (residual left numerator denominator + residual right numerator denominator) =
      denominator * whole (left + right) numerator denominator +
        residual (left + right) numerator denominator := by
  have hLeft := exact_conversion left numerator denominator
  have hRight := exact_conversion right numerator denominator
  have hCombined := exact_conversion (left + right) numerator denominator
  calc
    denominator *
          (whole left numerator denominator + whole right numerator denominator) +
        (residual left numerator denominator + residual right numerator denominator) =
        (denominator * whole left numerator denominator +
          residual left numerator denominator) +
        (denominator * whole right numerator denominator +
          residual right numerator denominator) := by
            rw [Nat.mul_add]
            ac_rfl
    _ = left * numerator + right * numerator := by
          rw [hLeft, hRight]
    _ = (left + right) * numerator := by
          rw [Nat.add_mul]
    _ = denominator * whole (left + right) numerator denominator +
          residual (left + right) numerator denominator := by
            symm
            exact hCombined

/-!
Concrete pressure specimen.

A relation of `1 / 3` applied to three source quanta yields one whole target
quantum when converted in aggregate. Splitting the same source quantity into
`1 + 2` and truncating each piece yields zero visible whole target quanta.

The missing whole quantum is not mysterious once residuals are retained:
`1 + 2 = 3` scaled residual units, which exactly equal one denominator and can
therefore carry into a later normalization step.
-/

example : whole 3 1 3 = 1 := by
  decide

example : whole 1 1 3 + whole 2 1 3 = 0 := by
  decide

example :
    whole 3 1 3 ≠ whole 1 1 3 + whole 2 1 3 := by
  decide

example : residual 3 1 3 = 0 := by
  decide

example : residual 1 1 3 + residual 2 1 3 = 3 := by
  decide

example :
    3 * (whole 1 1 3 + whole 2 1 3) +
        (residual 1 1 3 + residual 2 1 3) =
      3 * whole 3 1 3 + residual 3 1 3 := by
  decide

end Observation144
