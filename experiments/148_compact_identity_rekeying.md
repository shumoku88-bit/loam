# Observation 148 — Can migration-shaped Event / Effect identities be compactly re-keyed?

## Question

Observation 146 separated two very different claims:

```text
stable Event / Effect identity
    is structural

hpev-* / hpef-* token spelling
    is migration-issued representation
```

Observation 147 then removed the one historical identity family whose initial-node identity was not independently required: uncorrected ActualValidity roots now use the Event itself.

The remaining question is therefore not whether EventId or EffectKey can disappear. They cannot, under the already observed correction and provenance pressures.

The narrower question is:

> Can one complete canonical generation replace long migration-issued EventId and EffectKey spellings with compact opaque keys while preserving every retained distinction and translating every identity-bearing reference exactly once?

## Candidate

Representative spelling only:

```text
hpev-a18c...  -> e1
hpev-f09b...  -> e2

hpef-1a72...  -> f1
hpef-88c4...  -> f2
hpef-b911...  -> f3
```

The compact number is **not** chronology, list position, priority, account identity, or content hash. It is an opaque stable token assigned by the one-time re-key operation.

The mapping must not be derived from mutable Event content, date, Locus, Quantity, description text, or presentation position.

## Required preflight

A re-key candidate is admissible only when:

1. every canonical EventId has exactly one old -> new mapping;
2. every canonical EffectKey has exactly one old -> new mapping;
3. new EventIds are collision-free;
4. new EffectKeys are collision-free;
5. every retained Event reference resolves before the rewrite;
6. every retained Effect reference resolves before the rewrite;
7. every identity-bearing stream is translated by the same mapping;
8. the candidate is fully qualified before the EventMemory authority commit.

A missing mapping or collision is a refusal, not an invitation to invent another key during publication.

## Lean observation

`Loam/Observations/Observation148.lean` uses public synthetic data shaped like the historical migration generation.

It checks four groups of laws.

### 1. Mapping admission

- a complete injective Event/Effect mapping is accepted;
- two old Events mapping to one compact EventId are rejected;
- two old Effects mapping to one compact EffectKey are rejected;
- an incomplete Event map is rejected.

### 2. Physical payload preservation

Changing only EventId and EffectKey spelling preserves recorded exact quantity at the same Locus / Measure coordinates.

Translating an Effect endpoint also selects the same physical Effect payload:

```text
Locus + Measure + exact quanta
```

### 3. Cross-stream reference preservation

The same mapping translates:

- ActualValidity Event references;
- EventDescription Event references;
- EventCorrection target / replacement endpoints;
- representative Effect reference endpoints.

Correction projection succeeds both before and after the exact endpoint translation.

The observation simultaneously checks the negative boundary:

```text
compact EventMemory
+ old correction endpoints
=> unavailable
```

So this is not identity erasure and not a claim that callers may continue using old keys.

### 4. Physical cutover shape

The candidate specializes Observation 145's auxiliary-first destructive cutover shape.

Identity-bearing dependent evidence is published before EventMemory. ActualValidity is first and acts as the availability guard. EventMemory remains the authority commit point.

```text
old complete generation
    -> old-correct

auxiliary compact ids + old EventMemory
    -> fail closed

full compact auxiliaries + compact EventMemory
    -> compact-correct
```

No phase in the qualified sequence is classified as a mixed readable generation.

## Important boundary: semantic parity, not byte parity

A successful identity re-key intentionally changes canonical identity bytes.

Human review or readable-journal output may also include EventId spelling, so those artifacts are not required to be byte-identical if they expose identity.

The correct parity requirement is:

- quantities and balances identical;
- occurrence dates identical after EventId translation;
- descriptions identical after EventId translation;
- correction / relation topology identical after endpoint translation;
- Effect-selected payload identical after EffectKey translation;
- reference closure preserved;
- no old migration key remains in current canonical identity-bearing streams after cutover.

Any identity-visible derived output must compare equal after applying the exact old -> compact translation, not by pretending the identity did not change.

## Historical evidence is not rewritten

This observation does **not** authorize rewriting Git history or immutable historical-admission source evidence.

The old generation remains recoverable from Git history and the retained historical-admission evidence. A future canonical re-key should create a new generation and may record compact before/after hashes and counts, but it should not keep a second active authority mapping merely to preserve the old spelling in the current tree.

## Result sought

If the Lean qualification passes, the next step is a separate explicit canonical-data operation against `loam-data`:

1. audit all current EventId / EffectKey definitions and references;
2. generate a complete compact mapping from existing stable identities only;
3. construct the complete candidate in scratch;
4. compare semantic projections before/after;
5. verify no missing or colliding endpoint;
6. publish the candidate as one qualified generation;
7. update DD-003 only after the real canonical result is verified.

No canonical household data is changed by Observation 148 itself.
