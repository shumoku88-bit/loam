# Experiment 249: Locus admission authority separation

Status: **research lab; no production topology migration authorized**

Tracking: #700 / draft PR #701

## Question

`LocusAdmissionVocabulary` is an independently earned current write policy, but it currently rides inside every selected Movement generation.

For the operations production actually exposes today, must policy and Movement evidence be atomically co-selected?

## Current operation boundary

The current `LocusAdmissionPublisher` is add-only. It can extend the approved set, but cannot revoke an existing Locus.

Therefore successive admitted policy states satisfy:

```text
old.approved ⊆ current.approved
```

The experiment asks what happens if an Effect-producing writer observes an older policy snapshot while a later add-only policy publication is already current.

## Expected result

For one Draft using a finite set of Loci:

```text
admitted(policy, draft)
  iff
all draft Loci are in policy.approved
```

Under add-only evolution:

```text
admitted(old, draft)
-> admitted(current, draft)
```

So a stale older policy may produce a **false rejection** after a new Locus has been admitted, but it cannot produce **false authorization** relative to the newer policy.

That weakens the case for atomic co-selection of Movement evidence and Locus policy for the current operation set.

## Deliberate counterpressure

The model also permits a policy state where a previously approved Locus is removed. In that case an older snapshot can authorize a Draft that the current policy rejects.

Therefore the separation argument is conditional:

```text
current add-only policy operations
  -> stale-old reads are authorization-safe

future revocation / retirement semantics
  -> must re-qualify synchronization and authority rules
```

Observation 212 remains stronger than today's publisher: it established that historical readability and current write permission are independent, and did not permanently forbid future disallowance.

## Production implication if qualified

Do not immediately create a standalone file.

First restore complete writer coverage for Observation 212. Then introduce a local Locus policy authority boundary that hides whether policy is currently sourced from the Movement manifest or a standalone atomic image.

Only after callers stop depending on `world.locusAdmission` should physical separation be attempted.

The existing `LocusAdmissionPersistence` already provides versioned encoding and atomic sibling-stage replacement, so the remaining question is authority selection and migration, not codec invention.
