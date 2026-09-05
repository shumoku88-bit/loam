# Observation 182: discharge publication activation

## Context

Observation 178 qualified exact discharge quantity as independent provenance for aggregate `RelationUnit` values. PR #367 promotes only the raw Core shape:

```text
RelationDischarge
  event: EventId
  target: RelationUnitId
  quantity: Quantity
```

PR #369 then adds a target-local Application projection that derives exact outstanding quantity and fails closed on malformed queried discharge evidence.

The recurring household witness now has both semantic halves:

```text
travel payment
  -> friend -> Household RelationUnit 400

later PayPay receipt
  -> exact discharge of that RelationUnit
```

Before adding a physical discharge stream or Movement writer, one remaining protocol question must be isolated.

## Question

Can a fresh practical Movement that fulfills an existing RelationUnit publish its discharge evidence in an independent stream while keeping the new Event as the semantic activation edge?

A natural candidate mirrors Observation 177:

```text
writer
  discharge decision / qualification
  -> publish positive RelationDischarge when any
  -> Event last

reader
  Event
  -> discharge
```

But discharge exposes one extra issue that RelationUnit publication did not have in the same form.

A pre-Event `RelationUnit` row points to a source Event that does not yet exist and is naturally excluded from an unrelated source-local relation query. A pre-Event `RelationDischarge`, however, targets an already-live RelationUnit. PR #369 currently treats a queried discharge whose later Event is missing as unresolved.

Therefore this crash prefix:

```text
RelationDischarge written
-> crash
-> later Event absent
```

would make the previously valid outstanding answer unavailable even though no authoritative fulfillment Event exists yet.

Observation 182 asks whether the safe activation rule should instead be:

```text
raw discharge + later Event absent
  -> inert crash residue

raw discharge + later Event present
  -> semantically active candidate
  -> malformed/conflicting evidence still fails closed
```

## Existing outstanding truth

The bounded models use one already-current RelationUnit with exact outstanding quantity `10`.

A fresh later Movement may have one qualified discharge of `4`, so after that Event becomes authoritative the correct outstanding quantity is `6`.

The physical Event and discharge evidence remain distinct. The Event does not encode settlement meaning by itself; it acts as the activation edge only because the writer protocol guarantees that required discharge evidence was completed first.

## Candidate writer order

For a Movement with discharge meaning:

```text
collect physical Event draft
+ select current RelationUnit target
+ exact discharge quantity

under writer ownership:
  re-read current state
  -> qualify discharge
  -> publish RelationDischarge support
  -> publish Event last
```

If discharge persistence fails, Event publication must not occur.

If the process crashes after discharge persistence but before Event publication, the raw row may remain. No rollback is required if admission keeps that row inert while its later Event is absent.

For a Movement with no discharge meaning, no discharge row is written.

## Candidate reader order

For this bounded fresh-Movement publication shape:

```text
Event snapshot
-> discharge snapshot
```

If a reader sees the new Event, the writer must already have published any required discharge support. Reading discharge afterward can catch up to that support.

The reverse order is unsafe. A reader may first retain an old discharge snapshot, then see the new Event after the writer has completed, producing an outstanding value that is too high.

This is analogous to Observation 177's relation-reader asymmetry, but the semantic failure is different:

```text
Observation 177
  stale relation absence -> false known-none

Observation 182
  stale discharge absence -> false high outstanding quantity
```

## SPIN models

### Safe candidate

`182_discharge_publication_safe.pml`

The writer nondeterministically chooses discharge or no-discharge meaning.

For positive discharge:

```text
discharge row
-> qualification done
-> optional crash or Event commit
```

The reader acquires Event before discharge.

Assertions require:

- visible Event implies qualification completed;
- visible Event with true discharge meaning sees the discharge support and derives `6`;
- visible Event with no discharge meaning retains `10`;
- discharge-first crash residue with no Event authority leaves the old outstanding answer `10` available.

Expected: **0 errors**.

### Unsafe writer order

`182_discharge_publication_unsafe_writer.pml`

The true discharge is `4`, but the writer publishes Event before the discharge row.

An Event-first reader can observe Event authority plus old discharge absence and report `10` instead of `6`.

Expected: **assertion violation**.

### Unsafe reader order

`182_discharge_publication_unsafe_reader.pml`

The writer uses discharge-first / Event-last, but the reader snapshots discharge before Event.

It can retain old discharge absence and later observe the authoritative Event, again reporting `10` instead of `6`.

Expected: **assertion violation**.

### Unsafe strict orphan admission

`182_discharge_publication_unsafe_orphan_admission.pml`

The writer publishes the discharge row and crashes before Event publication.

A strict reader treats the unresolved later Event reference as enough to make the target's outstanding query unavailable.

Expected: **assertion violation**.

The desired answer while the later Event is absent is still the pre-discharge outstanding quantity `10`.

## Candidate consequence if qualified

The smallest safe physical boundary for fresh Movement discharge would be:

```text
writer:
  discharge qualification
  -> required discharge persistence
  -> Event last

reader:
  Event
  -> discharge

admission:
  later Event absent
    -> raw discharge inert

  later Event present
    -> discharge participates in target-local admission
    -> zero/negative quantity, duplicate Event/target pair,
       over-discharge, bad target, etc. remain fail-closed
```

This would require a narrow follow-up to PR #369: unresolved later-Event references should be ignored only when the Event is genuinely absent. That must not become a generic "filter malformed rows" rule.

## Identity reservation after crash

If raw discharge persistence is later implemented, every retained discharge `event : EventId` must reserve that Event identity during fresh Movement ID allocation.

Otherwise:

```text
crash leaves discharge(event = record-7)
-> retry chooses record-7 for unrelated Movement
-> stale discharge becomes accidentally active
```

This is the same identity-safety pattern already applied by PR #364 to pre-Event RelationUnit residue.

Observation 182 does not implement the allocator change, but any future discharge writer must qualify it before publication.

## What this would earn

Only if the SPIN matrix holds:

- pressure for one independent raw discharge persistence stream;
- discharge-first / Event-last publication for fresh practical Movement;
- Event-first / discharge-second acquisition for this bounded reader;
- missing-later-Event discharge residue treated as inert rather than as target-query failure;
- reservation of retained discharge EventIds in fresh Event ID allocation;
- no rollback requirement for harmless pre-Event discharge residue.

## What this does not earn

Observation 182 does **not** earn:

- discharge persistence format by itself;
- a discharge writer implementation;
- `DischargeId`;
- discharge revision/reversal semantics;
- RelationRevision-as-discharge;
- automatic matching by amount, endpoint, sign, or date;
- a Settlement entity;
- a cross-stream transaction/manifest;
- multi-writer concurrency claims;
- fsync or power-loss guarantees;
- a universal reader protocol;
- completeness cutover;
- Scheduled/correction/historical discharge qualification;
- later Effect-level discharge anchoring;
- historical backfill.

## Stack

Observation 182 is stacked on PR #369 `application/relation-discharge-frontier` at exact head:

`984022373c7299195321e774c0b43fb19f881ec4`

The relation/discharge stack remains open and unmerged. Observations 179–181 on main are independent.
