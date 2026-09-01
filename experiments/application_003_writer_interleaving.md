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

TLC found the expected counterexample:

```text
A prepare at revision 0
A authorize at revision 0
B prepare at revision 0
B authorize at revision 0
A publish {A}, revision 1
B publish stale {B}, revision 2
```

At the final state both writers are marked done but the document contains only B. `NoCompletedUpdateLost` is violated.

TLC reached the violation at depth 7 after generating 25 states and finding 21 distinct states.

## Protocol B: revision-aware compare-and-swap

Publication succeeds only if the revision observed during preparation still equals the current revision at the publication step.

A writer whose authorization has become stale can return to observation and prepare again.

TLC found no safety error in the complete finite two-writer state space:

```text
29 states generated
23 distinct states
0 states left on queue
maximum depth 7
```

This model does not claim a filesystem rename is itself a compare-and-swap. It identifies the semantic primitive a physical writer would need to supply if this protocol is chosen.

## Protocol C: exclusive lock

A writer acquires exclusive ownership before observing and preparing the whole replacement and releases it only after publication.

TLC found no safety error in the complete finite two-writer state space:

```text
17 states generated
17 distinct states
0 states left on queue
maximum depth 9
```

This does not yet answer crash-safe lock recovery, stale lock ownership, process death, or distributed locking.

## Finding

The writer boundary is now sharper:

```text
semantic authorization at time t
    !=
permission to replace at a later time t+n
```

A stale check performed before publication is insufficient when another writer can publish between the check and the replacement.

For the modeled whole-memory publication shape, preserving already-completed updates requires at least one of these forms of physical exclusion:

```text
revision-aware conditional publication
or
exclusive ownership spanning observation through publication
```

This experiment does not choose between them. CAS keeps more concurrency but requires a real conditional replace primitive and retry behavior. Locking serializes the critical region but introduces lock ownership and crash-recovery questions.

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

The retained application lesson is therefore smaller than the TLA+ model:

```text
an admitted EventMemory must not be published by an unconditional
whole-memory replace after its observed publication revision can change
```

A later implementation should avoid duplicating the whole application model in TLA+.

## Qualification note

The first workflow run stopped on TLC deadlock detection before reaching the intended safety counterexample. The experiment intentionally makes no deadlock or liveness claim, so qualification was corrected to disable deadlock checking and let TLC explore the safety state graph.

With that correction, all three intended checks behaved as specified:

- naive protocol: expected `NoCompletedUpdateLost` counterexample;
- revision-aware CAS protocol: no safety error;
- exclusive lock protocol: no safety error.

## Tool boundary

The dedicated workflow pins the latest stable TLA+ release exposed by the official release channel at the time of this experiment:

```text
TLA+ tools v1.7.4
TLC 2.19
Java 17 runner
```

The official jar checksum is verified in CI. TLA+ remains an experiment-local instrument, not yet a permanent LOAM dependency.

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
