namespace Loam.Observation354

set_option autoImplicit false

/-!
# Observation 354 — stable tie-break identity is reorder-safe but not historical membership

Observation 352 showed that weighted exact apportionment still needs a policy
for indivisible remainder quanta.

The next pressure is historical stability.

Two separate changes must not be conflated:

1. representation reorder:
       the same recipients and weights arrive in another list order;

2. semantic membership change:
       a new recipient is added to the current apportionment set.

A list-order tie-break is sensitive to the first.
A stable recipient identity can remove that sensitivity.

But stable identity alone cannot reconstruct an older allocation after the
recipient set itself changes.

Selected initial pressure:

    exact total = 6

    A weight 1
    B weight 2
    C weight 3
    D weight 6

    denominator = 12

Exact quota remainders:

    A:  6 / 12
    B:  0 / 12
    C:  6 / 12
    D:  0 / 12

The floor allocation is:

    A 0
    B 1
    C 1
    D 3

and one indivisible quantum remains.

A and C tie for the largest fractional remainder.

If list position breaks the tie:

    [A,B,C,D] -> A receives the extra quantum
    [C,B,A,D] -> C receives the extra quantum

The same semantic recipient set therefore receives a different allocation
merely because representation order changed.

A stable identity priority can instead choose A in both representations.

Then add one new current recipient:

    E weight 6

The same stable policy now sees denominator 18 and selects a different current
allocation. That is a legitimate current answer, but it is not the old
historical answer.

The observation asks what information is minimally needed to preserve that
distinction.
-/

inductive RecipientId where
  | a
  | b
  | c
  | d
  | e
deriving Repr, DecidableEq

structure WeightedRecipient where
  id : RecipientId
  weight : Nat
deriving Repr, DecidableEq

private def a : WeightedRecipient := ⟨.a, 1⟩
private def b : WeightedRecipient := ⟨.b, 2⟩
private def c : WeightedRecipient := ⟨.c, 3⟩
private def d : WeightedRecipient := ⟨.d, 6⟩
private def e : WeightedRecipient := ⟨.e, 6⟩

private def total : Nat := 6

private def originalOrder : List WeightedRecipient :=
  [a, b, c, d]

private def reordered : List WeightedRecipient :=
  [c, b, a, d]

private def currentAfterInsertion : List WeightedRecipient :=
  [a, b, c, d, e]

private def weightTotal (rows : List WeightedRecipient) : Nat :=
  rows.foldl (fun acc row => acc + row.weight) 0

private def quotaFloor
    (total denominator : Nat)
    (row : WeightedRecipient) : Nat :=
  if denominator = 0 then
    0
  else
    (total * row.weight) / denominator

private def quotaRemainder
    (total denominator : Nat)
    (row : WeightedRecipient) : Nat :=
  if denominator = 0 then
    0
  else
    (total * row.weight) % denominator

private def floorSum
    (total : Nat)
    (rows : List WeightedRecipient) : Nat :=
  let denominator := weightTotal rows
  rows.foldl
    (fun acc row => acc + quotaFloor total denominator row)
    0

private def missingQuanta
    (total : Nat)
    (rows : List WeightedRecipient) : Nat :=
  total - floorSum total rows

/--
First-max selection is intentionally representation-sensitive.

On equal remainder it keeps the earlier row.
-/
private def firstMaxRemainder?
    (total : Nat)
    (rows : List WeightedRecipient) : Option RecipientId :=
  match rows with
  | [] => none
  | first :: rest =>
      let denominator := weightTotal rows
      let winner :=
        rest.foldl
          (fun current candidate =>
            if quotaRemainder total denominator candidate >
                quotaRemainder total denominator current then
              candidate
            else
              current)
          first
      some winner.id

private def stablePriority : RecipientId -> Nat
  | .a => 0
  | .b => 1
  | .c => 2
  | .d => 3
  | .e => 4

/--
Stable priority is consulted only after exact fractional remainders tie.
-/
private def stableMaxRemainder?
    (total : Nat)
    (rows : List WeightedRecipient) : Option RecipientId :=
  match rows with
  | [] => none
  | first :: rest =>
      let denominator := weightTotal rows
      let winner :=
        rest.foldl
          (fun current candidate =>
            let currentRemainder :=
              quotaRemainder total denominator current
            let candidateRemainder :=
              quotaRemainder total denominator candidate
            if candidateRemainder > currentRemainder then
              candidate
            else if candidateRemainder < currentRemainder then
              current
            else if stablePriority candidate.id <
                stablePriority current.id then
              candidate
            else
              current)
          first
      some winner.id

private def getsExtra
    (winner : Option RecipientId)
    (id : RecipientId) : Nat :=
  if winner = some id then 1 else 0

private def allocateWithWinner
    (total : Nat)
    (rows : List WeightedRecipient)
    (winner : Option RecipientId) :
    List (RecipientId × Nat) :=
  let denominator := weightTotal rows
  rows.map fun row =>
    (row.id,
      quotaFloor total denominator row +
        getsExtra winner row.id)

private def listOrderAllocation
    (rows : List WeightedRecipient) :
    List (RecipientId × Nat) :=
  allocateWithWinner total rows (firstMaxRemainder? total rows)

private def stableAllocation
    (rows : List WeightedRecipient) :
    List (RecipientId × Nat) :=
  allocateWithWinner total rows (stableMaxRemainder? total rows)

private def assignedTo?
    (id : RecipientId)
    (allocation : List (RecipientId × Nat)) : Option Nat := do
  let row ← allocation.find? fun row => row.1 = id
  pure row.2

private def sumAssigned
    (allocation : List (RecipientId × Nat)) : Nat :=
  allocation.foldl (fun acc row => acc + row.2) 0

theorem selected_initial_case_has_one_tied_remainder_quantum :
    weightTotal originalOrder = 12 ∧
    missingQuanta total originalOrder = 1 ∧
    quotaRemainder total 12 a = 6 ∧
    quotaRemainder total 12 c = 6 ∧
    quotaRemainder total 12 b = 0 ∧
    quotaRemainder total 12 d = 0 := by
  native_decide

/--
List order alone changes which tied recipient receives the extra quantum.
-/
theorem representation_order_changes_first_tie_break :
    firstMaxRemainder? total originalOrder = some .a ∧
    firstMaxRemainder? total reordered = some .c ∧
    assignedTo? .a (listOrderAllocation originalOrder) = some 1 ∧
    assignedTo? .a (listOrderAllocation reordered) = some 0 ∧
    assignedTo? .c (listOrderAllocation originalOrder) = some 1 ∧
    assignedTo? .c (listOrderAllocation reordered) = some 2 := by
  native_decide

/--
Both representation-sensitive answers conserve the exact total.

Conservation therefore does not detect the historical instability.
-/
theorem representation_sensitive_allocations_still_conserve :
    sumAssigned (listOrderAllocation originalOrder) = total ∧
    sumAssigned (listOrderAllocation reordered) = total := by
  native_decide

/--
Stable identity priority removes the accidental representation-order
dependency for the same semantic recipient set.
-/
theorem stable_identity_tie_break_is_reorder_invariant_for_same_set :
    stableMaxRemainder? total originalOrder = some .a ∧
    stableMaxRemainder? total reordered = some .a ∧
    assignedTo? .a (stableAllocation originalOrder) = some 1 ∧
    assignedTo? .a (stableAllocation reordered) = some 1 ∧
    assignedTo? .c (stableAllocation originalOrder) = some 1 ∧
    assignedTo? .c (stableAllocation reordered) = some 1 := by
  native_decide

/--
Adding E is a semantic membership change, not a representation reorder.

The same stable tie-break policy now sees a different denominator and a
different largest remainder.
-/
theorem later_membership_change_changes_current_stable_allocation :
    weightTotal currentAfterInsertion = 18 ∧
    missingQuanta total currentAfterInsertion = 1 ∧
    stableMaxRemainder? total currentAfterInsertion = some .b ∧
    stableAllocation currentAfterInsertion =
      [(.a, 0), (.b, 1), (.c, 1), (.d, 2), (.e, 2)] := by
  native_decide

private def retainedHistoricalAllocation :
    List (RecipientId × Nat) :=
  stableAllocation originalOrder

private def recomputedFromCurrentMembership :
    List (RecipientId × Nat) :=
  stableAllocation currentAfterInsertion

/--
The current recipient set plus the unchanged stable policy does not reproduce
the old historical assignment.

In particular, A's old remainder quantum disappears from the recomputed current
view.
-/
theorem current_membership_is_not_a_historical_reconstruction_source :
    retainedHistoricalAllocation =
      [(.a, 1), (.b, 1), (.c, 1), (.d, 3)] ∧
    recomputedFromCurrentMembership =
      [(.a, 0), (.b, 1), (.c, 1), (.d, 2), (.e, 2)] ∧
    assignedTo? .a retainedHistoricalAllocation = some 1 ∧
    assignedTo? .a recomputedFromCurrentMembership = some 0 := by
  native_decide

/--
Reusing the *historical* recipient set and the same stable policy is sufficient
to reconstruct the selected old answer.

So the observation does not force allocation persistence specifically. It
forces preservation of information equivalent to the historical input boundary
whenever later reconstruction is required.
-/
theorem historical_membership_plus_stable_policy_reconstructs_selected_history :
    stableAllocation originalOrder = retainedHistoricalAllocation := by
  rfl

/-!
## Finding

Weighted exact apportionment exposes two different stability problems.

### 1. Representation reorder

If equal fractional remainders are broken by list position:

    same recipients
    same weights
    same total
    different list order
        ->
    different historical assignment

Exact conservation does not catch the problem.

A stable recipient identity plus a stable tie-break rule can eliminate this
representation-order dependency for an unchanged semantic recipient set.

So:

    recipient identity
        !=
    representation position

and tie-breaking should not silently treat the latter as the former when
historical assignment matters.

### 2. Membership change

Stable identity does not freeze the result forever.

When E is later added:

    old membership + same policy
        -> old allocation

    current membership + same policy
        -> different current allocation

This is legitimate. The denominator and exact quotas genuinely changed.

But it means:

    current membership
        +
    current policy

does not reconstruct an older historical allocation.

This is parallel to, but distinct from, Observations 069–071:

- those observations changed current policy or policy definition;
- Observation 354 keeps the policy behavior stable and changes the semantic
  recipient set.

If an application promises a historical per-recipient allocation answer, some
information equivalent to the historical allocation boundary must survive.

Possible representations include:

- the retained allocation itself;
- the historical recipient/weight snapshot plus immutable policy definition;
- another information-equivalent provenance encoding.

Observation 354 does not choose among them.

## Consequence for the resurrected allocation question

The old equal Allocation kernel had explicit front/back placement but recipient
identity lived in a separate module.

The stronger weighted candidate now reveals a sharper boundary:

    exact proportional arithmetic
        !=
    stable recipient identity
        !=
    tie-break policy
        !=
    historical recipient-set provenance

So a future production apportionment kernel should not make list order the
accidental durable tie-break merely because list order is convenient to compute.

Still not earned:

- resurrection of Allocation or RecipientAssignment;
- a production RecipientId type;
- a universal lexical/numeric identity ordering;
- a universal largest-remainder method;
- retained historical allocation for every projection;
- membership versioning;
- policy versioning;
- correction/reversal semantics for retained allocation;
- fairness, rotation, randomness, or priority authority.

The next question is no longer purely arithmetic.

It is an evidence-boundary question:

> when an apportionment answer becomes historical meaning, is the minimal
> retained fact the resulting assignment, the input snapshot, or a smaller
> provenance certificate sufficient to reproduce it?

That should be pressured before any numeric kernel is promoted back into Core.
-/

end Loam.Observation354
