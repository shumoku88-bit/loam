# Observation 373 — settlement commitment lifecycle distinguishability

Status: **BOUNDED RESULT — plain untyped cancel collapse falsified; no production representation selected**

Baseline:

```text
#1425–#1432  retained SettlementEvidence -> Actual v2 -> atomic publisher
             -> shared SettlementReview -> read-only TUI
main         d5990cad2570fa0d301be2491fb40882582292c6
```

## Trigger

The first production settlement family deliberately promoted
`SettlementCommitment` without a commitment-revision vocabulary.

Observation 371 said this explicitly:

> stable commitment identity was earned, but correction semantics for a
> mis-recorded commitment itself had not yet been separately qualified.

That stop condition is now operationally relevant because the explicit writer
exists and a future ordinary TUI/AI input flow will make commitment mistakes
possible.

The tempting repair is small:

```text
cancel commitment
```

or perhaps:

```text
cancel old commitment
-> optional successor commitment
```

Before introducing such a terminal operation, this observation asks whether it
would collapse meanings that LOAM already keeps separate elsewhere.

## Prior earned distinctions

Observation 175 established for OpenRelation:

```text
retraction != known-none
```

Observation 178 then made a second distinction explicit:

```text
retraction != discharge
```

A retraction says retained positive evidence was wrong or is no longer current
authority.

A discharge says a semantically valid relation was fulfilled by a later actual
occurrence.

Settlement commitments now expose the analogous unresolved boundary.

## Root question

> Can commitment correction, retraction, and real-world extinguishment collapse
> to one untyped terminal cancel operation?

This is not yet asking how many production structures should exist.

One physical representation could still carry several explicitly tagged
meanings. The observation only tests whether the meanings themselves may be
collapsed.

## Model vocabulary

The bounded Alloy model retains four deliberately separate axes:

```text
Commitment
  exact positive quantity

CommitmentRevision
  target
  optional replacement

Extinguishment
  target
  exact quantity
  optional successor

SettlementUse
  target
  exact quantity
```

Interpretation:

```text
revision + replacement
  evidence correction

revision + no replacement
  explicit retraction of erroneous commitment evidence

extinguishment
  valid commitment later ceases to bind without physical settlement

settlement
  valid commitment is fulfilled by physical/net settlement evidence
```

The model deliberately does **not** encode legal reason taxonomies such as
waiver, expiry, novation, forgiveness, or jurisdiction-specific discharge.

Those names are downstream possibilities, not yet earned Core concepts.

## Deliberately weaker cancel projection

The candidate collapse remembers only:

```text
terminal target
optional successor
```

and forgets whether the edge came from:

```text
evidence correction
or
real-world extinguishment
```

That is the strongest useful form of a plain `cancel old -> successor` proposal.

If two semantically different worlds can share this projection, cancel alone is
not enough.

## Witness A — incorrect amount corrected

```text
recorded commitment 10
but reality/evidence should have been 1

10 --revision--> 1
```

Expected:

```text
outstanding = 1
```

The old 10 remains retained provenance but is not a valid historical obligation.

Expected Alloy result: **SAT**.

## Witness B — erroneous/duplicate commitment retracted

```text
commitment 10 was itself erroneous

10 --revision--> none
```

Expected:

```text
outstanding = 0
```

This is not evidence that a valid 10 obligation was later fulfilled or released.

Expected Alloy result: **SAT**.

## Witness C — valid commitment fully extinguished

```text
valid commitment 10
later non-settlement extinguishment 10
```

Expected:

```text
outstanding = 0
```

The historical answer differs from Witness B:

```text
B: the 10 commitment was not valid current evidence
C: the 10 commitment was valid and later ceased to bind
```

Expected Alloy result: **SAT**.

## Witness D — partial extinguishment

```text
valid commitment 10
later release 3

outstanding = 7
```

This is the strongest pressure against a Boolean/terminal cancel flag.

The target remains partly open.

Expected Alloy result: **SAT**.

## Witness E — real-world successor

```text
valid old commitment 10
fully extinguished 10
new real-world successor commitment 7
```

Expected:

```text
outstanding = 7
```

This deliberately has the same superficial shape as correcting an erroneous
`10` row into a `7` row:

```text
old -> successor
```

but the historical meaning differs.

Expected Alloy result: **SAT**.

## Critical falsification — same cancel view, different meaning

Two worlds are constructed over the same retained commitments:

```text
old = 10
successor = 7
```

World A:

```text
old --correction--> successor
```

World B:

```text
old --real-world extinguishment--> successor
```

Both expose:

```text
cancel old -> successor
current outstanding = 7
```

but they disagree on the historical question:

> Was the old 10 commitment valid before the transition?

Therefore the assertion:

```text
CollapsedCancelDeterminesLifecycleMeaning
```

is expected to have a **SAT counterexample**.

That is the direct falsification of plain cancel collapse.

## Settlement versus extinguishment

The model also compares:

```text
valid 10
physical settlement 3
remaining 7
```

with:

```text
valid 10
non-settlement extinguishment 3
remaining 7
```

The numeric answer is identical, but provenance is not.

Therefore:

```text
outstanding quantity
-/->
reason the obligation shrank
```

The assertion:

```text
OutstandingDeterminesReductionMeaning
```

is expected to have a **SAT counterexample**.

## Candidate conservation law

For a commitment that remains current evidence, the model tests:

```text
committed
=
settled
+ non-settlement-extinguished
+ outstanding
```

This generalizes the current production settlement equation:

```text
committed = settled + outstanding
```

without storing outstanding.

Expected:

```text
OutstandingNeverNegative       UNSAT counterexample
CurrentCommitmentPartition      UNSAT counterexample
```

The equation is only a bounded candidate law at this stage.

It does not yet decide whether non-settlement extinguishment belongs in the base
Settlement family, beside it, or in a later obligation lifecycle layer.

## Alloy result

Qualified on Alloy 6.2.0 with SAT4J through the repository's shared research
witness harness.

```text
correctionWitness                                 SAT
retractionWitness                                 SAT
fullExtinguishmentWitness                         SAT
partialExtinguishmentWitness                      SAT
successorExtinguishmentWitness                    SAT
sameCancelDifferentMeaningWitness                 SAT
sameOutstandingSettlementVsExtinguishmentWitness SAT

OutstandingNeverNegative                         UNSAT counterexample
CurrentCommitmentPartition                       UNSAT counterexample

EveryExtinguishmentIsTerminal                    SAT counterexample
CollapsedCancelDeterminesLifecycleMeaning        SAT counterexample
OutstandingDeterminesReductionMeaning            SAT counterexample
```

The result directly falsifies the untyped `cancel old -> optional successor`
collapse inside the bounded model. It also preserves the candidate arithmetic
partition for current commitments.

## Expected Alloy matrix

```text
correctionWitness                              SAT
retractionWitness                              SAT
fullExtinguishmentWitness                      SAT
partialExtinguishmentWitness                   SAT
successorExtinguishmentWitness                 SAT
sameCancelDifferentMeaningWitness              SAT
sameOutstandingSettlementVsExtinguishmentWitness SAT

OutstandingNeverNegative                       UNSAT counterexample
CurrentCommitmentPartition                     UNSAT counterexample

EveryExtinguishmentIsTerminal                  SAT counterexample
CollapsedCancelDeterminesLifecycleMeaning      SAT counterexample
OutstandingDeterminesReductionMeaning          SAT counterexample
```

## Finding

A plain terminal:

```text
cancel commitment
```

is too weak.

Even:

```text
cancel old -> optional successor
```

is too weak when the operation carries no semantic distinction.

At minimum, the system must be able to preserve the distinction between:

```text
evidence-side lifecycle
  correction
  retraction

real-world lifecycle
  settlement
  non-settlement extinguishment
```

Partial extinguishment additionally pressures the real-world side to retain an
exact quantity rather than a Boolean terminal marker.

## What this does not decide

This observation intentionally does **not** select a production representation.

It does not yet earn separate types named:

```text
Forgiveness
Waiver
Expiry
Novation
Cancellation
Release
```

It also does not prove that production needs four independent row families.

Possible future representations still include, for example:

```text
CommitmentRevision
  target
  replacement : Option CommitmentId

CommitmentReduction
  target
  quantity
  kind : settlement | nonSettlementExtinguishment
  successor : Option CommitmentId
```

or another smaller tagged form.

The next observation should ask which distinctions can safely share mechanics
without sharing semantic authority.

## Important identity question left open

Current production correspondence/member correction targets version-capable row
identity.

Commitment correction is harder because existing settlement evidence targets
`SettlementCommitmentId`.

If correction replaces one commitment identity with another, a later design
must decide whether existing correspondence/member evidence:

- remains attached to the historical target only;
- must itself be revised;
- follows a logical commitment identity through versions;
- or requires a separate commitment-version identity.

Observation 373 does not choose among these.

That question should be isolated before production commitment correction is
implemented.

## Stop condition

The qualified bounded matrix supports the stop condition:

1. reject untyped terminal cancel as the commitment lifecycle model;
2. keep production code unchanged;
3. carry forward only the two residual questions:
   - minimum representation for correction/retraction vs real-world
     extinguishment;
   - commitment logical identity vs version identity under correction.

Do not add a TUI commitment editor until those residuals are resolved well enough
that an ordinary typo has a safe append-only repair path.
