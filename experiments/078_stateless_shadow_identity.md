# Observation 078 — Can run-local identity support stateless real-data shadow observation?

## Question

Observation 075 established that imported identity is retained continuity information and must not be recomputed from mutable content or presentation position.

Observation 076 then set the anti-sidecar direction:

```text
prefer no sidecar
```

Observation 077 showed that ambiguous reconciliation can remain one-shot rather than becoming a durable mapping.

A private whole-file readiness pass over the current canonical household journal now adds a new practical pressure:

- Event-level identity markers exist only partially;
- Effect-level stable identity markers are absent;
- the source contains ordinary multi-effect Events and opaque metadata;
- therefore a lossless Practical Core admission that claims imported stable identity is not currently available for the whole source.

No private dates, descriptions, accounts, quantities, or metadata values are copied into this repository or CI.

The next question is deliberately narrower than import:

> For a read-only query whose answer is invariant under identity renaming, may one run assign fresh run-local EventId / EffectKey values, discard them immediately afterward, and still obtain a legitimate stateless shadow observation?

## Why this is different from invented imported identity

The prohibited shape remains:

```text
mutable source facts
    -> derive identifier
    -> retain identifier as source continuity
```

Observation 078 instead studies:

```text
one read-only run
    -> assign fresh unique local names
    -> evaluate an identity-insensitive query
    -> discard all local names
```

The local names make the current in-memory Practical Core structures admissible. They do not claim historical continuity and do not survive the run.

## Candidate query

The first candidate is exact quantity projection:

- `Event.quantityAt`
- `EventMemory.quantityAtRecorded`

Both functions aggregate locus / measure / quantity observations. Their definitions do not use the spelling of `EventId` or `EffectKey` to compute the quantity answer.

Observation 078 records this as Lean proofs rather than relying on inspection alone.

## Positive boundary

The Lean experiment checks that:

1. replacing only an EventId cannot change `Event.quantityAt`;
2. replacing EventId and EffectKey on one Effect cannot change the quantity answer;
3. distinct run-local EffectKeys on a multi-effect Event still preserve the quantity answer;
4. a singleton `EventMemory.quantityAtRecorded` answer remains unchanged under fresh Event / Effect identities.

The intended interpretation is:

```text
identity-renaming-invariant query
+ fresh run-local unique identity
+ no persistence
+ no cross-run relation
=> stateless shadow observation may proceed
```

## Negative boundary

The experiment also proves that `EventMemory.findById?` observes identity.

Therefore the run-local allowance does **not** extend to:

- identity lookup across runs;
- correction attachment;
- reconciliation continuity;
- relation targets;
- persistence;
- claims that a later source occurrence is the same historical occurrence.

For those questions, Observation 075 still applies and stable retained continuity is required.

## Real-data dogfood status

This is the first whole-file readiness observation that directly uses the current private canonical journal as pressure, while keeping every private value outside the public repository and CI.

The stages are now:

```text
real-data structural pressure
    started

whole-file stateless shadow readiness
    started here

read-only quantity shadow projection
    next if the Lean boundary holds

persistent / continuity-sensitive shadow admission
    still blocked on stable identity or explicit reconciliation
```

This distinction allows real-data dogfooding to begin for questions that genuinely do not observe identity without weakening the identity laws earned by Observations 052 and 075–077.

## Practical Core impact

None.

- no Core type change;
- no Persistence change;
- no source mutation;
- no sidecar;
- no new imported identity scheme;
- no private values in public artifacts.

The experiment is a proof about which existing Core queries are safe to use in a stateless shadow run.

## Next pressure

If the Lean proof remains green, the next practical step is small and concrete:

> add a read-only private `shadow-quantity` entrance that parses one journal snapshot, assigns fresh run-local identities, evaluates only rename-invariant recorded quantity projections, emits no persistence, and discards every generated identity when the process exits.

That would be the first operational real-data shadow dogfood while preserving the no-sidecar direction.
