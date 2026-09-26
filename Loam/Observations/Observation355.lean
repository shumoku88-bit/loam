namespace Loam.Observation355

set_option autoImplicit false

/-!
# Observation 355 — the minimal retained apportionment fact is query-relative

Observation 354 established two history pressures:

- stable identity can remove accidental list-order tie breaking;
- current membership plus unchanged current policy does not reconstruct an older
  allocation after the recipient set changes.

That leaves one more architectural question:

> If an apportionment answer becomes historical meaning, what is the smallest
> retained representation that is actually sufficient?

Three candidate representations are compared here:

1. a tiny remainder certificate such as "A won the tie";
2. the full resulting assignment;
3. the historical weighted input boundary plus one immutable policy definition.

The result is intentionally query-relative rather than selecting one universal
canonical representation.

Selected fixed policy:

- weighted exact apportionment;
- floor every exact quota;
- if one quantum remains, give it to the largest exact fractional remainder;
- break equal remainders with stable recipient priority A < B < C < D.

Three historical worlds are used.

World 1:
    total 6
    weights A1 B2 C3 D6
    denominator 12
    winner A
    assignment [A1, B1, C1, D3]

World 2:
    total 6
    weights A1 B1 C4 D6
    denominator 12
    winner A
    assignment [A1, B0, C2, D3]

World 3:
    total 6
    weights A1 B2 C2 D5
    denominator 10
    winner A
    assignment [A1, B1, C1, D3]

Worlds 1 and 2 have the same compact winner certificate but different final
assignments.

Worlds 1 and 3 have the same final assignment but different historical weights.

So:

    winner certificate
        is too small even for "what was allocated?"

while:

    full assignment
        answers "what was allocated?"
        but does not answer "what historical weighted input produced it?"

and:

    historical weighted inputs + immutable policy
        reconstruct the allocation
        and preserve the explanation boundary.

This is context-relative sufficiency in a concrete investment/apportionment
setting.
-/

inductive RecipientId where
  | a
  | b
  | c
  | d
deriving Repr, DecidableEq

structure WeightedRecipient where
  id : RecipientId
  weight : Nat
deriving Repr, DecidableEq

structure World where
  total : Nat
  recipients : List WeightedRecipient
deriving Repr, DecidableEq

private def priority : RecipientId -> Nat
  | .a => 0
  | .b => 1
  | .c => 2
  | .d => 3

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
    (world : World) : Nat :=
  let denominator := weightTotal world.recipients
  world.recipients.foldl
    (fun acc row => acc + quotaFloor world.total denominator row)
    0

private def missingQuanta
    (world : World) : Nat :=
  world.total - floorSum world

/--
This selected pressure only needs one remainder quantum.

The result is none when there is no recipient.
-/
private def stableWinner? (world : World) : Option RecipientId :=
  match world.recipients with
  | [] => none
  | first :: rest =>
      let denominator := weightTotal world.recipients
      let winner :=
        rest.foldl
          (fun current candidate =>
            let currentRemainder :=
              quotaRemainder world.total denominator current
            let candidateRemainder :=
              quotaRemainder world.total denominator candidate
            if candidateRemainder > currentRemainder then
              candidate
            else if candidateRemainder < currentRemainder then
              current
            else if priority candidate.id < priority current.id then
              candidate
            else
              current)
          first
      some winner.id

private def getsExtra
    (winner : Option RecipientId)
    (id : RecipientId) : Nat :=
  if winner = some id then 1 else 0

private def allocation
    (world : World) : List (RecipientId × Nat) :=
  let denominator := weightTotal world.recipients
  let winner :=
    if missingQuanta world = 1 then
      stableWinner? world
    else
      none
  world.recipients.map fun row =>
    (row.id,
      quotaFloor world.total denominator row +
        getsExtra winner row.id)

private def world1 : World := {
  total := 6
  recipients := [
    ⟨.a, 1⟩,
    ⟨.b, 2⟩,
    ⟨.c, 3⟩,
    ⟨.d, 6⟩
  ]
}

private def world2 : World := {
  total := 6
  recipients := [
    ⟨.a, 1⟩,
    ⟨.b, 1⟩,
    ⟨.c, 4⟩,
    ⟨.d, 6⟩
  ]
}

private def world3 : World := {
  total := 6
  recipients := [
    ⟨.a, 1⟩,
    ⟨.b, 2⟩,
    ⟨.c, 2⟩,
    ⟨.d, 5⟩
  ]
}

theorem selected_worlds_have_expected_assignments :
    allocation world1 =
      [(.a, 1), (.b, 1), (.c, 1), (.d, 3)] ∧
    allocation world2 =
      [(.a, 1), (.b, 0), (.c, 2), (.d, 3)] ∧
    allocation world3 =
      [(.a, 1), (.b, 1), (.c, 1), (.d, 3)] := by
  native_decide

structure WinnerCertificate where
  total : Nat
  denominator : Nat
  recipientIds : List RecipientId
  winner : Option RecipientId
deriving Repr, DecidableEq

private def winnerCertificate
    (world : World) : WinnerCertificate := {
  total := world.total
  denominator := weightTotal world.recipients
  recipientIds := world.recipients.map (·.id)
  winner := stableWinner? world
}

/--
Worlds 1 and 2 collapse to the same small certificate even though their final
allocations differ.

So retaining only the winner, total, denominator, recipient identities, and
fixed policy is insufficient to reconstruct "what was allocated?"
-/
theorem winner_certificate_is_not_output_sufficient :
    winnerCertificate world1 = winnerCertificate world2 ∧
    allocation world1 ≠ allocation world2 := by
  native_decide

/--
The full historical assignment is sufficient for the narrow query
"what was allocated?" by construction.
-/
private def retainedAssignment
    (world : World) : List (RecipientId × Nat) :=
  allocation world

theorem retained_assignment_answers_allocation_query :
    retainedAssignment world1 =
      [(.a, 1), (.b, 1), (.c, 1), (.d, 3)] := by
  native_decide

/--
But Worlds 1 and 3 have the same final allocation while their historical weighted
input differs.

Therefore the result alone cannot answer a future question about historical
weights or explain which exact quotas were used.
-/
theorem full_assignment_is_not_input_provenance_sufficient :
    retainedAssignment world1 = retainedAssignment world3 ∧
    world1.recipients ≠ world3.recipients := by
  native_decide

structure HistoricalInputSnapshot where
  total : Nat
  recipients : List WeightedRecipient
deriving Repr, DecidableEq

private def snapshot (world : World) : HistoricalInputSnapshot := {
  total := world.total
  recipients := world.recipients
}

private def worldOfSnapshot
    (history : HistoricalInputSnapshot) : World := {
  total := history.total
  recipients := history.recipients
}

/--
With the selected immutable policy definition fixed by this Observation,
historical weighted inputs are sufficient to reconstruct the historical
assignment exactly.
-/
theorem historical_input_snapshot_plus_immutable_policy_reconstructs :
    allocation (worldOfSnapshot (snapshot world1)) =
      allocation world1 ∧
    allocation (worldOfSnapshot (snapshot world2)) =
      allocation world2 ∧
    allocation (worldOfSnapshot (snapshot world3)) =
      allocation world3 := by
  native_decide

/--
The same snapshot also directly retains the historical weights which the full
assignment alone forgot.
-/
private def weightOf?
    (id : RecipientId)
    (history : HistoricalInputSnapshot) : Option Nat := do
  let row ← history.recipients.find? fun row => row.id = id
  pure row.weight

theorem input_snapshot_preserves_explanatory_weight_query :
    weightOf? .c (snapshot world1) = some 3 ∧
    weightOf? .c (snapshot world3) = some 2 := by
  native_decide

/--
A "floor rows + winner" certificate can reconstruct the final assignment, but it
is no smaller in the important information-theoretic sense: it still retains
one integer amount per recipient and still forgets the original exact weights.

This candidate is useful to distinguish reconstruction from explanation.
-/
structure FloorWinnerCertificate where
  floors : List (RecipientId × Nat)
  winner : Option RecipientId
deriving Repr, DecidableEq

private def floorRows
    (world : World) : List (RecipientId × Nat) :=
  let denominator := weightTotal world.recipients
  world.recipients.map fun row =>
    (row.id, quotaFloor world.total denominator row)

private def floorWinnerCertificate
    (world : World) : FloorWinnerCertificate := {
  floors := floorRows world
  winner := if missingQuanta world = 1 then stableWinner? world else none
}

private def allocationFromFloorWinner
    (certificate : FloorWinnerCertificate) :
    List (RecipientId × Nat) :=
  certificate.floors.map fun row =>
    (row.1, row.2 + getsExtra certificate.winner row.1)

theorem floor_plus_winner_reconstructs_selected_output :
    allocationFromFloorWinner (floorWinnerCertificate world1) =
      allocation world1 ∧
    allocationFromFloorWinner (floorWinnerCertificate world2) =
      allocation world2 := by
  native_decide

/--
Even this stronger certificate does not preserve the historical weighted input.

Worlds can share an assignment while differing in the exact proportional
question that produced it.
-/
theorem reconstructed_output_does_not_imply_historical_explanation :
    allocation world1 = allocation world3 ∧
    snapshot world1 ≠ snapshot world3 := by
  native_decide

/-!
## Finding

There is no context-free single "minimal historical apportionment fact."

The smallest sufficient representation depends on the future query vocabulary.

### Query: what was allocated?

A retained full assignment is sufficient.

A winner-only certificate is not sufficient. Worlds 1 and 2 have:

    same total
    same denominator
    same recipient identities
    same winner
    same immutable policy

but different historical weights and different allocations.

So the winner certificate destroys output information.

### Query: why was that allocation produced?

A full assignment alone is not sufficient.

Worlds 1 and 3 have the same final assignment but different historical weights.

So the assignment destroys explanatory input provenance.

For the selected fixed policy, retaining:

    historical total
    historical recipient identities
    historical weights

is sufficient to reconstruct both the allocation and the weighted-input answer.

If policy definitions can change, Observations 070–071 already show that
historical policy provenance/definition becomes independently relevant.

### Can a smaller certificate replace the input snapshot?

Only relative to retained context.

A floor-plus-winner certificate reconstructs the output, but it carries one
integer per recipient and still cannot explain the original exact weights.

A hash or content address could bind an external snapshot, but without the
snapshot itself it would verify identity, not reconstruct its contents.

Therefore certificate sufficiency depends on which source evidence already
survives elsewhere.

This is a concrete reappearance of LOAM's context-relative sufficiency law:

    retained representation
        is sufficient only relative to
    selected future questions
        and
    other retained context

## Current candidate boundary

Do not promote one universal AllocationHistory record yet.

Instead distinguish possible promises:

    projection-only answer
        -> no retained allocation may be needed

    historical "what was allocated?"
        -> retained assignment or information-equivalent source state

    historical "why was it allocated that way?"
        -> historical input provenance
           + historical policy semantics if policy can change

    audit verification against an externally retained source
        -> a smaller certificate/hash may be sufficient

The minimal representation is therefore a product promise, not a property of
the arithmetic alone.

Still not earned:

- production AllocationHistory;
- production HistoricalInputSnapshot;
- policy version persistence;
- a winner certificate wire format;
- a cryptographic content-address scheme;
- retention of every computed allocation;
- one universal future query vocabulary;
- resurrection of Allocation into neutral Core.

The next useful pressure is practical rather than mathematical:

> Which of these historical promises does investment basis actually need?

If investment reports only need deterministic recomputation from already
retained acquisition/disposal evidence, then no separate AllocationHistory may
be needed at all.

If tax filing, audit, or correction workflows need to preserve the historically
booked integer basis answer even after inputs or policy are corrected, then a
retained assignment/correction frontier may become independently observable.

That distinction should be tested before persistence is added.
-/

end Loam.Observation355
