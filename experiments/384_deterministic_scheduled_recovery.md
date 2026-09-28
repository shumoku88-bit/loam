# Observation 384 — deterministic Scheduled relation-first recovery

Status: **EXECUTABLE PILOT — cross-authority recovery replay; no production architecture change**

Baseline:

```text
LOAM main 2bd45ff4065178a9df77c3fd3f6b2d5a29d135da
Observation 381 merged as #1450
Observation 382 merged as #1451
Observation 383 merged as #1452
shared deterministic support merged as #1453
```

## Question

Previous deterministic scenarios exercised one canonical Actual authority at a time.

Scheduled completion has a different recovery law because it spans two authorities in a fixed order:

```text
scheduled.loam
  retain Scheduled -> Actual completion claim
        ↓
actual.loam
  publish completion Event
```

If execution stops after the first write, the retained completion claim is intentionally inert until the referenced Actual Event exists.

The production contract says a later retry must reuse that retained endpoint, while cancellation must refuse to compete with the interrupted completion.

Observation 384 asks whether that cross-authority law survives a reproducible history containing a genuine interrupted state, an initially blocked retry, policy restoration, and eventual recovery.

## Instrument

The selected instrument is:

```text
Loam/Tests/DeterministicScheduledRecoveryScenario.lean
```

It reuses production:

```text
HouseholdCommand.completeScheduled
HouseholdCommand.cancelScheduled
ScheduledTerminalPublisher
ActualAuthority
LocusAdmissionAuthority
ScheduledReview
ScheduledLifecyclePersistence
DeterministicScenarioSupport for Actual canonical checks
```

No production module is modified.

## Why filesystem fault injection is not first

`ActualAuthorityCrashTest` already qualifies the single-file stage/rename boundary:

```text
partial stage write
complete stage before rename
atomic rename switch
malformed candidate refusal
retry after successful rename
```

Scheduled recovery exposes a distinct defect class: two valid authorities can temporarily disagree because the first half of a cross-authority protocol was retained and the second half was interrupted.

That is therefore the next useful deterministic target before adding lower-level filesystem fault seams.

## Initial world

Each replay begins with:

```text
Actual: empty
Locus policy: paypay / smbc / rent / food admitted
Scheduled:
  scheduled-1  paypay -> rent
  scheduled-2  paypay -> food
  scheduled-3  smbc   -> rent
```

## Trace

### 1. Fresh completion

`scheduled-1` completes through the ordinary household command.

The retained Scheduled terminal must point to a real Actual Event, and completion Effects must have canonical sparse identity rather than collector-local keys.

### 2. Independent cancellation

`scheduled-2` is cancelled.

This is Scheduled-only and must not modify `actual.loam`.

### 3. Controlled interruption

The test injects exactly the documented post-first-write state by retaining:

```text
scheduled-3 -> recovered-actual-3
```

in `scheduled.loam` while leaving `actual.loam` unchanged.

This is not a new production API. It is a test-only reconstruction of the state that would exist after process death between the two documented publication steps.

The referenced Actual Event must still be absent.

Scheduled review must treat the retained completion claim as inert because its Actual endpoint is absent, so `scheduled-3` remains current-open.

### 4. Cancellation conflict

Cancellation of `scheduled-3` must fail closed while the interrupted completion claim survives.

Both `actual.loam` and `scheduled.loam` must remain byte-for-byte unchanged.

### 5. Blocked recovery retry

The current Locus policy is temporarily closed.

A retry of completion must fail because the proposed Actual Event is no longer admissible for new publication.

The already-retained Scheduled completion claim must remain intact, and neither Actual nor Scheduled authority may change.

### 6. Recovery

The original Locus policy is restored and completion is retried through the ordinary production command.

The retry must:

```text
reuse recovered-actual-3
not allocate a new EventId
not append a second completion claim
not rewrite scheduled.loam
publish the missing Actual Event
```

### 7. Duplicate completion refusal

Once the Actual endpoint exists, another completion attempt must fail across both authorities without mutation.

## Canonical checks

After every meaningful transition the scenario validates:

```text
Actual:
  typed load
  encode -> decode -> encode
  disk bytes == canonical bytes

Scheduled:
  typed lifecycle load
  encode -> decode -> encode
  disk bytes == canonical bytes
```

Refused cross-authority actions additionally require:

```text
actual.loam before == actual.loam after
scheduled.loam before == scheduled.loam after
```

## Deterministic replay

The complete scenario runs in two isolated household roots.

Both executions must end with identical:

```text
scenario counters
actual.loam bytes
scheduled.loam bytes
locus-admission.loam bytes
```

## Expected counters

```text
fresh completion       1
cancellation           1
interrupted claim      1
policy-blocked retry   1
recovered completion   1
refusals               3
```

## Boundary significance

This is the first deterministic scenario where a valid intermediate world intentionally contains disagreement between two authorities.

The test therefore checks a property not covered by the previous Actual-only scenarios:

> retained recovery evidence may be temporarily incomplete across authorities, but it must stay deterministic, inert to ordinary reads, non-competing with cancellation, and recoverable to the exact retained endpoint.

## Stop / next gate

If this qualifies, deterministic production-history testing has covered:

```text
Movement/idempotency
Correction/Reversal
Settlement lifecycle
Scheduled cross-authority recovery
```

At that point the next research question should be fault injection only if a small seam can be introduced without production IO abstraction or simulator-framework growth.

Otherwise stop here and retain the four scenario families as the durable deterministic layer.
