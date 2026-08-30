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
remainder is retained exactly by giving one additional quantum to the first
`extra` parts.
-/

namespace Allocation

/-- Common whole-quanta part for an equal allocation. -/
def base (total recipients : Nat) : Nat :=
  total / recipients

/-- Number of recipients that receive one additional quantum. -/
def extra (total recipients : Nat) : Nat :=
  total % recipients

/--
Allocate nonnegative indivisible quanta across `recipients` parts.

A zero recipient count has no allocation and returns the empty list. For a
positive count, the first `total % recipients` parts receive `base + 1` and the
rest receive `base`.
-/
def parts (total recipients : Nat) : List Nat :=
  if recipients = 0 then
    []
  else
    List.replicate (extra total recipients) (base total recipients + 1) ++
      List.replicate (recipients - extra total recipients) (base total recipients)

private theorem sum_replicate (count value : Nat) :
    (List.replicate count value).sum = count * value := by
  induction count with
  | zero => simp
  | succ count ih =>
      simp [List.replicate, ih, Nat.succ_mul, Nat.add_comm]

/-- A positive recipient count produces exactly that many parts. -/
theorem length_parts
    (total recipients : Nat) (hPositive : 0 < recipients) :
    (parts total recipients).length = recipients := by
  have hNonzero : recipients ≠ 0 := Nat.ne_of_gt hPositive
  have hExtra : extra total recipients ≤ recipients :=
    Nat.le_of_lt (Nat.mod_lt total hPositive)
  simp only [parts, hNonzero, if_false, List.length_append, List.length_replicate]
  exact Nat.add_sub_of_le hExtra

/--
Exact allocation conserves the original number of quanta.

No rounding remainder disappears: the quotient supplies the common base and the
modulus is represented by the extra one-quantum parts.
-/
theorem sum_parts
    (total recipients : Nat) (hPositive : 0 < recipients) :
    (parts total recipients).sum = total := by
  have hNonzero : recipients ≠ 0 := Nat.ne_of_gt hPositive
  have hMod : total % recipients ≤ recipients :=
    Nat.le_of_lt (Nat.mod_lt total hPositive)
  simp only [parts, hNonzero, if_false, List.sum_append, sum_replicate]
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

/-- Concrete sanity check for an indivisible remainder. -/
example : parts 100 3 = [34, 33, 33] := by
  decide

end Allocation

end Loam.Core
