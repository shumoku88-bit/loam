# EffectKey pressure qualification receipt

Checkpoint date: 2026-09-12

## Inputs

LOAM base experiment:

```text
experiment/compact-actual-projection
f038b3d7591c371c02efc9968589dc1c85f6bc73
```

Household data checkpoint:

```text
shumoku88-bit/loam-data
169450fc1b85fe998070b91da16af1e4dccd25ca
```

## Real-data census

```text
Events                         593
Effects                      1,241
RelationUnit rows                0
EffectKey token bytes         6,457
EffectKey wire bytes          7,698
compact Actual bytes         65,466
keyless lower-bound bytes    57,768
measured pressure             11.76%
```

The private-data read-only workflow `EffectKey real-data pressure` completed SUCCESS. The number is a lower-bound pressure measurement only; it does not authorize removing identity required by Effect-level overlays.

## Formal receipt

Alloy 6.2.0 observation `effect-key-sparse-identity` completed SUCCESS at:

```text
08ff4cb33a1bad009f0d7d3ece0f58a0ef1aa3e0
```

Expected receipts all matched:

```text
unreferencedEffectsCanRemainKeyless             SAT
relationCanIntroduceOneSparseKey                 SAT
duplicatePayloadCanGainSparseIdentity            SAT
positionalIdentityChangesUnderPermutation        SAT
EventAndSparseKeyIdentifyAtMostOneEffect         UNSAT counterexample
```

## Boundary verdict

```text
Effect-level identity semantics        KEEP
(EventId, EffectKey) relation anchor   KEEP
position-derived identity              REJECT
eager stable key on every Effect       NOT YET JUSTIFIED
sparse stable key on referred Effects  VIABLE CANDIDATE
```

No production code or canonical household data is changed by this receipt.
