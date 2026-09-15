# Observation 261 — arbitrary finite correction-diff composition

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
main: aa0f2a441899ff0eac9b0cf3f6bd899a36b3cff1
Observation 260 / PR #935 merged
open PR: 0
```

Qualification:

```text
Selected Lean Observations
run:    34998238875
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    34998238887
result: SUCCESS

Purpose Catalog Boundary
run:    34998238873
result: SUCCESS
```

## Trigger

Observation 260 qualified exact two-step composition:

```text
A -> B -> C

delta(A,C) = delta(A,B) + delta(B,C)
```

and showed that the union of step supports, filtered by nonzero summed delta, is exactly the direct endpoint changed support.

Observation 261 asks whether that local law closes under arbitrary finite repetition.

## Minimal chain representation

Research-only:

```text
first Event + List successive Events
```

The empty list is a zero-step chain. A nonempty list represents a selected finite sequence of adjacent comparisons.

This is intentionally **not** a new retained correction-chain authority. O261 studies the algebra of a selected Event sequence only.

## Qualified obligation DAG

```text
O260 two-step telescoping
        |
        v
finite recursive step-delta sum
        |
        v
chain sum = direct first-to-endpoint delta
        |
        v
finite union of every adjacent changed support
        |
        v
endpoint nonzero change must occur in some step
        |
        v
filter union by nonzero total chain delta
        |
        v
exact direct endpoint changed support
```

## O261-1 — arbitrary finite telescoping

Define recursively:

```text
chainDeltaSum first [] = 0

chainDeltaSum first (next :: rest)
  = delta(first,next)
  + chainDeltaSum next rest
```

Lean qualifies, for every finite selected sequence and every coordinate:

```text
chainDeltaSum first rest coordinate
  = delta(first, chainLast first rest)
```

The zero-step case is included and yields exact zero endpoint delta.

The proof uses O260 as the induction step rather than introducing a new algebra.

## O261-2 — arbitrary finite step support

Define recursively:

```text
chainStepChangedCoordinates first [] = []

chainStepChangedCoordinates first (next :: rest)
  = eraseDups (
      changedCoordinates first next
      ++ chainStepChangedCoordinates next rest)
```

Lean qualifies:

```text
endpoint delta != 0
->
coordinate appears in chainStepChangedCoordinates
```

Therefore a nonzero endpoint change cannot arise outside the finite union of adjacent step diffs.

## O261-3 — exact composed chain support

Define:

```text
chainComposedChangedCoordinates
  = chainStepChangedCoordinates
      |> filter (chainDeltaSum != 0)
```

Lean qualifies the exact support law:

```text
coordinate in chainComposedChangedCoordinates first rest
<->
coordinate in changedCoordinates first (chainLast first rest)
```

List order is deliberately outside the claim. Semantic membership is exact.

## Qualified three-step witness

Two coordinates are used across:

```text
E0 -> E1 -> E2 -> E3
```

### Pulse coordinate

```text
E0  absent
E1  +100
E2   +40
E3  absent
```

Step deltas:

```text
+100, -60, -40
sum = 0
```

Lean qualifies that the pulse coordinate appears in step history but disappears from the composed endpoint support.

### Net coordinate

```text
E0  +10
E1  +20
E2  +15
E3  +30
```

Step deltas:

```text
+10, -5, +15
sum = +20
```

Lean qualifies that the net coordinate survives both the composed support and the direct endpoint support.

## Qualified boundary

Observation 261 establishes:

```text
arbitrary finite endpoint quantity diff
    = fold of adjacent step quantity diffs
    + coordinate alignment
    + zero-sum cancellation
```

No persistent chain-diff state, cross-Event Effect lineage, global EffectId, or label-composition ontology is required merely to calculate the endpoint quantity diff of a selected finite sequence.

Combined with O260:

```text
local two-step composition law
    closes under arbitrary finite repetition
```

However, this does **not** establish that an arbitrary `List Event` is a valid retained correction chain. It proves only the algebra of a selected sequence.

A separate future observation may ask whether `EventCorrection` evidence itself determines a unique safe chain or frontier and what happens under branching, missing targets, or replacement cycles.

## Stop condition

Do not add a canonical chain-diff authority merely because multi-step reporting is useful. First derive it from retained Events and existing correction topology; retain new truth only if a concrete query cannot be reconstructed safely.
