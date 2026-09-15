# Observation 257 — correction coordinate delta without Effect lineage

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
main: 46860305a87272f29472a7b092475908bf21a6ea
Observation 256 / PR #931 merged
```

Qualification:

```text
Selected Lean Observations
run:    34992975937
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    34992975809
result: SUCCESS

Purpose Catalog Boundary
run:    34992975734
result: SUCCESS
```

## Trigger

Observation 256 qualified an important negative boundary:

```text
EventCorrection
+ Event-local EffectKey reuse
-/-> cross-Event Effect continuity
```

A replacement Event can preserve the same physical quantities and the same local key set while assigning those keys to different physical Effects. Therefore LOAM must not silently interpret EventCorrection as Effect lineage.

Observation 257 asks the weaker practical question:

> If a household record is corrected, can LOAM explain what observably changed without knowing which exact Effect became which exact Effect?

## Selected observer

For one physical coordinate `(LocusId, MeasureId)`:

```text
before = original.quantityAt coordinate
after  = replacement.quantityAt coordinate
delta  = after - before
```

This observer compares retained Event projections only. It does not pair Effects across Events.

## O257-1 — sparse Effect identity does not affect correction delta

Lean qualified:

```text
quantityDeltaQuanta
  (eraseEffectIdentity original)
  (eraseEffectIdentity replacement)
  locus measure
=
quantityDeltaQuanta original replacement locus measure
```

The complete research `CoordinateDelta` row `(coordinate, before, after, delta)` is also invariant under erasing every optional EffectKey from both Events.

Therefore ordinary physical correction explanation sits below the Effect identity boundary.

## O257-2 — lineage alternatives commute to the same physical delta

The concrete witness uses:

```text
Original
  cash  JPY  -1000  [leftKey]
  food  JPY  +1000  [rightKey]
```

Two candidate replacement worlds share the same replacement EventId, physical Effects, local key set, and EventCorrection edge.

Aligned:

```text
cash  JPY  -800  [leftKey]
food  JPY  +800  [rightKey]
```

Swapped:

```text
cash  JPY  -800  [rightKey]
food  JPY  +800  [leftKey]
```

Lean qualified all selected witnesses:

```text
same EventCorrection projects in both worlds
cash delta = +200 in both worlds
food delta = -200 in both worlds
```

So the selected physical explanation is identical:

```text
cash: -1000 -> -800   delta +200
food: +1000 -> +800   delta -200
```

although the replacement worlds disagree about which local EffectKey names which physical Effect.

## Qualified boundary

Observation 257 establishes the separation:

```text
"what observably changed?"
    coordinate before / after / delta
    no Effect lineage required

"which exact Effect became which exact Effect?"
    current evidence insufficient
    independent correspondence required if a real query earns it
```

The inability to answer cross-Event Effect identity therefore does not prevent LOAM from explaining ordinary correction changes at the physical quantity level.

## Deliberate information loss

Coordinate delta remains a projection. It can hide:

- Effect membership rearrangements that net to the same coordinate quantity;
- cross-Event Effect identity;
- causal interpretation of why a change occurred;
- capture / posting chronology;
- accounting classification beyond the retained coordinate.

Therefore equal deltas must not be used to reconstruct lineage.

## Stop condition

Do not add production cross-Event Effect correspondence merely to explain ordinary correction changes. The current evidence earns such a new retained relation only if a concrete household query genuinely needs exact Effect continuity rather than coordinate-level physical change.
