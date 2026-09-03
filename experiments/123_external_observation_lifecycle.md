# Observation 123 — Can pending -> posted remain an external-observation lifecycle?

## Household question

Observation 121 separated household `Actual` occurrence authority from bank/card/import observation authority and showed that explicit reconciliation cannot be reconstructed from record content alone.

A temporal pressure remains:

```text
source reports pending
        ↓ later
source reports posted
```

PFM software often exposes this as a mutable transaction status or replaces one imported row with another. LOAM should not assume that either source lifecycle has to mutate household Actual truth.

The question is:

> Can pending -> posted evolution remain entirely inside external-source evidence while the reconciled household Actual stays stable?

A second question is:

> If the current source view is `posted`, is that current projection sufficient to reconstruct whether pending evidence existed earlier?

## Why TLA+

This pressure is about reachable histories and operation order, not only static distinguishability.

The model therefore uses TLA+ / TLC rather than Alloy:

- a source may expose pending first and posted later;
- a source may expose posted directly with no prior pending observation;
- pending and posted evidence may each be reconciled to the same Actual;
- the household Actual quantity is held invariant throughout the source lifecycle.

No concurrent importer, retry protocol, or race is being modeled, so SPIN would not yet add a distinct result.

## Observation vocabulary

The model keeps two views deliberately separate.

### Current source projection

```text
none | pending | posted
```

This represents what a UI or source adapter may currently show.

### Retained source evidence

```text
pendingSeen
postedSeen
supersessionRecorded
pendingSupportsActual
postedSupportsActual
```

These booleans are bounded observation scaffolding, not proposed production fields.

They stand for information-equivalent retained evidence.

The household Actual is represented by one stable `actualQuantity` coordinate.

Synthetic quantities deliberately drift:

```text
pending observation = 9
posted observation  = 10
Actual               = 10
```

This asks whether a provisional source report may differ from the later posted source report without requiring an intermediate rewrite of household Actual.

## Reachable histories

### Pending then posted

```text
none
  -> pending
  -> posted
```

The current source projection ends at `posted`, while `pendingSeen` remains true and source supersession provenance is retained.

### Direct posted

```text
none
  -> posted
```

The current source projection is the same `posted`, but there was no earlier pending evidence.

If both histories are reachable, a mutable current source row is too small to answer `was pending evidence seen earlier?`.

### Dual corroboration

```text
pending evidence ----+
                      +-> same Actual
posted evidence  -----+
```

Both historical source observations may support the same household occurrence.

This is not two Actuals and does not imply that pending and posted quantities must be identical.

## Qualification target

The positive TLC configuration must preserve:

```text
TypeOK
ActualStable
SupersessionRequiresObservedEndpoints
SupportRequiresObservedSource
CurrentProjectionBackedByEvidence
```

Dedicated boundary configurations are intentionally too strong and must fail:

```text
NoPendingThenPostedHistory
NoDirectPostedHistory
NoDualSourceSupport
NoQuantityDriftSupport
```

Expected interpretation:

- `NoPendingThenPostedHistory` violation proves pending -> posted history is reachable;
- `NoDirectPostedHistory` violation proves posted-without-prior-pending is also reachable;
- together, those two violations show current `posted` projection does not determine prior-pending history;
- `NoDualSourceSupport` violation proves both source observations can support one Actual;
- `NoQuantityDriftSupport` violation proves provisional/final source quantities may differ while converging on the same stable Actual.

## Expected compression boundary

If qualified, the bounded boundary is:

```text
household Actual
    does not need to transition
    merely because source evidence goes pending -> posted
```

and:

```text
current source projection = posted
    does not determine
whether pending evidence existed earlier
```

So the selected questions can be answered by a decomposition like:

```text
stable household Actual

external source evidence history
    pending observation
        ↓ source supersession
    posted observation

reconciliation correspondence
    source evidence -> Actual

projection
    current source view
```

The current `pending` / `posted` label can therefore remain a projection of source evidence rather than a mutable status on Actual.

## Important restraint

This does **not** prove that every imported source record must be retained forever.

A source adapter may legally compact evidence if no household question needs the discarded provenance. The result is conditional:

> If later questions need to distinguish direct-posted from pending-then-posted history, a mutable current source row is insufficient.

The experiment also does not yet establish the production representation of source supersession.

## Neighboring boundaries

- Observation 121 separates external observation authority from Actual authority and requires explicit reconciliation for selected support answers.
- `AsynchronousSettlement.tla` models a different pressure: initiation/pending versus physical settlement of a household movement. Observation 123 must not collapse source-feed pending into physical unsettledness.
- Existing append-only provenance observations already show that current projections can lose history in other semantic families; Observation 123 tests whether that pressure appears specifically at the external-source boundary.

## Boundaries

Observation 123 does not establish:

- a production `ExternalObservation` type;
- a production source-supersession relation;
- a bank/card API;
- whether provider record IDs remain stable between pending and posted;
- whether pending evidence may disappear without a posted successor;
- authorization reversal / cancellation semantics;
- duplicate delivery or retry handling;
- concurrent import publication;
- fuzzy matching policy;
- automatic creation of Actual from source evidence;
- statement reconciliation;
- cross-institution transfer pairing;
- foreign exchange or valuation behavior;
- a mutable `pending`, `posted`, `cleared`, or `matched` flag on Actual.

The observation asks only whether source lifecycle history can evolve while household Actual remains semantically stable, and whether the current posted projection loses provenance that an append-only source-evidence history can retain.
