# Observation 077 — What is the smallest fail-closed reconciliation entrance without a permanent mapping store?

## Question

Observation 075 established that imported identity is retained continuity information rather than a hash of mutable source facts.

Observation 076 then established the project direction:

```text
prefer no sidecar
```

If an external identity aid is ever introduced, it must have an explicit retirement path and must not silently become a second permanent authority.

For the current real-data shadow direction, the canonical source remains authoritative and may not retain stable occurrence identity.

Observation 077 therefore asks:

> Can one ambiguous admission be resolved safely for the current operation without creating a persistent source-to-LOAM mapping?

## Practical boundary

The proposed entrance is deliberately one-shot:

```text
0 candidates
    -> reject

1 candidate
    -> current operation may proceed

2+ candidates
    -> reject automatic selection
    -> require explicit reconciliation
```

An explicit reconciliation chooses exactly one candidate from the candidates visible to that operation.

That choice is not retained as a source identity map.

Therefore another later ambiguous operation must stop again rather than pretending the earlier decision created durable continuity.

## Why this is not an importer yet

The entrance modeled here does not:

- scan private canonical values in public CI;
- create stable EventId or EffectKey values from source content;
- persist a source-to-LOAM mapping;
- modify the canonical source;
- decide a source format;
- decide a user interface;
- or move authority from the source to LOAM.

It only asks what a fail-closed current-cycle reconciliation law would need to look like.

## Bounded model

The model contains:

- one source occurrence under reconciliation;
- two possible current candidates;
- a current cycle and a later cycle;
- an optional explicit choice for each operation;
- an optional admitted candidate;
- an optional published LOAM identity.

There is intentionally no durable relation of the form:

```text
source occurrence -> LOAM identity
```

The absence of that relation is part of the experiment.

## Result

Alloy 6.2.0 + Sat4j produced:

```text
zeroCandidateReject                              SAT
uniqueCandidateAutomatic                         SAT
ambiguousWithoutChoiceReject                     SAT
ambiguousWithExplicitChoice                      SAT
reconciliationDoesNotBecomeFutureMapping         SAT

NoCandidateNeverAdmits                           UNSAT counterexample
AmbiguityWithoutChoiceNeverAdmits                UNSAT counterexample
ExplicitChoiceMustBeCandidate                    UNSAT counterexample
AdmissionAlwaysComesFromCandidateSet             UNSAT counterexample
ExplicitReconciliationSelectsExactlyItsChoice    UNSAT counterexample
```

The bounded result confirms all five intended entrance properties.

### No candidate

A source occurrence with no current candidate remains unresolved and publishes nothing.

### Unique candidate

If exactly one candidate is visible for the current operation, the entrance can proceed without an explicit choice.

This is only a current-operation uniqueness claim. It is not a proof of future source continuity.

### Ambiguous candidates

If two candidates remain possible and there is no explicit choice, the operation publishes nothing.

### Explicit reconciliation

If two candidates remain possible, an explicit choice may select exactly one of the currently visible candidates and allow that current operation to publish.

### No hidden permanent mapping

After a successful explicit reconciliation in the current cycle, a later ambiguous cycle with no explicit choice still rejects automatic admission.

The witness confirms:

```text
one reconciliation
    does not imply
future automatic reattachment
```

## Safety boundary

Within the bounded entrance:

```text
no candidate
    => no admission

multiple candidates + no explicit choice
    => no admission

explicit choice
    => choice belongs to current candidate set

admission
    => admitted occurrence belongs to current candidate set

explicit reconciliation
    => admitted occurrence is exactly the explicit choice
```

No counterexample was found for those assertions in the checked scope.

## Relationship to real-data dogfooding

This observation is directly preparing the first stronger form of real-data dogfooding, but it is not that dogfooding yet.

The project has already used the private canonical data as read-only pressure to discover structural gaps, especially imported identity pressure. However, LOAM is not yet continuously projecting the canonical household records into LOAM Events / Effects and using those projections as an operational shadow ledger.

A useful distinction is:

```text
real-data pressure observation
    already started

real-data operational shadow dogfood
    not started yet
```

Observation 077 makes the latter possible without first creating a permanent sidecar.

## Practical Core impact

None.

- no new Core type;
- no Persistence change;
- no CLI change;
- no sidecar;
- no source mutation;
- no private canonical values copied into the repository or CI.

## Next pressure

The next practical step should be very small:

> expose the current shadow audit so that a private real-data run can report unique / ambiguous / unresolved admission candidates without publishing or persisting them.

Only after that private read-only pass should LOAM consider a one-shot reconciliation entrance for actual canonical records.
