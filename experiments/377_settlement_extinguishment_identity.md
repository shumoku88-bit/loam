# Observation 377 — settlement extinguishment row identity

Status: **BOUNDED RESULT — stable extinguishment row identity and evidence revision are required**

Baseline:

```text
#1439  Observation 376 — commitment revision vs extinguishment authority split qualified
#1440  commitment revision authority promoted to production
#1441  commitment revision publisher promoted
main   071d1f9cef6414a29aaaf035b7be295da0e40869
```

## Trigger

Observation 376 qualified a separate quantity-bearing authority for valid
commitment quantity that later ceases to bind without physical/net settlement.

It deliberately left one production-shape question open:

> Does an extinguishment row need stable identity and append-only evidence
> revision, or is `target + quantity` itself enough?

This must be answered before promotion because LOAM promises retained provenance
and correction rather than destructive mutation.

## Candidate minimal row

The model tests:

```text
ExtinguishmentId

Extinguishment
  id
  target commitment
  exact quantity

ExtinguishmentRevision
  target ExtinguishmentId
  replacement : Option ExtinguishmentId
```

Interpretation:

```text
replacement = some id
  correction of extinguishment evidence

replacement = none
  explicit retraction of erroneous extinguishment evidence
```

This evidence-side revision is distinct from commitment retraction.

The extinguishment row still means that the commitment itself was valid and some
exact quantity later ceased to bind.

## Why target + quantity may be too weak

Two independent real-world extinguishments can share the same semantic
coordinate:

```text
commitment 10

extinguishment A = 2
extinguishment B = 2
```

The correct total extinguished quantity is 4.

A set-like coordinate projection retaining only:

```text
(target, 2)
```

cannot distinguish one row from two rows.

The observation therefore treats multiplicity as potentially meaningful retained
evidence.

## Witness 1 — duplicate coordinate is meaningful

```text
same target
same quantity 2
two distinct extinguishment rows
current total = 4
```

Expected Alloy result: **SAT**.

No inference from equal payload merges the rows.

## Witness 2 — same coordinate view, different total

World A:

```text
one extinguishment row: 2
total = 2
```

World B:

```text
two independent extinguishment rows: 2 + 2
total = 4
```

Both have the same identity-free coordinate view:

```text
(target, 2)
```

Expected Alloy result: **SAT**.

Therefore `target + quantity` does not determine retained multiplicity or the
current total.

## Witness 3 — positive correction

```text
wrong extinguishment row = 4
corrected row             = 2

wrong-id -> corrected-id
```

Expected current total:

```text
2
```

Expected Alloy result: **SAT**.

## Witness 4 — evidence retraction

```text
wrong extinguishment row = 3
wrong-id -> none
```

Expected current total:

```text
0
```

Expected Alloy result: **SAT**.

This does not retract the commitment. It retracts only the erroneous claim that
some quantity was extinguished.

## Witness 5 — retract one of two equal rows

```text
A: target C, quantity 2
B: target C, quantity 2

retract A by stable row ID
```

Expected:

```text
B remains current
current total = 2
```

A coordinate-only operation saying:

```text
retract (C, 2)
```

cannot say whether A or B was intended and removes both under a set-like
interpretation.

Expected Alloy result: **SAT**.

This is the strongest pressure for stable row identity.

## Assertions

### CurrentRowsHaveUniqueIdentity

After structural admission, no two current rows share one row identity.

Expected: **UNSAT counterexample**.

### CoordinateViewDeterminesCurrentTotal

Deliberately too strong.

One versus two equal-coordinate rows have the same coordinate view but different
totals.

Expected: **SAT counterexample**.

### CoordinateRetractionMatchesIdentityRetraction

Deliberately too strong.

When equal-coordinate rows coexist, stable-ID retraction can remove exactly one
while coordinate-only retraction cannot.

Expected: **SAT counterexample**.

## Expected Alloy matrix

```text
duplicateCoordinateWitness                    SAT
sameCoordinateDifferentMultiplicityWitness    SAT
correctionWitness                             SAT
retractionWitness                             SAT
retractOneDuplicateCoordinateWitness          SAT

CurrentRowsHaveUniqueIdentity                 UNSAT counterexample
CoordinateViewDeterminesCurrentTotal          SAT counterexample
CoordinateRetractionMatchesIdentityRetraction SAT counterexample
```

## Alloy result

Qualified on Alloy 6.2.0 with SAT4J through the shared research witness harness.

```text
duplicateCoordinateWitness                    SAT
sameCoordinateDifferentMultiplicityWitness    SAT
correctionWitness                             SAT
retractionWitness                             SAT
retractOneDuplicateCoordinateWitness          SAT

CurrentRowsHaveUniqueIdentity                 UNSAT counterexample
CoordinateViewDeterminesCurrentTotal          SAT counterexample
CoordinateRetractionMatchesIdentityRetraction SAT counterexample
```

The bounded result shows two independent pressures for stable row identity:

1. multiplicity is semantically relevant, because one `(target, quantity)` row and
   two equal-coordinate rows can have the same identity-free coordinate view but
   different total extinguished quantity;
2. evidence correction/retraction must be able to address exactly one row even
   when another retained row has the same target and quantity.

So row identity is not merely implementation bookkeeping. It preserves
distinguishability that current quantity derivation and append-only repair both
need.

## Finding

Stable extinguishment row identity is earned.

The smallest currently supported production candidate becomes:

```text
SettlementExtinguishmentId

SettlementCommitmentExtinguishment
  id
  target SettlementCommitmentId
  quantity Quantity

SettlementExtinguishmentRevision
  target SettlementExtinguishmentId
  replacement : Option SettlementExtinguishmentId
```

Current extinguishment total is derived only from the revision frontier.

This mirrors correspondence/member correction mechanics without collapsing
their semantic families.

## What this does not decide

Observation 377 does not earn:

- a legal/business reason taxonomy;
- timestamps beyond whatever provenance a later requirement may demand;
- an explicit successor-commitment link for novation/modification;
- user-facing wording;
- whether extinguishment should immediately be writable from TUI.

Those remain separate pressure questions.

## Stop condition

If the expected matrix holds:

1. require stable row identity for extinguishment evidence;
2. give extinguishment its own optional-successor evidence revision authority;
3. derive current extinguished quantity from the current row frontier;
4. keep commitment revision, settlement fulfillment, and extinguishment as
   separate semantic authorities;
5. only then promote extinguishment to production.
