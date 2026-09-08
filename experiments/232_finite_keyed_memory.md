# Observation 232 — Can repeated Core memories share one finite keyed-memory mechanic?

Status: **PROBE — mechanical sharing under test; no semantic merge claimed**

Research baseline: LOAM `bc95e328f9125afda4bf85cc3d209deeb31414cb`

## Pressure

Observation 218 removed duplicated replacement-frontier algorithms without introducing a universal household Relation ontology. During that audit it also identified finite partial-map lookup/proof boilerplate across Core memories as a separate simplification candidate.

The current semantic census makes that pressure concrete.

At the research baseline:

```text
Loam/Core/*.lean          34 modules
Loam/Application/*.lean   18 modules
-------------------------------------
                         52 modules
```

At least ten Core structures independently contain the same one-key finite collection skeleton:

```text
List Item
+ keyOf : Item -> Key
+ Nodup (map keyOf items)
+ fail-closed admission
+ append preserving uniqueness
+ lookup by key
```

This observation starts with four uncomplicated representatives:

```text
EventMemory
ScheduledMemory
CapacityMemory
AttentionMemory
```

They belong to different semantic authorities. The question is therefore not whether Event, Scheduled, Capacity, and Attention mean the same thing. They do not.

The question is narrower:

> Is their retained finite-key machinery one reusable structure, and if so is the right production extraction a generic container or only shared low-level mechanics?

## Candidate structure

The Lean probe introduces an experiment-local:

```text
KeyedMemory Item Key keyOf
  entries
  keyNodup
```

with generic:

```text
ofEntries?
add?
findByKey?
findByKey?_perm
```

The important law is that lookup is invariant under permutation once selected keys are unique. This captures the existing LOAM rule that deterministic list representation is not temporal, causal, priority, lifecycle, or winner authority.

## Mechanical tests

For each of Event, Scheduled, Capacity, and Attention the probe defines bidirectional adapters between the existing domain memory and the generic keyed representation.

The selected checks are:

```text
domain -> keyed -> domain = identity
keyed -> domain -> keyed = identity

domain admission isSome
  =
generic keyed admission isSome

one generic permutation-invariant lookup theorem
  instantiates for all four families
```

A successful probe establishes representation/mechanical isomorphism for this boundary. It does not erase semantic authority.

## Why not immediately replace every memory with an abbrev?

The current public structures carry useful domain vocabulary:

```text
EventMemory.events
ScheduledMemory.occurrences
CapacityMemory.movements
AttentionMemory.items
```

Persistence, readers, tests, and human code already speak those names. Replacing the public types with one generic field such as `entries` could trade duplicated mechanics for adapter and migration noise.

Therefore this observation separates two outcomes:

### Outcome A — shared mechanics

Keep domain structures and persistence unchanged. Extract only generic keyed-list admission / append / lookup / permutation laws where source delta is genuinely negative.

### Outcome B — generic canonical container

Replace domain memory structures themselves with one generic type.

Outcome B requires much stronger evidence than representation isomorphism. It must reduce production source and preserve readable authority boundaries without wire churn.

## Promotion gate

The experiment is promoted only if a production-shaped extraction shows:

```text
net negative source
+ no persistence format change
+ no semantic API collapse
+ duplicate-key fail-closed parity
+ practical CI parity
```

If a generic container fails to pay rent, the result is still useful: extract the smaller lookup/proof machinery and retain domain wrappers.

## Follow-on candidate

If the one-key family qualifies, audit the separate two-endpoint uniqueness family:

```text
ActualReversalMemory
ScheduledCompletionMemory
ScheduledReplacementMemory
```

That is likely a finite partial-bijection storage mechanic, but it must not be folded into Observation 232 merely for symmetry.

## Non-claims

Observation 232 does not authorize:

- one universal household `Memory` ontology;
- merging Actual, Scheduled, Capacity, or Attention semantics;
- changing persistence syntax;
- introducing temporal meaning from list order;
- replacing family-specific admission laws beyond the selected key uniqueness mechanic;
- combining one-key and two-endpoint relation stores into one framework before measurement;
- moving proof-heavy research machinery into production by default.

## Current result

The Lean probe and production source delta are still under qualification on the Observation 232 branch.
