# Sparse EffectKey projection

Checkpoint date: 2026-09-12

This experiment follows the EffectKey pressure audit. It does not delete Effect-level identity. It tests whether the canonical Actual representation can omit durable keys from ordinary Effects while retaining stable keys exactly where `RelationUnit` makes an Effect independently referable.

## Candidate wire

```text
TX <EventId> <ValidOn> ...
EFFECT <Locus> <Measure> <Quanta>
KEYED-EFFECT <EffectKey> <Locus> <Measure> <Quanta>
...
ENDTX
```

`KEYED-EFFECT` is used only for an Effect named by retained RelationUnit evidence. Ordinary `EFFECT` rows have no durable EffectKey.

For compatibility with today's keyed in-memory Core, re-expansion allocates deterministic `compat-effect-N` keys only for keyless rows. These keys are non-authoritative. A retained Relation source keeps its original stable EffectKey unchanged.

## Synthetic relation-bearing result

The fixture is created by the production Movement publisher:

```text
record-1
  effect-1  paypay  jpy  -1000
  effect-2  travel  jpy   1000
relation-1
  source = (record-1, effect-1)
  E2H friend 400
```

Sparse projection:

```text
KEYED-EFFECT effect-1 paypay jpy -1000
EFFECT travel jpy 1000
```

Result:

```text
current three-family payload  226 bytes
sparse Actual                 148 bytes
reduction                      78 bytes / 34.5%
```

After re-expansion:

- `(record-1, effect-1)` still resolves to `paypay/jpy/-1000`;
- relation quantity remains 400;
- unrelated travel Effect receives compatibility-local `compat-effect-1` only at the old-code boundary;
- Actual semantic observation is byte-identical.

The `Sparse EffectKey Projection` workflow completed SUCCESS at head:

```text
a1227e090d9b3285e027832fa7e08e612a4e24ef
```

## Current real household result

Data checkpoint:

```text
shumoku88-bit/loam-data
169450fc1b85fe998070b91da16af1e4dccd25ca
```

Current data contains:

```text
593 transactions
1,241 Effects
0 retained RelationUnit rows
```

Therefore all 1,241 current Effects project as ordinary keyless Effects.

Measured result:

```text
current Event + ActualValidity + EventDescription  74,301 bytes
compact Actual with eager EffectKey                 65,466 bytes
sparse EffectKey Actual                             57,774 bytes

reduction from current three-family payload         16,527 bytes / 22.2%
additional reduction after compact Actual            7,692 bytes
```

Read-only parity after sparse projection and re-expansion:

- Actual date / description / locus / measure / quantity: PASS
- retained Relation source Event / EffectKey / payload: PASS
- HOBS1 Balance / Budget / Capacity: PASS
- CycleBudgetReview Funding / CurrentCoverage / Scheduled pressure: PASS

The private-data workflow `Sparse EffectKey real-data experiment` completed SUCCESS.

## Combined active-state implication

The three-stream experiment measured the selected current semantic payload at 81,356 bytes. Replacing the 74,301-byte three-family Actual payload with the qualified 57,774-byte sparse representation gives an equivalent experimental selected payload of approximately:

```text
81,356 - 74,301 + 57,774 = 64,829 bytes
```

That is 16,527 bytes, about 20.3%, below the original selected active payload before any further semantic compression.

## Verdict

Under the current production capability:

```text
Effect-level identity semantics                KEEP
stable key for retained Relation source        KEEP
stable key on unrelated ordinary Effect        NOT REQUIRED by tested observations
position-derived durable identity              REJECT
compatibility-local transient key               ACCEPTABLE at old Core boundary, if non-authoritative
sparse canonical EffectKey representation       QUALIFIED EXPERIMENTALLY
```

This does not yet authorize a production migration. A production design must make it impossible for compatibility-local keys to become retained relation identity or other public durable evidence. The smallest likely migration is to change the eventual compact Actual persistence boundary, not to broaden Core with optional identity unless an independent need appears.
