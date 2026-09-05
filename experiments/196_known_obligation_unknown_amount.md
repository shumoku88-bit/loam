# Observation 196 — Does a known obligation require evidence before its amount is known?

Status: **F051 active falsification observation**

## Question

The falsification atlas entry F051 asks about an ordinary household state:

```text
an obligation is known to exist
but
its exact amount is not known yet
```

Current practical `ScheduledOccurrence` is deliberately quantity-bearing: it contains an exact balanced movement. Current `RelationUnit` is also exact-quantity evidence. Attention can exist without an amount, but Observation 109 deliberately kept Attention meaning distinct from Scheduled / relation lifecycle meaning; an Attention item must not silently become financial-obligation evidence merely because its shape is convenient.

So the narrow question is:

> If every currently representable exact Scheduled fact is held fixed, can two worlds still differ on whether one future obligation is known to exist when no exact amount is available?

This is not yet a question about UI input, persistence syntax, nullable quantities, estimates, ranges, invoices, or debt objects.

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

## Expected probes

### Representative amount-unknown obligation

Can one obligation be known while having no exact Scheduled amount?

Expected: **SAT**.

### Same exact Scheduled evidence, different known existence

Can Left and Right have exactly the same `exactScheduledAmount` relation while one world knows an amount-unknown obligation exists and the other has no known obligation for that identity?

Expected: **SAT**.

This is the central F051 falsification witness.

### Same known existence, different amount knowledge

Can both worlds agree that the same obligation exists while one knows only existence and the other has an exact amount?

Expected: **SAT**.

This checks the reverse independence:

```text
existence knowledge
    !=
quantity knowledge
```

## Deliberately too-strong checks

### Exact Scheduled determines known obligation

```text
same exact Scheduled evidence
    ->
same known-obligation answer
```

Expected: **SAT counterexample**.

If so, the current exact Scheduled boundary is too small for the selected existence query.

### Known existence determines amount knowledge

```text
same known-obligation set
    ->
same known-vs-unknown amount state
```

Expected: **SAT counterexample**.

If so, simply retaining existence does not reconstruct exact quantity knowledge.

## Positive sufficiency checks

### Exact Scheduled + explicit existence-only evidence determines selected views

Expected counterexample: **UNSAT**.

This does not claim the candidate representation is canonical. It only checks that the selected information gap disappears once both independent answers are retained.

### Exact Scheduled subjects are known

Expected counterexample: **UNSAT**.

An exact Scheduled fact remains sufficient to say that its own represented obligation is known. Observation 196 attacks only the false converse:

```text
no exact Scheduled
    -/->
no known obligation
```

## Candidate interpretation if the matrix holds

The bounded result would be:

```text
known obligation existence
    !=
exact obligation quantity
```

and, more specifically:

```text
exact quantity-bearing Scheduled evidence
    -/->
all known future-obligation existence
```

This would earn **independently observable existence/claim information for this selected query**, not a production object.

Several later representations could still be information-equivalent:

- a relation-shaped claim whose quantity is not yet specified;
- another explicit evidence family linked to later exact Scheduled evidence;
- a richer claim state whose amount knowledge is separate from identity/existence;
- some smaller representation not yet considered.

The observation does not choose among them.

## Why existing Attention does not automatically close F051

Practical Attention deliberately has no amount, but Observation 109 established that Attention lifecycle meaning is its own semantic family. Reusing an Attention identity as proof that a financial obligation exists would add a new semantic correspondence that is not currently earned.

So this observation does not say Attention is unusable. It says only that **shape similarity is not already obligation provenance**.

## Why existing OpenRelation does not automatically close F051

Current `RelationUnit` carries an exact `Quantity`. It can represent an exact open directional obligation after the source Effect exists, but its present production shape does not itself represent “this obligation exists, exact amount still unknown.”

Observation 196 therefore does not compete with OpenRelation. It pressures an earlier epistemic boundary.

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

Production remains gated on real dogfood need even if a counterexample is found.

## Falsification status

Until the exact model executes successfully, F051 remains:

```text
Work     = OBSERVING
Finding  = UNTESTED
Runtime  = RESEARCH_ONLY
```
