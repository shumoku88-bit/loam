# Observation 259 — human-readable correction explanation

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
main: 32fa0ef60f6cb1de9e236ad3e3138bf3f3419a40
Observation 258 / PR #933 merged
```

Qualification:

```text
Selected Lean Observations
run:    34995683394
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    34995683363
result: SUCCESS

Purpose Catalog Boundary
run:    34995683539
result: SUCCESS
```

## Trigger

Observation 258 qualified an exact finite support of all nonzero observable correction quantity changes:

```text
coordinate ∈ changedCoordinates original replacement
<->
delta coordinate ≠ 0
```

That is enough for a complete machine diff. Observation 259 asks whether LOAM can lift that diff into familiar human-facing labels without retaining new correction truth.

## Important semantic guard

The tempting rule

```text
before = 0  -> added
after  = 0  -> removed
```

is not generally safe.

LOAM permits multiple Effects at the same `LocusId × MeasureId` coordinate. Those Effects may sum to exact zero while the coordinate is physically represented by the Event.

Therefore O259 derives labels from **coordinate presence in the Event's Effect list**, not from aggregate quantity being zero or nonzero.

For a coordinate already known to belong to O258 `changedCoordinates`:

```text
original absent, replacement present -> added
original present, replacement absent -> removed
original present, replacement present -> changed
```

Observation 258 excludes the fourth case, absent in both, for every nonzero delta.

## Qualified research projection

```text
CorrectionChangeKind
  = added | removed | changed

CorrectionExplanation
  = O257 CoordinateDelta
  + derived ChangeKind
```

`completeExplanation` maps this classifier over the exact finite O258 changed support.

Nothing is persisted.

## Exact classification laws

For every coordinate in `changedCoordinates`, Lean qualifies:

```text
kind = added
<->
coordinate absent from original
and present in replacement

kind = removed
<->
coordinate present in original
and absent from replacement

kind = changed
<->
coordinate present in both
```

These are exact read-side laws on the qualified changed support, not UI guesses.

## Selected fixture

```text
Original
  cash    JPY  -1000
  paypay  JPY    -50

Replacement
  cash    JPY   -800
  books   JPY   +200
```

Lean qualifies:

```text
cash    changed
paypay  removed
books   added
```

## Zero-aggregate counterexample

A second fixture deliberately keeps a coordinate physically present while making its original aggregate quantity zero:

```text
Original
  cancelling JPY +100
  cancelling JPY -100

Replacement
  cancelling JPY  +50
```

Lean qualifies:

```text
before quantity quanta = 0
delta = +50
coordinate present in both Events
safe label = changed
```

This falsifies quantity-zero as a reliable proxy for coordinate absence.

## Qualified boundary

Observation 259 establishes:

```text
complete human-readable correction explanation
    = exact O258 changed support
    + O257 before/after/delta
    + derived coordinate-presence label
```

No persistent explanation table, diff authority, Effect lineage, chronology field, or additional Core ontology is required.

The labels remain deliberately narrow. `changed` means the physical coordinate is represented in both Events and its aggregate quantity differs. It does not mean the same Effect survived, nor does it explain cause, intent, accounting role, or chronology.

Combined with Observations 257–259:

```text
which exact Effect became which exact Effect?
    not currently retained

what physical quantities changed?
    completely derivable

how should those changed coordinates be described to a human?
    added / removed / changed is safely derivable from coordinate presence
```

## Stop condition

Do not retain `added / removed / changed` as new canonical facts merely to render correction explanations. They are earned as read-side projections unless a future independent workflow needs to refer to a classification itself as durable evidence.
