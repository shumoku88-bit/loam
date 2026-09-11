# Experiment 245: Capacity publication topology

Status: **qualified research result; no production topology migration authorized**

Baseline: production PR #698 introduced one local `CapacityAuthority` handle while deliberately retaining the current two-file backing representation.

## Question

Hold the retained meanings fixed:

```text
CapacityMovement
CapacityEffective
```

and compare only publication topology for one new Capacity operation:

```text
A. current split backing
   effective image -> movement image

B. one typed atomic Capacity image
   { movements, effective }
```

This experiment does **not** ask whether `CapacityEffective` can be deleted. Observations 112 and 158 already earned effective-coordinate information independently.

## Why this is not Observation 055, 060, or 240 again

Observation 055 already established that semantic fact topology does not determine physical publication topology. Dependency ordering and fail-closed admission can preserve closure over split storage.

Observation 060 modeled a split protocol whose first step is deliberately idempotent, so the same request can be retried after restart.

Observation 240 states a representation-free evidence-before-activation candidate law and remains separately gated by the repository's replacement-dividend rule.

Capacity has a narrower production-specific pressure: its ordinary publisher refuses an incomplete Capacity image **before** it can replay or continue the interrupted operation.

## Current production contract

`CapacityAuthority.Image` exposes:

```text
movements : CapacityMemory
effective : CapacityEffectiveMemory String
```

The current publisher:

1. acquires Capacity writer ownership;
2. loads both families;
3. rejects bidirectionally incomplete evidence;
4. constructs one fresh movement/effective pair;
5. publishes effective evidence first;
6. publishes the activating movement image second.

If step 6 fails, effective evidence is durable but inert. A later ordinary `publish` sees incomplete evidence and refuses with `explicit recovery is required`.

The existing Capacity publisher regression deliberately seeds such an orphan effective entry and requires normal publication to fail closed. Experiment 245 therefore treats this behavior as a current contract, not an accidental bug.

## Temporal result: TLA+ / Apalache

`Observation245CapacityPublicationTopology.tla` models one fresh operation using:

```text
effectiveNew
movementNew
```

The dedicated CI pinned Apalache 0.62.2 and qualified all intended checks.

### Current split protocol

The model proved an inductive activation-safety invariant:

```text
movementNew => effectiveNew
```

So the current effective-before-movement ordering is genuinely useful: an activating movement cannot become visible without its effective evidence in the modeled protocol.

However, Apalache also found the required counterexamples:

- after effective publication, a crash can leave complete Capacity coverage unavailable;
- after restart, ordinary publication can reach `blocked` because it first observes incomplete evidence.

The availability-loss witness appears by model state 3; the blocked-restart witness by state 5.

Therefore the current split protocol is **activation-safe but not ordinary-retry recoverable**.

### Atomic-image candidate

For one typed image replaced atomically at the same abstraction level as today's individual staged-file rename, Apalache proved:

```text
effectiveNew = movementNew
```

as an inductive invariant.

It also found the required crash/restart/completion witness: a crash before atomic commit leaves the old complete image intact, ordinary restart can re-admit, and a later atomic commit can complete the operation. The completion witness appears by model state 4.

This does not model power-loss durability inside the filesystem's replacement primitive. It compares only the cross-file state introduced above that primitive.

## Static recovery result: Alloy

Temporal recovery raised a second question:

> Could LOAM simply reconstruct the missing movement from the orphan effective row?

`245_capacity_recovery_ambiguity.als` models the retained orphan observation and alternative possible completed worlds.

The orphan contains only:

```text
movement id
effective coordinate
```

while the missing `CapacityMovement` contains the actual balanced movement payload.

Alloy 6.2.0 produced the required SAT results for all three commands:

```text
ambiguousMissingMovement                       SAT
OrphanEffectiveDeterminesOneSafeDestination    SAT counterexample
SameOrphanImpliesSameCompletion                 SAT counterexample
```

A single orphan effective observation is therefore compatible with at least two different missing Capacity movements that would produce different completed household worlds.

Consequently:

```text
orphan effective evidence
    != enough information
       to reconstruct missing movement payload
```

Automatic **completion** recovery cannot be derived from retained orphan evidence alone.

## What about deleting the orphan effective row?

The model does not justify blind deletion either.

An effective-only row can be consistent with an interrupted publication, but raw bytes alone do not prove that origin. It could also reflect corruption, manual intervention, or another unmodeled failure. Deleting retained evidence merely because it is currently orphaned would introduce a new recovery policy that needs its own justification.

A split design that wants safe automatic recovery therefore needs additional evidence such as a staged request / transaction identity / recovery receipt, or an independently justified rollback rule.

That extra recovery state is itself semantic and operational surface area.

## Qualified conclusion

Experiment 245 establishes a Capacity-specific distinction not supplied by Observation 060:

```text
current split topology
  + evidence-before-activation
  = activation safety
  + reachable incomplete authority
  + ordinary retry refusal
  + missing payload not reconstructable from orphan evidence
```

At the same individual-file atomic-replacement abstraction level:

```text
one typed atomic image
  = paired completeness across modeled crash/restart
  + ordinary retry remains possible
```

This still does **not** prove that one physical file is globally superior.

It does mean the current split topology now owes an operational justification for the additional failure/recovery state it creates.

## Remaining operational counterweights

Before choosing a production topology, compare only properties not answered here:

- write amplification;
- corruption blast radius;
- human inspection / manual recovery;
- backup and restore granularity;
- power-loss durability assumptions below rename;
- whether a split-specific recovery journal would cost more complexity than an atomic image.

One observation already narrows the write-amplification question: today's Capacity publisher rewrites **both complete images** for every successful Capacity change. A single combined image would therefore not automatically turn one current append into a whole-image rewrite; the current design already performs two whole-image rewrites. The exact byte and failure costs still need measurement.

## Stop rule

This PR remains a research lab. Do not merge the TLA+, Alloy model, or dedicated workflow wholesale merely because they are green.

Next durable move should be one of:

1. measure the remaining operational counterweights and, if the split topology still fails to pay rent, prototype an atomic Capacity image behind the already-landed `CapacityAuthority`; or
2. if split storage has a measured advantage, explicitly design and qualify the additional recovery evidence it requires.

Do not grow a generic transaction/repository framework from this result.
