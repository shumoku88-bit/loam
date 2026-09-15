# Observation 255 — query granularity under sparse Effect identity

Status: **EXPERIMENT — Lean qualification pending**

Baseline:

```text
shumoku88-bit/loam
main: 9a34157c065a090518a7c58b63ddd99073bd43b4
Observation 254 / PR #928 merged
```

## Trigger

Observation 254 established a strict information ladder for one bounded history fixture:

```text
retained Event/effect history
        |
        v
Event-indexed quantity view
        |
        v
balance image
```

But Observation 166 had already answered an older identity question: `EventId` alone is not precise enough to name one Effect, `EffectKey` alone is not globally unique under the current law, and `(EventId, EffectKey)` is the existing minimum durable reference coordinate when one exact Effect must be named.

Observation 255 therefore does not repeat Observation 166. It asks a different question directly against current Core:

> Which query classes actually depend on optional `EffectKey`, and what physical information remains when Effect identity is deliberately absent?

## Proof instrument

The Lean observation defines a research-only erasure:

```text
eraseEffectIdentity : Effect -> Effect
```

which changes only:

```text
key := none
```

and an Event-level map that erases every optional Effect key while retaining the Event identity and every Effect list element.

This is not a migration or production transform. It is a semantic probe.

## O255-1 — anonymous does not mean aggregated away

Expected Lean facts:

```text
EventId preserved
Effect list length preserved
retained EffectKey list becomes empty
```

So an anonymous Effect remains a physical Effect in the Event representation. Sparse identity means "not durably addressable", not "not represented".

## O255-2 — physical quantity queries do not require EffectKey

Expected theorem:

```text
Event.quantityAt (eraseEventEffectIdentity event) locus measure
=
Event.quantityAt event locus measure
```

for every Event, Locus, and Measure.

If qualified, ordinary Event-level quantity projection belongs below the Effect-identity boundary.

## O255-3 — durable Effect reference queries do require EffectKey

The observation defines a research-only Event-scoped key lookup. Expected theorem:

```text
findInEventByKey? (eraseEventEffectIdentity event) key = none
```

for every Event and key, while a keyed singleton resolves before erasure.

This classifies durable reference lookup above the identity boundary without promoting `EffectKey` to a global identifier.

## O255-4 — identity can be earned without changing physical observation

Current Core already exposes:

```text
Effect.identify : Effect -> EffectKey -> Effect
```

The observation checks that identification changes addressability while preserving coordinate and exact quantity.

This gives the intended sparse-identity pattern:

```text
ordinary Effect
  coordinate + quantity are enough

later query needs durable reference
  -> attach EffectKey
  -> physical observation unchanged
```

## Query-class boundary

If the Lean obligations hold, the current Core supports this classification:

```text
Event-level quantity / balance-like query
    needs Event + physical Effect data
    does not need EffectKey

Event-local multiplicity query
    Effect list structure remains available
    does not by itself require EffectKey

Durable reference to one Effect
    needs EventId + EffectKey

"Which anonymous Effect is the same one later?"
    intentionally has no answer until identity is earned
```

The final line is not data loss relative to the model. It is the absence of an independently retained identity claim.

## Relationship to Observation 166

Observation 166 established the reference-coordinate boundary using Alloy pressure from burden/open-relation provenance.

Observation 255 tests the complementary erasure law in actual Lean Core:

```text
(EventId, EffectKey) is sufficient when exact reference is needed
```

does not imply:

```text
all Effects should always receive EffectKey
```

The current sparse design is useful precisely if lower-granularity queries are invariant under key erasure.

## Stop condition

Do not add global `EffectId`, mandatory keys, posting-line identity, or a production Register from this observation alone.

A later observation may ask whether a concrete history/register surface needs to expose keyed Effect references. Until then, current optional identity is the smaller model.
