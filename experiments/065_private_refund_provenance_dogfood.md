# Observation 065 private dogfood — refund provenance beyond physical reversal

## Purpose

Observation 065 established two separations:

```text
Event records + net quantity
    !=
refund provenance
```

and:

```text
refund / reimbursement
    !=
Correction
```

This checkpoint asks whether the current private canonical Actual source still exerts the first pressure without copying private descriptions, dates, quantities, account-like coordinates, identities, or counterparties into the public repository.

It does not introduce Observation 085.

## The question used for dogfood

The observer deliberately does not decide which records are semantically refunds.

Instead it asks a narrower physical question:

> When a two-posting record reverses an Expense coordinate and its counter-coordinate, do prior physical records determine which earlier Event is the source?

For each such expense-reversal-shaped record it considers two increasingly permissive physical heuristics:

1. **exact opposite quantity** — same two coordinates and exactly opposite quantities;
2. **same-coordinate opposite direction** — same two coordinates and opposite posting directions, allowing partial quantity.

Descriptions are not read for classification or matching.

## Privacy-safe current snapshot pressure

A read-only inspection of the current private canonical snapshot exposes a representative expense-reversal-shaped record with this structural result:

```text
exact-opposite prior source candidates:
    zero

same-coordinate opposite-direction prior source candidates:
    multiple
```

No private value is needed to interpret that result.

The first heuristic is too strict for the observed shape: requiring equal magnitude leaves no source candidate.

The second heuristic admits partial offset, but becomes ambiguous: more than one earlier physical Event has the same coordinate shape and source direction.

Therefore the current real-data pressure is:

```text
exact quantity reversal
    is not required by the observed return shape

same-coordinate reverse direction
    does not uniquely identify the source
```

and hence:

```text
physical reversal evidence
    -/->
refund provenance
```

## Why this is Observation 065 rather than a new law

Observation 065 already modeled the stronger structural statement that the same retained Event records can support different refund relations.

This dogfood does not discover a new semantic primitive. It shows that two tempting practical reconstruction heuristics both fail on current canonical pressure:

```text
same magnitude + reverse direction
    -> too strict

same coordinates + reverse direction
    -> too ambiguous
```

The result therefore strengthens the existing boundary operationally rather than introducing Observation 085.

## Executable observer

`tools/private-refund-provenance-pressure.py` makes the physical ambiguity check repeatable.

It:

- accepts one Actual journal path;
- hashes the source before and after observation and refuses mutation;
- parses exact integer postings;
- identifies only two-posting physical expense-reversal shapes;
- counts prior exact-opposite and shape-compatible physical candidates;
- reports only aggregate zero / one / multiple candidate buckets;
- never prints dates, descriptions, quantities, coordinates, identities, paths, or source hashes;
- never assigns refund semantics from reversal shape;
- never chooses a source Event from physical candidates.

The use of run-local record order is query-local only. No record index is emitted or retained as stable identity.

## Synthetic qualification

The dedicated public workflow includes:

- a partial reversal with multiple same-coordinate prior candidates and no exact-opposite candidate;
- an exact reversal with one exact and one shape-compatible candidate;
- a non-expense transfer that must not be classified as an expense reversal;
- privacy assertions preventing synthetic descriptions, coordinates, and quantities from escaping;
- source digest equality before and after observation;
- two physically identical fixtures with different descriptions that must produce identical output.

This ensures the observer is neither hard-coded to return ambiguity nor secretly dependent on descriptive text.

## Correction boundary

Nothing in this dogfood changes the second Observation 065 result.

A return-like Event remains a historical occurrence. Physical offset does not imply that the earlier Event was mistaken, replaced, or superseded.

So:

```text
refund provenance
    !=
Correction parentage
```

remains the safe boundary.

## Practical Core impact

None.

```text
Practical Core additions: 0
Persistence additions:     0
CLI additions:             0
wire-format additions:     0
```

This checkpoint does not earn:

- a Practical Core `Refund` type;
- a refund relation persistence stream;
- automatic refund matching;
- description-based provenance inference;
- amount-based provenance inference;
- a universal one-to-one refund cardinality law;
- Correction-style treatment of refunds.

If a future practical operation needs to answer which earlier Event a return belongs to, the source relation must be retained explicitly or otherwise supplied by information-equivalent evidence. Current physical records alone do not earn that answer.
