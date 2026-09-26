import Init.Data.List.Nat.Basic
import Init.Data.Nat.Div.Lemmas

namespace Loam.Observation351

set_option autoImplicit false

/-!
# Observation 351 — exact conservation is itself a policy, not a universal rounding law

Observation 350 separated:

    exact ratio
        !=
    rounding mode
        !=
    quantization stage

It ended by identifying remainder allocation as the next pressure whenever
several quantized outputs must sum back to one exact finite total.

Current Japanese individual-stock tax guidance adds an important correction to
that sentence.

The NTA's selected same-issue stock example computes a per-unit acquisition
amount, rounds a fractional yen upward, and then multiplies by the disposed
quantity. The later remaining position is likewise carried using that rounded
per-unit amount:

- https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1466.htm

That means exact conservation of the pre-quantized purchase total is not itself
a universal tax/accounting law.

This observation therefore separates a fourth dimension:

    exact ratio
        !=
    quantization policy
        !=
    exact-total conservation requirement

Selected arithmetic:

    exact pool basis = 1000 JPY
    exact quantity   = 3 units
    exact unit ratio = 1000 / 3

If each one-unit fragment independently uses ceil:

    [334, 334, 334]
    sum = 1002

If each independently uses floor:

    [333, 333, 333]
    sum = 999

If the selected consumer instead requires exact conservation of the 1000 JPY
finite total, some fragments must receive the indivisible remainder quanta:

    [334, 333, 333]
    [333, 334, 333]
    [333, 333, 334]

All three conserve 1000, but they attach different historical basis amounts to
individual fragments.

That is the reappearance of the exact-allocation mathematics once explored in
the now-retired `Loam/Core/Allocation.lean`.

The old kernel was correctly retired when it had no production consumer.
Observation 351 does not restore it. It asks whether investment arithmetic now
supplies real semantic pressure for the same conservation theorem.
-/

private def totalBasis : Nat := 1000
private def fragmentCount : Nat := 3

private def floorUnit (total count : Nat) : Nat :=
  total / count

private def ceilUnit (total count : Nat) : Nat :=
  let q := total / count
  let r := total % count
  if r = 0 then q else q + 1

private def independentlyRoundedParts
    (unit : Nat) (count : Nat) : List Nat :=
  List.replicate count unit

theorem independent_per_unit_ceil_does_not_conserve_selected_exact_total :
    (independentlyRoundedParts
      (ceilUnit totalBasis fragmentCount) fragmentCount).sum = 1002 ∧
    1002 ≠ totalBasis := by
  native_decide

theorem independent_per_unit_floor_does_not_conserve_selected_exact_total :
    (independentlyRoundedParts
      (floorUnit totalBasis fragmentCount) fragmentCount).sum = 999 ∧
    999 ≠ totalBasis := by
  native_decide

inductive RemainderPlacement where
  | front
  | back
deriving Repr, DecidableEq

private def base (total recipients : Nat) : Nat :=
  total / recipients

private def extra (total recipients : Nat) : Nat :=
  total % recipients

private def highParts (total recipients : Nat) : List Nat :=
  List.replicate (extra total recipients) (base total recipients + 1)

private def baseParts (total recipients : Nat) : List Nat :=
  List.replicate (recipients - extra total recipients) (base total recipients)

private def exactParts
    (placement : RemainderPlacement)
    (total recipients : Nat) : List Nat :=
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

private theorem sum_exactParts
    (placement : RemainderPlacement)
    (total recipients : Nat) (hPositive : 0 < recipients) :
    (exactParts placement total recipients).sum = total := by
  have hNonzero : recipients ≠ 0 := Nat.ne_of_gt hPositive
  cases placement with
  | front =>
      simp only [exactParts, hNonzero, if_false, highParts, baseParts,
        List.sum_append, sum_replicate]
      exact exact_count_sum total recipients hPositive
  | back =>
      simp only [exactParts, hNonzero, if_false, highParts, baseParts,
        List.sum_append, sum_replicate]
      rw [Nat.add_comm]
      exact exact_count_sum total recipients hPositive

/--
If a selected semantic consumer *does* require exact conservation, the old
allocation law reappears naturally.

No remainder quantum disappears.
-/
theorem exact_remainder_allocation_conserves_selected_total :
    exactParts .front totalBasis fragmentCount = [334, 333, 333] ∧
    exactParts .back totalBasis fragmentCount = [333, 333, 334] ∧
    (exactParts .front totalBasis fragmentCount).sum = totalBasis ∧
    (exactParts .back totalBasis fragmentCount).sum = totalBasis := by
  constructor
  · native_decide
  constructor
  · native_decide
  constructor
  · exact sum_exactParts .front totalBasis fragmentCount (by decide)
  · exact sum_exactParts .back totalBasis fragmentCount (by decide)

structure DisposalId where
  token : String
deriving Repr, DecidableEq

private def saleA : DisposalId := ⟨"sale-a"⟩
private def saleB : DisposalId := ⟨"sale-b"⟩
private def saleC : DisposalId := ⟨"sale-c"⟩

private def disposalOrder : List DisposalId :=
  [saleA, saleB, saleC]

private def assignedBasis
    (placement : RemainderPlacement) :
    List (DisposalId × Nat) :=
  disposalOrder.zip (exactParts placement totalBasis disposalOrder.length)

/--
Conservation does not determine *which* historical disposal receives the extra
quantum.

Recipient identity / order and placement policy are independently observable
when per-disposal answers matter.
-/
theorem same_conserved_total_different_historical_assignment :
    assignedBasis .front =
      [(saleA, 334), (saleB, 333), (saleC, 333)] ∧
    assignedBasis .back =
      [(saleA, 333), (saleB, 333), (saleC, 334)] ∧
    assignedBasis .front ≠ assignedBasis .back := by
  native_decide

private def proceeds : List Nat :=
  [500, 450, 350]

private def gains
    (placement : RemainderPlacement) : List Int :=
  let basis := exactParts placement totalBasis disposalOrder.length
  (proceeds.zip basis).map fun row =>
    Int.ofNat row.1 - Int.ofNat row.2

private def sumInts (rows : List Int) : Int :=
  rows.foldl (fun total row => total + row) 0

/--
Remainder placement changes the per-disposal realised-gain history while
preserving aggregate gain when the basis allocation itself conserves the exact
total.

This is why remainder placement is policy, not mere implementation detail.
-/
theorem placement_changes_per_disposal_gain_but_not_aggregate_gain :
    gains .front = [166, 117, 17] ∧
    gains .back = [167, 117, 16] ∧
    gains .front ≠ gains .back ∧
    sumInts (gains .front) = 300 ∧
    sumInts (gains .back) = 300 := by
  native_decide

inductive BasisSemantics where
  | independentPerUnitCeil
  | exactConserving (placement : RemainderPlacement)
deriving Repr, DecidableEq

private def projectedBasis
    (semantics : BasisSemantics) : List Nat :=
  match semantics with
  | .independentPerUnitCeil =>
      independentlyRoundedParts
        (ceilUnit totalBasis fragmentCount) fragmentCount
  | .exactConserving placement =>
      exactParts placement totalBasis fragmentCount

/--
The same exact pool supports both a non-conserving per-unit-ceiling projection
and exact-conserving remainder allocation.

Therefore conservation cannot be inferred merely from the exact ratio.
-/
theorem exact_pool_does_not_determine_conservation_semantics :
    projectedBasis .independentPerUnitCeil = [334, 334, 334] ∧
    projectedBasis (.exactConserving .front) = [334, 333, 333] ∧
    (projectedBasis .independentPerUnitCeil).sum = 1002 ∧
    (projectedBasis (.exactConserving .front)).sum = 1000 := by
  native_decide

/-!
## Finding

Observation 350's "next pressure" needs one qualification:

    exact total conservation

is not a universal consequence of exact arithmetic.

Current Japanese individual-stock guidance demonstrates a legitimate selected
semantics where a per-unit acquisition value is rounded upward before
multiplication. In such a semantics, the rounded tax-basis projection can depart
from the pre-quantized exact purchase total.

So the architecture must distinguish:

    retained exact acquisition evidence
        !=
    exact derived ratio
        !=
    quantization rule
        !=
    conservation requirement
        !=
    remainder-placement policy

Only when a selected consumer requires exact conservation does remainder
allocation become mandatory.

At that point the previously retired exact-allocation mathematics reappears:

    total = base * count + remainder

and the indivisible remainder can be assigned without loss.

But even exact conservation does not determine recipient assignment.
Front/back placement produces different per-disposal gain histories while
preserving the same aggregate basis and aggregate gain.

That yields two important boundaries:

1. Do not impose exact conservation on jurisdictional/report semantics which do
   not require it.
2. When exact conservation *is* required, make remainder placement explicit
   rather than letting list order silently decide historical meaning.

This is the first new practical pressure since the old Allocation kernel was
retired which reproduces its conservation theorem.

It still does not automatically earn resurrection into Core.

Before promotion, Architecture Law 9 still asks for repeated independent
production consumers with the same semantic operation. Investment arithmetic is
now one serious consumer candidate, not sufficient evidence by itself.

Not earned here:

- production Allocation resurrection;
- universal conservation of tax basis;
- universal front/back placement;
- fairness or rotation semantics;
- weighted allocation for unequal quantities;
- temporal allocation when future recipients are not yet known;
- correction/reversal semantics for retained allocation;
- tax correctness beyond the selected documented rounding shape.

The next pressure, if needed, is weighted apportionment:

    exact total basis
        +
    unequal fragment quantities
        ->
    exact integer allocations whose sum is conserved

That would test whether the old equal-allocation kernel is genuinely sufficient
or whether investment work demands a more general weighted theorem.
-/

end Loam.Observation351
