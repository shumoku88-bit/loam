# EffectKey persistence pressure

This read-only follow-up asks a narrower question than SA-010.

SA-010 already earned `EffectKey` as semantic nested identity because later relation provenance can distinguish one Effect from another inside the same Event. This experiment does **not** ask to delete that distinction.

Question:

> Must every Effect persist a stable key before any independent Effect-level reference exists, or can stable identity be sparse?

## Fixed semantic boundary

`EffectKey` itself remains **KEEP**.

LOAM allows more than one Effect inside one Event, including coordinate-equal Effects. Event list position is deliberately non-semantic. A later `RelationUnit` can therefore require the already-earned exact source coordinate:

```text
(EventId, EffectKey)
```

Replacing that coordinate with Event identity alone loses source precision. Replacing it with list position silently turns representation order into meaning.

The candidate under test is narrower:

```text
Effect-level identity: KEEP
identity on every ordinary Effect at creation: QUESTIONED
```

## Current production capability

The production relation writer is currently part of new Movement admission. The user selects one already-collected draft Effect, and the new Event plus any new RelationUnit evidence are admitted and published as one Movement world.

There is currently no separate production writer that attaches a new RelationUnit to an arbitrary historical Effect later.

Correction and Reversal also fail closed when the selected target Event already participates in retained relation/discharge evidence. Therefore current production does not need to migrate relation provenance across corrected or reversed Effect sets.

Production Actual review/search does not expose EffectKey as a household-facing field; it renders Event identity, date, description, locus, measure, and quantity. Scripted relation entry does currently accept an EffectKey, which is an entrance/API detail that a sparse design would need to replace with a draft-local selector before durable identity allocation.

## HRA-N is not the candidate

HRA-N currently synthesizes flow keys from flow order while reading a transaction and retains relation provenance at transaction scope rather than LOAM's exact Effect scope.

LOAM must not copy that positional identity scheme. Its Event semantics explicitly permit representation permutation, so `first Effect`, `second Effect`, and generated `f1/f2` positions are not stable semantic coordinates.

## Real-data pressure

Measured at `loam-data` checkpoint:

```text
169450fc1b85fe998070b91da16af1e4dccd25ca
```

Current selected Event authority contains:

```text
Events                       593
Effects                    1,241
retained RelationUnit rows     0
EffectKey token bytes       6,457
EffectKey token+tab bytes   7,698
average key token length    5.203
```

Against the preceding compact-Actual experiment:

```text
compact Actual with eager keys     65,466 bytes
hypothetical all-keyless lower bound 57,768 bytes
wire pressure                       7,698 bytes
share of compact Actual             11.76%
```

This is a pressure measurement, **not** an earned production saving. A real sparse representation must retain stable keys for every Effect that becomes independently referable.

## Alloy observation

`experiments/effect_key_sparse_identity.als` checks a bounded sparse-identity candidate without weakening Event payload semantics.

Qualified observations:

1. unreferenced Effects can exist without stable keys;
2. the semantic transition that first retains an Effect-level relation can introduce a stable key on only that source Effect while leaving physical Event/Effect payload unchanged;
3. duplicate-payload Effects do not force eager identity before one becomes independently referable;
4. positional identity changes its target under a permitted representation permutation;
5. scoped sparse keys preserve the minimum lookup law: `(Event, Key)` identifies at most one Effect.

All expected SAT/UNSAT receipts passed under Alloy 6.2.0 at commit:

```text
08ff4cb33a1bad009f0d7d3ece0f58a0ef1aa3e0
```

## Verdict

The current evidence supports this split:

```text
Effect-level identity semantics        KEEP
(EventId, EffectKey) relation anchor   KEEP
EffectKey global uniqueness            REJECT
position-derived identity              REJECT
stable key on every Effect eagerly     NOT YET JUSTIFIED
sparse stable key for referred Effects VIABLE CANDIDATE
```

The next implementation experiment should not modify production Core immediately. First prototype a compact Actual wire in which ordinary Effect rows are keyless while explicitly keyed Effect rows remain available for RelationUnit sources. Re-expand that wire into today's keyed in-memory model using deterministic **non-authoritative** temporary keys only at the compatibility boundary, and compare household observations plus a synthetic relation-bearing fixture.

That prototype must demonstrate that temporary compatibility keys never become persisted relation identity and that a relation-bearing source retains the same stable key across compact round trips.
