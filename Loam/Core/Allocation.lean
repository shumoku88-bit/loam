import Init.Data.List.Nat.Basic
import Init.Data.Nat.Div.Lemmas

namespace Loam.Core

set_option autoImplicit false

/-!
# Exact allocation

This module starts with nonnegative indivisible quanta. General `Quantity` is
signed, but allocation does not yet assign a meaning to distributing a negative
quantity.

For a positive recipient count, division gives a common base part and the
remainder is retained exactly. Where those extra one-quantum parts appear is an
explicit placement choice rather than an implicit property of allocation.
-/

namespace Allocation

/--
Where indivisible remainder quanta are placed relative to the caller's existing
recipient order.

This does not determine recipient identity or priority. It only makes the
previously implicit list-order choice explicit.
-/
inductive RemainderPlacement where
  | front
  | back
deriving Repr, DecidableEq

/-- Common whole-quanta part for an equal allocation. -/
def base (total recipients : Nat) : Nat :=
  total / recipients

/-- Number of recipients that receive one additional quantum. -/
def extra (total recipients : Nat) : Nat :=
  total % recipients

private def highParts (total recipients : Nat) : List Nat :=
  List.replicate (extra total recipients) (base total recipients + 1)

private def baseParts (total recipients : Nat) : List Nat :=
  List.replicate (recipients - extra total recipients) (base total recipients)

/--
Allocate nonnegative indivisible quanta across `recipients` parts.

A zero recipient count has no allocation and returns the empty list. For a
positive count, `total % recipients` parts receive `base + 1` and the remaining
parts receive `base`. `placement` says whether those remainder-bearing parts are
at the front or back of the caller's recipient order.
-/
def parts (placement : RemainderPlacement) (total recipients : Nat) : List Nat :=
  if recipients = 0 then
    []
  else
    match placement with
    | .front => highParts total recipients ++ baseParts total recipients
    | .back => baseParts total recipients ++ highParts total recipients

private theorem sum_replicate (count value : Nat) :
    (List.replicate count value).sum = count * value := by
  induction count with
  | zero => simp
  | succ count ih =>
      simp [List.replicate, ih, Nat.succ_mul, Nat.add_comm]

private theorem exact_count_sum
    (total recipients : Nat) (hPositive : 0 < recipients) :
    extra total recipients * (base total recipients + 1) +
        (recipients - extra total recipients) * base total recipients = total := by
  have hMod : total % recipients ≤ recipients :=
    Nat.le_of_lt (Nat.mod_lt total hPositive)
  unfold base extra
  calc
    (total % recipients) * (total / recipients + 1) +
        (recipients - total % recipients) * (total / recipients) =
        ((total % recipients) * (total / recipients) + total % recipients) +
          (recipients - total % recipients) * (total / recipients) := by
            rw [Nat.mul_add, Nat.mul_one]
    _ = ((total % recipients) * (total / recipients) +
          (recipients - total % recipients) * (total / recipients)) +
          total % recipients := by
            ac_rfl
    _ = ((total % recipients) + (recipients - total % recipients)) *
          (total / recipients) + total % recipients := by
            rw [Nat.add_mul]
    _ = recipients * (total / recipients) + total % recipients := by
            rw [Nat.add_sub_of_le hMod]
    _ = total := Nat.div_add_mod total recipients

/-- A positive recipient count produces exactly that many parts. -/
theorem length_parts
    (placement : RemainderPlacement)
    (total recipients : Nat) (hPositive : 0 < recipients) :
    (parts placement total recipients).length = recipients := by
  have hNonzero : recipients ≠ 0 := Nat.ne_of_gt hPositive
  have hExtra : extra total recipients ≤ recipients :=
    Nat.le_of_lt (Nat.mod_lt total hPositive)
  cases placement with
  | front =>
      simp only [parts, hNonzero, if_false, highParts, baseParts,
        List.length_append, List.length_replicate]
      exact Nat.add_sub_of_le hExtra
  | back =>
      simp only [parts, hNonzero, if_false, highParts, baseParts,
        List.length_append, List.length_replicate]
      exact Nat.sub_add_cancel hExtra

/--
Exact allocation conserves the original number of quanta for either placement.

No rounding remainder disappears, and choosing where the remainder-bearing
parts appear cannot change the conserved total.
-/
theorem sum_parts
    (placement : RemainderPlacement)
    (total recipients : Nat) (hPositive : 0 < recipients) :
    (parts placement total recipients).sum = total := by
  have hNonzero : recipients ≠ 0 := Nat.ne_of_gt hPositive
  cases placement with
  | front =>
      simp only [parts, hNonzero, if_false, highParts, baseParts,
        List.sum_append, sum_replicate]
      exact exact_count_sum total recipients hPositive
  | back =>
      simp only [parts, hNonzero, if_false, highParts, baseParts,
        List.sum_append, sum_replicate]
      rw [Nat.add_comm]
      exact exact_count_sum total recipients hPositive

/-- Concrete sanity checks make the placement choice visible at the call site. -/
example : parts .front 100 3 = [34, 33, 33] := by
  decide

example : parts .back 100 3 = [33, 33, 34] := by
  decide

end Allocation

end Loam.Core
