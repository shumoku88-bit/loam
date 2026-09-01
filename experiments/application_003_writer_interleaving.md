# Application 003: writer interleaving

This experiment begins where Application 002 stops.

Application 002 can decide whether a candidate is stale or duplicate at an authorization boundary. That is not yet a physical publication protocol. A second writer may change the canonical memory after authorization and before whole-memory replacement.

The question here is deliberately narrow:

> When two writers prepare updates from a shared whole-memory snapshot, which publication protocols preserve every update that has already completed?

## Model

Two abstract writers each contribute one distinct Event identity to an abstract document. `document` represents the set of remembered contributions, not a new Practical Core type or persistence format.

A writer may:

```text
observe document + revision
    -> prepare replacement document
    -> authorize
    -> publish whole replacement
```

The model retains the prepared whole document so that stale replacement can actually overwrite another writer's completed contribution.

The safety property is:

```text
NoCompletedUpdateLost

for every writer marked done,
that writer's contribution remains in the published document
```

This is intentionally weaker than serializability, durability, fairness, crash recovery, or cross-stream atomicity. It asks only whether a completed update can disappear.

## Protocol A: naive check then replace

Authorization checks that the revision observed during preparation is still current.

Publication itself does not revalidate that revision.

Therefore the following interleaving is admitted by the model:

```text
A prepare at revision 0
B prepare at revision 0
A authorize at revision 0
B authorize at revision 0
A publish {A}, revision 1
B publish stale {B}, revision 2
```

The expected TLC result is a counterexample to `NoCompletedUpdateLost`.

## Protocol B: revision-aware compare-and-swap

Publication succeeds only if the revision observed during preparation still equals the current revision at the publication step.

A writer whose authorization has become stale returns to observation and prepares again.

The expected TLC result is that `NoCompletedUpdateLost` is invariant for the complete finite two-writer state space.

This model does not claim a filesystem rename is itself a compare-and-swap. It only identifies the semantic primitive a physical writer would need to supply if this protocol is chosen.

## Protocol C: exclusive lock

A writer acquires exclusive ownership before observing and preparing the whole replacement and releases it only after publication.

The expected TLC result is that `NoCompletedUpdateLost` is invariant for the complete finite two-writer state space.

This does not yet answer crash-safe lock recovery, stale lock ownership, process death, or distributed locking.

## Relationship to Lean Application 002

Lean can keep the semantic writer gate in the existing Core type world:

```text
EventMemory + Event
    -> stale/duplicate admission
    -> admitted EventMemory or refusal
```

TLA+ is not replacing that code. It observes a different dimension:

```text
writer A over time
writer B over time
physical publication boundary
```

A later implementation should therefore avoid duplicating the whole application model in TLA+. The retained result should be the smallest publication law or primitive justified by this interleaving experiment.

## Tool boundary

The dedicated workflow pins the latest stable TLA+ release exposed by the official release channel at the time of this experiment:

```text
TLA+ tools v1.7.4
Java runtime
```

The jar checksum is verified in CI. TLA+ is still an experiment-local instrument, not yet a permanent LOAM dependency.

## Scope

- two synthetic writers only
- one whole-document replacement abstraction
- one safety invariant
- naive / CAS / exclusive-lock comparison
- no canonical household data
- no Practical Core changes
- no Persistence changes
- no production CLI changes
- no lock or CAS implementation
- no crash/recovery model
- no liveness claim
- no cross-stream transaction claim
- no Observation 085
