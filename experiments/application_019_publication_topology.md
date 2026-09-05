# Application 019: Physical publication topology

## Pressure

Application 018 found that the strongest current production-size pressure is not
terminal presentation. It is mutation, admission, recovery, and especially the
ordered publication of one household operation across several separately
persisted evidence families.

The next question is therefore narrower than "put everything in one file":

```text
if semantic fact families stay separate,
which physical publication topology actually changes the temporal protocol?
```

This application is stacked on Application 018 at:

```text
1652ebb05e97795d714064357b1555ffa57561df
```

The production snapshot remains `main` at:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

No production source, persistence format, canonical fact, or household data is
changed.

## Why TLA+ is earned

The pressure is now temporal rather than lexical. A useful comparison must allow:

```text
publish supporting evidence
-> crash
-> restart
-> retry
-> reader observation
```

and ask which partial states are durable, which are visible to readers, and which
must remain part of recovery logic.

Application 003 already established that semantic admission and later physical
publication are different boundaries. Observation 155 separately established the
value of staging a complete image away from authority and exposing it with one
atomic authority transition. Application 019 reuses those lessons for one
multi-fact practical operation rather than inventing another storage framework.

## Fixed semantic payload

The model deliberately holds household meaning constant. It uses the maximum
current Movement fan-out as a synthetic payload:

```text
ActualValidity
EventDescription
RelationUnit
RelationDischarge
Event
```

Production descriptions, relations, and discharges are optional. The model makes
all five present only to expose the strongest publication fan-out. It does not
claim every Movement requires all five facts.

The five names remain distinct in every topology. A topology may co-locate their
bytes, but it may not merge their semantic meaning.

## Four physical topologies

### A. Separate streams, Event last

This abstracts the current maximum Movement publication shape:

```text
ActualValidity
-> EventDescription
-> RelationUnit
-> RelationDischarge
-> Event
```

Each step makes one more fact durable in an authority-side store. Event is the
reader activation boundary. A crash leaves a durable prefix and retry resumes
without letting that prefix appear as a complete Movement.

### B. One typed stream, still one fact per append

All five fact families are physically co-located, but the writer still appends
one typed fact at a time and appends Event last.

At the temporal level this has the same transition relation as A. The filesystem
shape changed; the number and order of semantic publication steps did not.

This candidate is included specifically to test the tempting assumption:

```text
one file => one publication boundary
```

The model does not grant that implication.

### C. One typed stream plus explicit commit marker

The five semantic facts are appended durably, then a sixth commit marker changes
reader visibility:

```text
five typed fact appends
-> commit marker
```

This centralizes the visibility gate, but the pre-commit records are still
partial durable content in the authority-side store. A marker alone therefore
does not remove interruption residue.

### D. Non-authoritative staging plus atomic bundle publication

The five facts are assembled in staging state that readers do not treat as
canonical authority. Only a complete stage can cross one atomic authority
boundary:

```text
partial stage may exist
-> complete stage
-> one authority publication
```

This is deliberately the strongest candidate. It assumes a real primitive that
can expose the complete operation atomically. A single file name or an ordinary
sequence of appends does not provide that primitive by itself.

## Crash boundary

The model permits one crash before completion. The crash preserves all durable
or staged bytes and resets only the writer's local progress cursor.

This is enough to make retry traverse interrupted states without introducing a
full process or filesystem model. Set union makes retry idempotent at the fact
abstraction used here; exact duplicate-record encoding is outside scope.

## Safety question

Readers classify the operation as:

```text
none
complete
partial
```

For A and B, Event is the activation gate. For C and D, the explicit marker is
the gate.

The principal reader invariant is:

```text
ReadersNeverSeePartial
```

All four topologies are expected to satisfy it. This is important: Application
019 is not trying to prove the current Event-last protocol unsafe. The current
protocol is intentionally designed so pre-Event residue is inert.

## Authority-store residue question

A second property asks something different:

```text
NoPartialAuthorityStore
```

"Authority store" here means durable bytes in the publication surface that the
operational system must retain and reason about, even when readers do not yet
show a complete Movement.

The expected boundary is:

```text
A separate streams        -> partial authority-store state reachable
B typed sequential stream -> partial authority-store state reachable
C commit-marked stream    -> partial authority-store state reachable
D atomic bundle           -> no partial authority-store state
```

D is not magic. Its staging surface may still be partial. A dedicated negative
boundary requires `NoPartialStage` to fail for D, proving the model did not erase
interruption work; it moved partial work outside authority.

## Non-vacuity

A dedicated `NoCompletePublication` invariant is expected to fail under every
protocol configuration. This proves each finite model reaches a completed
publication rather than satisfying safety by never finishing.

## What the comparison can establish

If TLC confirms the intended boundaries, three useful conclusions follow.

First:

```text
separate streams -> one typed stream
```

is not by itself temporal compression when facts are still appended one by one.
It may reduce encoders, paths, or open/rename mechanics, but it does not remove
ordered fact publication or durable crash prefixes.

Second:

```text
add commit marker
```

can make one generic visibility gate, but it does not by itself remove partial
durable records. It may still simplify domain-specific activation logic, but that
is a separate implementation hypothesis requiring source work after this model.

Third:

```text
stage outside authority + atomic complete publication
```

is the only modeled topology that collapses the authority-store transition from
partial prefixes to old-or-complete. That is a stronger storage primitive, not a
naming refactor.

## Relationship to current Event-last publication

The current Event already behaves like an operation-specific activation marker
for several sibling evidence families. This matters because a new generic commit
marker would otherwise risk merely duplicating a role LOAM already has.

The likely compression question after this application is therefore not:

```text
should Event be replaced by Commit?
```

It is:

```text
can the physical writer publish one already-admitted multi-fact operation
through one authority transition while keeping Event, validity, description,
relation, and discharge independently typed?
```

That question reaches storage design and must preserve append-only provenance,
correction frontiers, and inspectability.

## Explicit limits

This model does not include:

- two concurrent writers;
- filesystem rename or append implementation details;
- durability guarantees of a particular OS/filesystem;
- checksum or torn-record parsing;
- exact Event/Relation identity collision rules;
- optional omission of description/relation/discharge;
- independent migration of one fact family;
- correction graphs;
- liveness or fairness;
- source-line reduction estimates.

Application 003 remains the relevant concurrency observation. Observation 155
remains the relevant complete-image publication precedent. Application 019 only
compares the interruption topology of one already-admitted multi-fact operation.

## Qualification plan

The dedicated Application 019 workflow pins TLA+ tools 1.7.4 and checks:

1. `TypeOK` and `ReadersNeverSeePartial` for all four topologies;
2. expected `NoPartialAuthorityStore` counterexamples for A, B, and C;
3. `NoPartialAuthorityStore` success for D;
4. expected `NoPartialStage` counterexample for D;
5. expected `NoCompletePublication` counterexample for all four topologies.

Exact TLC state counts are intentionally not treated as a code-size metric. The
important result is which state boundary exists, not how many model states happen
to encode it.

## What this does not earn

Even a successful model does not authorize:

- merging the current persistence files;
- introducing one universal fact log;
- adding a generic commit framework;
- deleting Event-last recovery checks;
- changing identity allocation;
- changing production writer order;
- changing canonical household data.

A later production experiment would first need a concrete physical primitive and
a migration story. Until then this is an observation of topology only.
