# Observation 232 — Can repeated Core memories share one finite keyed-memory mechanic?

Status: **QUALIFIED MECHANICAL ISOMORPHISM — shared mechanics yes; generic household Memory ontology not earned**

Research baseline: LOAM `bc95e328f9125afda4bf85cc3d209deeb31414cb`

Qualified Lean head: `44928140831b1cf2cabdf2060df9a69c1e3aa06e`

Dedicated workflow: Observation 232 run `34213654203`, job `102020220536`, **SUCCESS**.

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

The dedicated Lean workflow mechanically checked:

```text
domain -> keyed -> domain = identity
keyed -> domain -> keyed = identity

domain admission isSome
  =
generic keyed admission isSome

one generic permutation-invariant lookup theorem
  instantiates for all four families
```

All selected checks compile on the exact qualified head.

This establishes representation/mechanical isomorphism for the selected boundary. It does not erase semantic authority.

## Why not replace every memory with an abbrev?

The current public structures carry useful domain vocabulary:

```text
EventMemory.events
ScheduledMemory.occurrences
CapacityMemory.movements
AttentionMemory.items
```

Persistence, readers, tests, and human code already speak those names. Replacing the public types with one generic field such as `entries` would trade duplicated mechanics for adapters and migration noise.

The successful isomorphism proof therefore does **not** qualify a generic canonical `Memory` type.

The preferred production candidate is smaller:

```text
FiniteKeyed.findBy?
FiniteKeyed.findBy?_perm
```

with existing semantic memory structures retained unchanged.

This is especially attractive because current production contains large near-copy permutation proofs in both `EventMemory` and `ActualValidityMemory`, with another near-copy in `CapacityEffectiveMemory`, in addition to many repeated private recursive lookup functions.

## Promotion gate

A production extraction still has to show:

```text
net negative source
+ no persistence format change
+ no semantic API collapse
+ duplicate-key fail-closed parity
+ practical CI parity
```

The mechanical qualification now permits a production-shaped extraction to test that gate. It does not pre-authorize the extraction if the source delta loses.

## Follow-on candidate

After measuring the one-key lookup extraction, audit the separate two-endpoint uniqueness family:

```text
ActualReversalMemory
ScheduledCompletionMemory
ScheduledReplacementMemory
```

That is likely a finite partial-bijection storage mechanic, but it remains a separate question.

## Non-claims

Observation 232 does not authorize:

- one universal household `Memory` ontology;
- merging Actual, Scheduled, Capacity, or Attention semantics;
- changing persistence syntax;
- introducing temporal meaning from list order;
- replacing family-specific admission laws beyond the selected key uniqueness mechanic;
- combining one-key and two-endpoint relation stores into one framework before measurement;
- moving the experiment-local generic container into production merely because it is isomorphic.

## Result

Observation 232 qualifies the small statement:

```text
four independent semantic memories
+ same finite keyed representation law
+ same duplicate-key admission predicate
+ one shared permutation-invariant lookup theorem
```

The right next move is **not** to merge the semantic memories. It is to measure a smaller production helper that extracts keyed lookup/proof mechanics while leaving domain types and persistence intact.
