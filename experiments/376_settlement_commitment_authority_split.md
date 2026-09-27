# Observation 376 — settlement commitment authority split

Status: **BOUNDED RESULT — optional-successor evidence revision qualified; quantity-bearing extinguishment remains separate**

Baseline:

```text
#1434  Observation 373 — plain untyped cancel collapse falsified
#1435  Observation 374 — replacement-lineage identity qualified
#1438  Observation 375 — frontier-follow + current re-admission qualified
main   fce450d4f9697180d1c74f119f8733bd9cf197ec
```

## Trigger

The previous observations narrowed the unresolved commitment lifecycle to two
different semantic planes.

Evidence-side lifecycle:

```text
correction
retraction
```

Real-world lifecycle:

```text
physical/net settlement
non-settlement extinguishment
```

Observation 373 already showed that these planes cannot safely collapse into one
untyped terminal cancel operation.

Observation 374 then showed that correction continuity does not yet require a
separate logical commitment identity.

Observation 375 showed that historical dependent settlement evidence may follow
that correction lineage in current projection only when the resulting current
commitment passes full semantic re-admission.

The remaining representation question is now small:

> Can correction and explicit retraction share one family-specific revision
> authority, while non-settlement extinguishment remains a separate
> quantity-bearing real-world authority?

## Candidate representation under test

Evidence-side authority:

```text
SettlementCommitmentRevision
  target
  replacement : Option SettlementCommitmentId
```

Interpretation:

```text
replacement = some id
  evidence correction / positive replacement

replacement = none
  explicit retraction of the retained commitment evidence
```

Real-world reduction authority:

```text
SettlementCommitmentExtinguishment
  target
  exact quantity
```

Interpretation:

```text
the commitment was valid evidence
but this exact quantity later ceased to bind
without physical/net settlement
```

This observation deliberately does not introduce a legal reason taxonomy.

No `forgiven`, `waived`, `expired`, `novated`, or similar production kinds
are earned merely by this model.

## Why correction and retraction may share mechanics

Both operations answer the same evidence-authority question:

> Is this retained commitment row still current evidence, and if not, what
> retained row replaces it?

The optional successor records the distinction without another kind field:

```text
some successor = correction
no successor   = retraction
```

The positive replacement relation remains one-to-one and acyclic.

A lineage may therefore be:

```text
C1 -> C2 -> C3
```

or terminate explicitly:

```text
C1 -> C2 -> none
```

The model tests that the unified revision frontier has the same current-evidence
partition as deriving separate correction and retraction target sets.

## Why extinguishment is different

Extinguishment does not say the original commitment evidence was wrong.

For:

```text
commitment 10
later non-settlement extinguishment 3
```

the historical proposition remains:

```text
10 was a valid commitment
3 later ceased to bind
7 remains outstanding
```

That cannot be represented as evidence retraction without changing the historical
answer.

Representing it as correction:

```text
10 -> 7
```

can reproduce the current number but instead says the earlier 10 row was
superseded evidence.

Observation 373 already showed those histories are not semantically equivalent.

Observation 376 therefore tests quantity-bearing extinguishment directly beside
the unified evidence revision frontier.

## Witness 1 — correction in the unified revision family

```text
C1 quantity 10
C1 --revision--> C2 quantity 7
```

Expected:

```text
C1 is a correction target
C1 is not a retraction target
C1 resolves to C2
```

Expected Alloy result: **SAT**.

## Witness 2 — retraction in the same revision family

```text
C1 quantity 10
C1 --revision--> none
```

Expected:

```text
C1 is a retraction target
C1 is not a correction target
C1 has no current descendant
```

Expected Alloy result: **SAT**.

No separate retained `CommitmentRetraction` row family is needed in the
candidate model.

## Witness 3 — correction followed by retraction

```text
C1 quantity 10
  -> C2 quantity 7
  -> none
```

Expected:

```text
same family-specific revision authority
no current descendant
```

Expected Alloy result: **SAT**.

This is a useful pressure test because retraction applies to the current version,
not to a separate logical identity object.

## Witness 4 — partial extinguishment

```text
valid commitment 10
non-settlement extinguishment 3
outstanding 7
```

The commitment remains current evidence.

Expected Alloy result: **SAT**.

This immediately pressures extinguishment to retain an exact quantity rather than
a Boolean terminal marker.

## Witness 5 — full extinguishment

```text
valid commitment 10
non-settlement extinguishment 10
outstanding 0
```

The valid commitment remains in the evidence frontier even though its open
quantity is zero.

Expected Alloy result: **SAT**.

This is the sharpest contrast with retraction.

## Witness 6 — settlement and extinguishment coexist

```text
commitment 10
settled 2
extinguished 3
outstanding 5
```

Expected Alloy result: **SAT**.

The candidate conservation law is:

```text
committed
=
settled
+ non-settlement-extinguished
+ outstanding
```

Outstanding remains derived.

## Witness 7 — same zero open quantity, different authority

Two worlds retain the same commitment quantity 10.

World A:

```text
revision -> none
open = 0
no current commitment descendant
```

World B:

```text
extinguishment 10
open = 0
commitment remains valid current evidence
```

Expected Alloy result: **SAT**.

So current open quantity alone cannot tell retraction from full extinguishment.

## Assertions

### UnifiedRevisionMatchesDerivedSplitFrontier

The optional-successor revision family must yield the same current evidence set
as subtracting:

```text
positive correction targets
+
explicit retraction targets
```

Expected: **UNSAT counterexample**.

### RevisionKindRecoverable

For each retained revision row, correction versus retraction must be recoverable
from successor presence alone.

Expected: **UNSAT counterexample**.

### AdmittedOutstandingNeverNegative

After structural admission and reduction conservation, outstanding may never be
negative.

Expected: **UNSAT counterexample**.

### CurrentReductionPartition

For every current commitment:

```text
settled + extinguished + outstanding = committed
```

Expected: **UNSAT counterexample**.

### ZeroOpenMeansNoCurrentCommitment

Deliberately too strong.

Full extinguishment has zero open quantity while preserving valid commitment
evidence.

Expected: **SAT counterexample**.

### EveryExtinguishmentIsTerminal

Deliberately too strong.

Partial extinguishment should refute it.

Expected: **SAT counterexample**.

### RevisionAuthorityExplainsEveryNonSettlementReduction

Deliberately too strong.

With no physical settlement, a partial extinguishment reduces open quantity while
the commitment remains outside the evidence revision frontier.

Expected: **SAT counterexample**.

## Expected Alloy matrix

```text
correctionWitness                              SAT
retractionWitness                              SAT
correctionThenRetractionWitness                SAT
partialExtinguishmentWitness                   SAT
fullExtinguishmentWitness                      SAT
settlementPlusExtinguishmentWitness            SAT
sameZeroOpenDifferentAuthorityWitness          SAT

UnifiedRevisionMatchesDerivedSplitFrontier     UNSAT counterexample
RevisionKindRecoverable                        UNSAT counterexample
AdmittedOutstandingNeverNegative               UNSAT counterexample
CurrentReductionPartition                      UNSAT counterexample

ZeroOpenMeansNoCurrentCommitment               SAT counterexample
EveryExtinguishmentIsTerminal                  SAT counterexample
RevisionAuthorityExplainsEveryNonSettlementReduction SAT counterexample
```

## Alloy result

Qualified on Alloy 6.2.0 with SAT4J through the repository's shared research witness harness.

```text
correctionWitness                              SAT
retractionWitness                              SAT
correctionThenRetractionWitness                SAT
partialExtinguishmentWitness                   SAT
fullExtinguishmentWitness                      SAT
settlementPlusExtinguishmentWitness            SAT
sameZeroOpenDifferentAuthorityWitness          SAT

UnifiedRevisionMatchesDerivedSplitFrontier     UNSAT counterexample
RevisionKindRecoverable                        UNSAT counterexample
AdmittedOutstandingNeverNegative               UNSAT counterexample
CurrentReductionPartition                      UNSAT counterexample

ZeroOpenMeansNoCurrentCommitment               SAT counterexample
EveryExtinguishmentIsTerminal                  SAT counterexample
RevisionAuthorityExplainsEveryNonSettlementReduction SAT counterexample
```

The first run exposed one useful modeling boundary rather than a semantic failure:
`RevisionKindRecoverable` originally quantified malformed pre-admission worlds.
After restricting that assertion to structurally admitted revision evidence, the
expected matrix held.

The bounded result therefore supports both halves of the candidate split:

```text
correction + retraction
  may share one optional-successor evidence revision authority

non-settlement extinguishment
  cannot be reduced to that revision frontier
  and requires exact quantity
```

Full extinguishment is especially important: it can produce the same numeric
`open = 0` as retraction while preserving the opposite historical answer about
whether the original commitment was valid evidence.

## Finding

The smallest currently earned lifecycle split becomes:

```text
Evidence correction authority
  SettlementCommitmentRevision
    target
    replacement : Option SettlementCommitmentId

Real-world fulfillment authority
  existing direct/net settlement evidence

Real-world non-settlement reduction authority
  exact target + exact extinguished quantity
```

This would mean:

```text
correction and retraction share mechanics
but
retraction and extinguishment do not share semantics
```

That is smaller than introducing separate correction and retraction row families,
while still preserving the distinction that motivated Observation 373.

## What this does not decide

This observation does not yet choose production names or wire rows.

In particular it does not decide:

- whether `Extinguishment` is the eventual user-facing term;
- whether a full real-world successor obligation needs an explicit successor link;
- whether extinguishment carries a reason code;
- how historical/as-recorded queries display these transitions;
- whether extinguishment evidence may itself later need correction/retraction;
- whether extinguishment should be promoted in the same production PR as
  commitment revision.

Those should be earned independently.

## Stop condition

If the expected matrix holds:

1. use one optional-successor commitment revision authority for correction and
   explicit retraction;
2. keep non-settlement extinguishment semantically separate;
3. require exact extinguished quantity;
4. retain the conservation law
   `committed = settled + extinguished + outstanding`;
5. move next to the smallest production promotion sequence, not directly to TUI
   editing.
