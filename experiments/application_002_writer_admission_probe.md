# Application 002 writer admission probe

## Purpose

Application 001 showed that a query-shaped boundary can become a small verified executable gate in Dafny without moving quantity semantics out of Lean.

Application 002 asks the first writer-side question:

> Before an already-admitted candidate reaches persistence, what evidence is sufficient to authorize publication without silently overwriting concurrent change or repeated Event identity?

This is still a host-language probe. It is not a canonical household writer and does not make Dafny a permanent LOAM dependency.

## Existing pressure

The current Practical Core already has a narrow Event-memory admission law:

```text
EventMemory + Event
    -> add?
    -> updated memory | duplicate EventId refusal
```

Persistence already publishes a complete EventMemory through a sibling staging path followed by filesystem rename.

That gives one target a replacement boundary, but the persistence layer deliberately does **not** serialize concurrent writers. The current practical CLI therefore has a read-modify-publish window:

```text
load EventMemory
    -> prepare candidate
    -> EventMemory.add?
    -> saveEventMemory?
```

Two writers that both prepare against the same old memory can otherwise each publish a complete replacement, allowing the later replacement to lose the earlier writer's update.

Application 002 does not solve physical locking or transactions. It asks only what the application-level authorization gate must refuse.

## Publication evidence

The Dafny probe receives only three facts:

- a `PublicationSnapshot` token observed when the candidate was prepared;
- the `PublicationSnapshot` token corresponding to the state currently eligible for publication;
- whether the candidate Event identity is already present in that current EventMemory.

The snapshot token is **not** Event identity, Effect identity, semantic time, version order, authority, or provenance.

Only equality is observed:

```text
observed snapshot == current snapshot
```

How a future runtime obtains the token is intentionally unresolved. It may later require a revision token, digest, lock protocol, compare-and-swap mechanism, or another physical publication design. This probe does not earn any one of those choices.

In particular, a mutable-content-derived token must never be reused as stable Event or Effect identity.

## Decision

The verified gate returns exactly one typed result:

```text
observed != current
    -> RefuseStaleSnapshot

observed == current
    + candidate EventId already present
    -> RefuseDuplicateEventIdentity

observed == current
    + candidate EventId absent
    -> PublishCandidate
```

Staleness dominates. If the preparation is stale, the application refuses and requires fresh observation before interpreting whether the candidate remains distinct.

## Verification questions

Dafny is required to establish that:

1. executable `AuthorizeWriter` agrees exactly with `ExpectedWriterDecision`;
2. `PublishCandidate` occurs iff the snapshot is current and candidate Event identity is absent;
3. every stale preparation refuses publication;
4. repeated Event identity refuses publication when the snapshot is current;
5. under stale evidence, changing the candidate-identity-present flag cannot escape `RefuseStaleSnapshot`.

Synthetic execution covers:

```text
current + distinct
    -> PublishCandidate

current + duplicate
    -> RefuseDuplicateEventIdentity

stale + apparently distinct
    -> RefuseStaleSnapshot

stale + duplicate
    -> RefuseStaleSnapshot
```

## Meaning of `PublishCandidate`

`PublishCandidate` is authorization evidence, not an IO action.

It does not prove that:

- the filesystem write succeeds;
- a particular encoding is representable;
- a rename is power-loss durable;
- multiple physical streams update transactionally;
- the candidate has household accounting meaning beyond what Core already admitted;
- LOAM owns canonical household write authority.

A future runtime boundary would still have to connect this authorization to a concrete publication mechanism without creating a check-then-write race between revalidation and replacement.

That last step may require stronger physical primitives than the current persistence helper exposes.

## Why this is useful even if Dafny is removed

The retained application distinction is independent of Dafny:

```text
candidate preparation
    + current publication state
    ->
current-and-distinct
| stale
| duplicate identity
```

If Dafny later proves too expensive to keep, this distinction can be retained as an observation, Lean law, or requirement for an Ada/SPARK writer boundary.

## Scope

- one Dafny writer-admission probe;
- one dedicated synthetic workflow;
- no canonical data reads or writes;
- no Persistence changes;
- no Practical Core changes;
- no CLI changes;
- no lock implementation;
- no revision/digest format;
- no Observation 085.
