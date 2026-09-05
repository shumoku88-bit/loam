# Application 019: Physical publication topology

## Pressure

Application 018 found that LOAM's strongest current production-size pressure is
mutation, admission, recovery, and especially ordered publication across several
persisted evidence families. The next question is therefore narrower than
"put everything in one file":

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

No production source, persistence format, canonical fact, writer behavior, or
household data changes here.

## Why TLA+ is earned

The pressure is temporal rather than lexical. The comparison must allow:

```text
publish support
-> crash
-> restart
-> retry
-> reader observation
```

and distinguish partial durable authority from partial non-authoritative staging.
Application 003 already separated semantic admission from later physical
publication. Observation 155 established complete-image staging plus one atomic
authority transition as a useful publication primitive. Application 019 applies
those lessons to one multi-fact practical operation.

## Fixed semantic payload

The model holds household meaning constant and uses the maximum current Movement
fan-out as a synthetic payload:

```text
ActualValidity
EventDescription
RelationUnit
RelationDischarge
Event
```

Descriptions, relations, and discharges are optional in production. All five are
present here only to expose the strongest publication fan-out. Their meanings
remain distinct in every topology.

## Four topologies

### A. Separate streams, Event last

```text
ActualValidity
-> EventDescription
-> RelationUnit
-> RelationDischarge
-> Event
```

Each step makes another fact durable in an authority-side store. Event is the
reader activation boundary. A crash can leave a durable prefix, but that prefix
must remain semantically inert until Event appears.

### B. One typed stream, one fact per append

The same five typed facts are physically co-located but still appended one at a
time with Event last. At this abstraction A and B deliberately share the same
transition relation: changing file count alone does not create a new temporal
publication boundary.

### C. One typed stream plus commit marker

The five facts become durable first, then a sixth marker changes reader
visibility:

```text
five typed appends
-> commit marker
```

The marker centralizes activation, but pre-commit records still form partial
durable content in the authority-side store.

### D. Non-authoritative stage plus atomic bundle publication

The five facts are assembled outside authority. A complete stage crosses one
atomic authority boundary:

```text
partial stage may exist
-> complete stage
-> one authority publication
```

This candidate assumes a real complete-bundle publication primitive. A single
file name or ordinary append sequence does not provide that primitive by itself.

## Crash model

One crash may occur before completion. Durable and staged bytes survive; only the
writer's local progress cursor is reset. Retry is idempotent at this fact-set
abstraction. Exact duplicate-record encoding, torn writes, and filesystem
semantics are outside scope.

## Checked properties

Readers classify the modeled operation as `none`, `complete`, or `partial`.

The positive reader invariant is:

```text
ReadersNeverSeePartial
```

A and B use Event as their activation gate. C and D use the explicit marker.

A second invariant distinguishes physical authority-store residue:

```text
NoPartialAuthorityStore
```

A dedicated atomic boundary also tests:

```text
NoPartialStage
```

and a non-vacuity boundary requires this deliberately too-strong invariant to
fail for every topology:

```text
NoCompletePublication
```

## TLC result

Application 019 qualified successfully on exact head
`dab5832ff8a73bbf87acd366c09be22e3102c64c` with TLA+ tools 1.7.4 / TLC.
The dedicated workflow completed every intended positive and negative check.

The observed boundary is:

```text
                              reader partial?   partial authority store?
A separate streams                 no                    yes
B typed sequential stream          no                    yes
C commit-marked stream             no                    yes
D atomic bundle                    no                    no
```

For D, partial staging is reachable. The successful expected-counterexample check
for `NoPartialStage` confirms that the atomic model does not pretend partial work
disappears. It moves partial work outside authority.

All four `NoCompletePublication` boundary checks also produced the expected
counterexample, so every topology reaches completed publication. Reader safety is
therefore not vacuous.

## Finding 1: one typed file is not temporal compression by itself

The comparison rejects this implication:

```text
one file => one publication boundary
```

If the writer still durably appends the same semantic facts one by one, the
interruption topology is unchanged at this abstraction. A typed stream may still
reduce path, encoder, or file-management mechanics, but it does not by itself
remove ordered publication, durable prefixes, or retry pressure.

## Finding 2: a commit marker changes visibility, not residue

An explicit marker can provide one generic activation gate, but the modeled
pre-commit facts remain partial durable authority-store content. It therefore does
not by itself remove the state that recovery logic must recognize.

This is especially relevant because current Event-last publication already gives
several supporting fact families an operation-specific activation gate. Adding a
generic marker could merely duplicate that role unless it also changes the
physical publication boundary.

## Finding 3: atomic bundle publication is the topology-changing primitive

Only the atomic-bundle model eliminates partial authority-store states while
preserving partial preparation outside authority.

So the genuinely different candidate is not:

```text
many semantic facts -> one semantic fact
```

and not merely:

```text
many files -> one file
```

It is:

```text
many independently typed facts
-> one complete physical authority transition
```

This is a storage primitive. It is not earned by source refactoring alone.

## Relationship to current Event-last protocol

Application 019 does **not** find the current protocol unsafe. All four topologies
preserve the modeled reader safety property. Current Event-last publication is a
real safety mechanism, not accidental boilerplate.

The source-size question is sharper now:

```text
can LOAM admit Event, validity, description, relation, and discharge separately,
but physically publish the already-admitted operation through one authority
transition?
```

If yes, some writer-specific interruption and identity-reservation machinery may
become derivable or removable. That claim is not made yet.

## Explicit limits

This model does not include:

- two concurrent writers;
- filesystem rename/append implementation details;
- durability guarantees of a particular OS or filesystem;
- checksum or torn-record parsing;
- exact Event/Relation identity collision rules;
- optional omission of supporting fact families;
- independent migration of one fact family;
- correction graphs;
- fairness or liveness;
- source-line reduction estimates.

Application 003 remains the concurrency observation. Observation 155 remains the
complete-image publication precedent.

## What this earns

Application 019 earns these limited conclusions:

1. current Event-last and the three alternatives can all preserve the modeled
   no-partial-reader property;
2. moving per-fact writes into one typed stream does not by itself remove partial
   durable authority states;
3. adding a commit marker does not by itself remove those states either;
4. staging outside authority plus one atomic complete-bundle publication does
   remove partial authority states in the modeled operation while retaining
   reachable partial staging.

It does **not** earn merging current persistence files, a universal fact log, a
generic commit framework, changing Event meaning, deleting recovery checks,
changing identity allocation, or modifying household data.

## Next pressure

If this line continues, the next useful observation is concrete rather than
architectural:

```text
what is the smallest physical atomic-bundle primitive LOAM could actually
implement while preserving append-only provenance and independent typed facts?
```

That should compare at least one realizable storage shape against current
Event-last publication before any production migration is attempted.
