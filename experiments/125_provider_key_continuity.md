# Observation 125 — Does provider key identity determine source lifecycle continuity?

## Household question

Observation 124 showed that repeated delivery and retained external-observation identity cannot be collapsed into one notion. A new pressure immediately follows:

```text
pending source record: provider key P
posted source record:  provider key Q
```

Some providers may preserve one identifier across lifecycle updates. Others may replace identifiers, or expose different record identities for provisional and final evidence.

The question is:

> If provider keys differ, must the pending and posted observations be different source lifecycles, or can explicit continuity evidence join them into one lifecycle?

A second question is:

> Do provider keys, stage, and visible source shape determine whether two observations belong to one lifecycle?

## Why Alloy

Observation 123 already established the temporal reachability of `pending -> posted` external-source evolution. Observation 125 is narrower: it asks whether static source facts determine continuity once two observations exist.

That is a bounded distinguishability / minimum-sufficiency question, so Alloy is the smaller instrument than another temporal model.

## Bounded vocabulary

The model has exactly two source observations:

```text
PendingObs
  key   = PendingKey
  stage = pending
  shape = SharedShape

PostedObs
  key   = PostedKey
  stage = posted
  shape = SharedShape
```

The provider keys are distinct by construction.

Two worlds retain the exact same observations, provider keys, stages, and visible source shape. They may differ only in explicit source-continuity evidence:

```text
Left:
PendingObs -> PostedObs

Right:
no continuity edge
```

The model derives source lifecycle starts from that continuity relation.

## Qualification target

Expected witnesses:

```text
linkedAcrossProviderKeyChange             SAT
sameSourceEvidenceDifferentContinuity     SAT
providerKeyWouldSplitLinkedLifecycle      SAT
```

Expected counterexamples:

```text
DifferentProviderKeysImplyDifferentLifecycles   SAT counterexample
ProviderFactsDetermineContinuity                SAT counterexample
ProviderFactsDetermineLifecycleCount            SAT counterexample
```

And once explicit continuity itself is fixed:

```text
ExplicitContinuityDeterminesLifecycleCount      UNSAT counterexample
```

## Expected compression boundary

If qualified:

```text
provider key
    !=
source lifecycle identity
```

and:

```text
provider key
+ stage
+ visible source shape

    do not determine

source continuity
or
source lifecycle count
```

Information equivalent to an explicit continuity / supersession correspondence is independently observable when a provider may replace keys across pending -> posted evolution.

This does not mean provider IDs are useless. They remain valuable source evidence and may be stable for some adapters. The result would only reject this stronger rule:

```text
provider key equality is the universal source-lifecycle identity law
```

## Neighboring boundaries

- Observation 121: source observation authority is distinct from household Actual authority; reconciliation is explicit evidence.
- Observation 123: pending / posted evolution can remain a source-evidence lifecycle while Actual stays stable.
- Observation 124: delivery attempt is distinct from source observation identity; content-only dedupe is insufficient.
- Observation 125: even source observation keys may be too fine-grained to serve as source lifecycle identity when keys change across lifecycle evolution.

The emerging chain is therefore:

```text
delivery attempt
    !=
source observation
    !=
source lifecycle continuity
    !=
household Actual
```

No generic relation framework is earned by this observation.

## Boundaries

Observation 125 does not establish:

- a production provider-key type;
- a production source-continuity or supersession relation;
- that provider keys always change across pending -> posted;
- a heuristic for inferring continuity when explicit source evidence is absent;
- fuzzy matching policy;
- source deletion / reversal semantics;
- cross-provider identity;
- concurrent ingest correctness;
- retention duration for source history;
- automatic reconciliation to Actual;
- a Practical Core, persistence, importer, or canonical household-data change.
