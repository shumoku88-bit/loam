# Observation 381 — deterministic production-scenario pilot

Status: **EXECUTABLE PILOT — TigerBeetle-inspired deterministic scenario testing; no production architecture change**

LOAM baseline:

```text
main a51c9f96daa7b7d3be036f4cf2df08f637339c09
#1448 merged
#1449 remains an independent open Observation-380 PR at pilot creation
```

External reference inspected:

```text
tigerbeetle/tigerbeetle
main 47aeb2212a255273dda508288412e537d11e4b7c
```

## Trigger

TigerBeetle's current deterministic simulation documentation describes a useful
testing discipline:

```text
production logic
+ controlled nondeterminism
+ deterministic seed
+ invariant/checker failures
+ Git revision
    -> exact replay of a failing world
```

Its VOPR stubs clocks, networking, and disk behavior, injects faults such as
packet loss, partitions, and storage corruption, then checks safety and liveness.

LOAM has a very different operational shape:

- one household authority rather than a replicated cluster;
- local filesystem publication rather than an unreliable network protocol;
- existing Lean/Alloy/TLA+ qualification for many semantic boundaries;
- explicit writer ownership and staged atomic replacement;
- several hand-written crash/retry integration tests already exercising known
  interruption points.

Therefore copying VOPR would be architecture theatre.

The narrower question is:

> Does a reproducible generated sequence over **existing production LOAM
> publication logic** find a useful testing layer between isolated regression
> cases and formal semantic proofs?

## Existing LOAM evidence

LOAM already has fixed executable interruption/retry qualifications.

For example, `ActualAuthorityCrashTest` covers:

```text
partial stage
completed stage before rename
atomic rename switch
malformed candidate refusal
retry after successful rename
```

Scheduled completion, Correction, Reversal, and Settlement tests likewise pin
specific retry and recovery stories.

Those tests are valuable because each names a known obligation precisely. They
should not be replaced by randomized scenarios.

## Pilot

The pilot adds one test-only executable:

```text
Loam/Tests/DeterministicMovementScenario.lean
```

It deliberately reuses production boundaries unchanged:

```text
MovementPublisher.publishDraftIdempotent
ActualAuthority
LocusAdmissionAuthority
NormalizedActualPersistence
writer ownership
typed normalized-Actual admission
```

No simulator interface is inserted into production code.

### Generated trace

A small deterministic recurrence generates 48 steps from a fixed seed.

Each step chooses:

- one stable Movement operation identity from a small collision-prone set;
- an amount;
- an approved destination Locus;
- occurrence date;
- description;
- and sometimes one deliberately invalid condition.

Invalid fresh drafts include:

```text
invalid calendar date
unapproved Locus
incorrect declared total
```

Because operation identities intentionally repeat, later generated payloads also
exercise the production idempotency rule:

```text
retained operation identity
    -> return original EventId
    -> do not revalidate/re-publish retry payload
```

Thus an invalid-looking retry payload after an earlier successful operation is
expected to reuse the first Event, while the same invalid payload under a fresh
operation identity must fail closed.

## Checkers after every step

After every generated operation, the pilot:

1. reloads through `ActualAuthority.loadActual?`, forcing production typed
   normalized-Actual admission;
2. checks Event / validity / description / Movement-operation counts against the
   model of successful logical operations;
3. checks every retained operation identity still maps to its original Event;
4. checks every mapped Event actually exists;
5. canonical-encodes the reloaded evidence;
6. decodes and re-encodes it;
7. requires the canonical bytes to remain unchanged;
8. requires on-disk `actual.loam` to equal that canonical encoding;
9. requires a rejected fresh operation to leave authority bytes unchanged.

This gives the generated trace a small executable oracle rather than treating
"the test did not crash" as success.

## Replay qualification

The complete scenario is run twice in separate household roots with the same:

```text
seed
step count
Git revision
production code
```

The final canonical `actual.loam` bytes and scenario statistics must be exactly
equal.

The selected seed is printed in failure contexts so a discovered failure can be
replayed directly.

## Distinct role beside formal methods

This pilot does not compete with LOAM's formal instruments.

```text
Lean
  general laws / production proof-carrying boundaries

Alloy
  bounded distinguishability / information loss

TLA+
  selected temporal state-machine behavior

fixed integration tests
  named known regressions and interruption stories

deterministic generated scenario
  unexpected composition failures across many production operations
  with exact replay
```

The generated runner can demonstrate the presence of an implementation/composition
bug. A passing seed is not a proof of absence.

## What this pilot deliberately does not do

It does not yet:

- stub or corrupt filesystem operations;
- inject process death at arbitrary instructions;
- simulate concurrent writers;
- create a general PRNG or property-testing library;
- introduce a new production state-machine abstraction;
- generate Scheduled, Correction, Reversal, Settlement, Capacity, or routing
  operations;
- replace existing fixed crash/retry tests;
- claim coverage comparable to TigerBeetle VOPR.

The local recurrence is test data generation, not a new randomness dependency.

## Expansion gate

The pilot earns expansion only if it stays understandable and proves useful.

The next candidate operation families, in order, are:

```text
Movement retry
    -> Correction / Reversal
    -> Settlement revisions / extinguishments
    -> Scheduled completion recovery
    -> selected publication-fault injection, only if a small seam emerges
```

Each addition must reuse production logic and add a checker for the new semantic
surface.

Do not introduce a general simulator abstraction until at least two materially
different operation families need the same mechanism.

## Stop condition

If this pilot passes but future operation families cannot reuse it without
callback-heavy or IO-abstraction machinery, retain the single test and stop.

TigerBeetle's lesson for LOAM is not "build a VOPR".

It is:

> Make surprising execution histories reproducible, run real logic, and pair
> generated histories with explicit invariants.
