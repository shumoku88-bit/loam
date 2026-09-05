# Observation 196 — Does a known obligation require evidence before its amount is known?

Status: **qualified F051 falsification result**

## Question

The falsification atlas entry F051 asks about an ordinary household state:

```text
an obligation is known to exist
but
its exact amount is not known yet
```

Current practical `ScheduledOccurrence` is deliberately quantity-bearing: it contains an exact balanced movement. Current `RelationUnit` is also exact-quantity evidence. Attention can exist without an amount, but Observation 109 deliberately kept Attention meaning distinct from Scheduled / relation lifecycle meaning; an Attention item must not silently become financial-obligation evidence merely because its shape is convenient.

The narrow question is:

> If every currently representable exact Scheduled fact is held fixed, can two worlds still differ on whether one future obligation is known to exist when no exact amount is available?

This is not a question about UI input, persistence syntax, nullable quantities, estimates, ranges, invoices, or debt objects.

## Candidate compression under attack

A too-small candidate says:

```text
known future obligation
    =
there exists an exact quantity-bearing Scheduled fact
```

Under that candidate, absence of exact Scheduled evidence collapses two possible states:

```text
A. no known obligation

B. obligation known, amount unknown
```

F051 asks whether a legitimate household query can distinguish A from B.

## Why Alloy

This is a static two-world information question.

We hold exact quantity-bearing evidence equal and vary only one candidate information distinction. No publication ordering, retry behavior, or arithmetic theorem is involved.

Therefore Alloy is the smallest useful instrument.

## Observation-local vocabulary

The model uses neutral bounded identities:

```text
Obligation
Amount
World
```

Each world has:

```text
exactScheduledAmount : Obligation -> lone Amount
knownWithoutAmount    : set Obligation
```

`exactScheduledAmount` is only an information-equivalent abstraction of the exact quantity-bearing Scheduled boundary for this selected question. It does not copy the full practical Scheduled movement structure into Alloy.

`knownWithoutAmount` is deliberately **experiment-local evidence**. It is not a proposal for a production `UnknownAmountScheduled`, `Obligation`, `Invoice`, `Claim`, or nullable `Quantity` type.

For one bounded snapshot, the two evidence shapes are disjoint. Transition from amount-unknown to amount-known is explicitly outside this observation.

## Selected views

The model asks only:

```text
known obligations
known obligations whose amount is unknown
known obligations whose amount is exact
no-known-obligation subjects
```

Nothing else is inferred.

## Executed Alloy result

Alloy 6.2.0 + Sat4j produced exactly the expected matrix:

```text
representativeUnknownAmount                    SAT
sameExactScheduledDifferentKnownExistence      SAT
sameKnownExistenceDifferentAmountKnowledge     SAT
ExactScheduledDeterminesKnownObligation        SAT counterexample
KnownExistenceDeterminesAmountKnowledge        SAT counterexample
ExplicitKnowledgeDeterminesSelectedViews       UNSAT counterexample
ExactScheduledSubjectsAreKnown                 UNSAT counterexample
```

Dedicated Observation 196 CI completed successfully with the full expected-result checker.

## What the witnesses show

### Exact Scheduled evidence does not determine known existence

`sameExactScheduledDifferentKnownExistence` is SAT and `ExactScheduledDeterminesKnownObligation` has a counterexample.

A concrete bounded witness keeps the exact Scheduled relation identical in both worlds, including the empty exact-Scheduled case, while Left retains an amount-unknown obligation and Right retains no known obligation for that identity.

So:

```text
same exact quantity-bearing Scheduled evidence
    +
different known-obligation existence
```

is possible.

The candidate compression therefore loses observable information.

### Existence knowledge does not determine quantity knowledge

`sameKnownExistenceDifferentAmountKnowledge` is SAT and `KnownExistenceDeterminesAmountKnowledge` has a counterexample.

Two worlds can agree that an obligation is known while disagreeing on whether an exact amount is known.

Thus:

```text
known obligation existence
    !=
exact obligation quantity knowledge
```

in both directions relevant to the selected vocabulary.

### Explicit existence-only evidence closes the selected information gap

`ExplicitKnowledgeDeterminesSelectedViews` has no counterexample in the bounded scope.

Once both the exact Scheduled relation and the experiment-local existence-only evidence are fixed, all selected knowledge views are fixed.

This is a sufficiency result only for the selected bounded vocabulary. It does not establish that `knownWithoutAmount` is the production representation.

### Exact Scheduled still entails known existence for its own subject

`ExactScheduledSubjectsAreKnown` has no counterexample.

Observation 196 therefore does not weaken the existing Scheduled meaning. Exact Scheduled evidence remains enough to know that its represented obligation exists.

The failed converse is the important boundary:

```text
no exact Scheduled evidence
    -/->
no known obligation
```

## Finding

Observation 196 falsifies the tested compression:

```text
known future obligation
    =
exact quantity-bearing Scheduled fact
```

The qualified bounded separation is:

```text
known obligation existence
    !=
exact obligation quantity
```

and more specifically:

```text
exact quantity-bearing Scheduled evidence
    -/->
all known future-obligation existence
```

For a vocabulary that asks whether an obligation is already known before its amount is known, **some information-equivalent existence/claim evidence is independently observable**.

This earns an information distinction, not a product noun.

Several later representations could still be information-equivalent:

- a relation-shaped claim whose quantity is not yet specified;
- another explicit evidence family linked to later exact Scheduled evidence;
- a richer claim state whose amount knowledge is separate from identity/existence;
- some smaller representation not yet considered.

Observation 196 does not choose among them.

## Why existing Attention does not automatically absorb F051

Practical Attention deliberately has no amount, but Observation 109 established that Attention lifecycle meaning is its own semantic family. Reusing an Attention identity as proof that a financial obligation exists would add a semantic correspondence that is not currently earned.

Shape similarity is not already obligation provenance.

## Why existing OpenRelation does not automatically absorb F051

Current `RelationUnit` carries an exact `Quantity`. It can represent an exact open directional obligation after the source Effect exists, but its present production shape does not itself represent “this obligation exists, exact amount still unknown.”

Observation 196 therefore pressures an earlier epistemic boundary rather than competing with OpenRelation.

## Deliberate boundaries

Observation 196 does **not** establish:

- a production `Obligation` type;
- `Option Quantity` inside `ScheduledOccurrence`;
- approximate quantities or ranges (F049/F050);
- unknown due date (F052);
- invoices, bills, receivables, payables, debt, or contracts;
- how amount-unknown evidence becomes exact later;
- correction, conflict, authority, source, confidence, or learned-time semantics;
- whether an unknown amount contributes to Commitment, Headroom, Remaining, or forecast arithmetic;
- persistence, CLI, TUI, notification, or household-data changes.

Production remains gated on real dogfood need.

## Falsification status

F051 is now:

```text
Work     = DONE
Finding  = COUNTEREXAMPLE
Runtime  = RESEARCH_ONLY
```
