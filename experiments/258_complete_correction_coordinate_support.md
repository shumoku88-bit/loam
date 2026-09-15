# Observation 258 — complete finite support for correction quantity change

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
main: 08dcf091f54e16acdc4d283563574cc09dd29152
Observation 257 / PR #932 merged
```

Qualification:

```text
Selected Lean Observations
run:    34994397382
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    34994397482
result: SUCCESS

Purpose Catalog Boundary
run:    34994397687
result: SUCCESS
```

## Trigger

Observation 257 proved that a queried correction change can be explained without cross-Event Effect lineage:

```text
before = original.quantityAt coordinate
after  = replacement.quantityAt coordinate
delta  = after - before
```

Observation 258 asks whether all nonzero physical correction changes can be found from a finite set already present in the original and replacement Events.

## Candidate support

For each Event:

```text
eventCoordinates event = event.effects.map Effect.coordinate
```

The correction candidate support is the deduplicated union:

```text
candidateCoordinates original replacement
  = eraseDups (eventCoordinates original ++ eventCoordinates replacement)
```

No Effect is merged by this projection. Deduplication applies only to the read-side coordinate list.

Lean also qualifies the exact membership law:

```text
coordinate ∈ candidateCoordinates original replacement
<->
coordinate ∈ eventCoordinates original
∨ coordinate ∈ eventCoordinates replacement
```

## O258-1 — coordinates absent from both Events have zero delta

Qualified theorem:

```text
coordinate ∉ candidateCoordinates original replacement
->
quantityDeltaQuantaAt original replacement coordinate = 0
```

The proof first establishes that an Event projects exact zero at a coordinate absent from all of its Effects.

Therefore there are no hidden nonzero quantity changes outside the finite union of original and replacement coordinates.

## O258-2 — every nonzero delta lies in finite candidate support

Lean qualifies the completeness law:

```text
delta coordinate ≠ 0
->
coordinate ∈ candidateCoordinates original replacement
```

Every observable nonzero correction quantity change must therefore occur at a coordinate represented by the original Event or the replacement Event.

## O258-3 — exact changed-coordinate list

Define:

```text
changedCoordinates original replacement
  = candidateCoordinates
      |> filter (delta != 0)
```

Lean qualifies the exact law:

```text
coordinate ∈ changedCoordinates original replacement
<->
quantityDeltaQuantaAt original replacement coordinate ≠ 0
```

So `changedCoordinates` is not merely a safe over-approximation. It is the exact finite support of observable `LocusId × MeasureId` quantity change.

A complete display diff is derived by mapping Observation 257's `deltaAt` over this finite list. No new retained truth is introduced.

## Concrete witness

The selected fixture exercises changed, removed, and added coordinates:

```text
Original
  cash    JPY  -1000
  food    JPY  +1000
  paypay  JPY    -50

Replacement
  cash    JPY   -800
  food    JPY   +800
  books   JPY   +200
```

Lean qualifies:

```text
cash    ∈ changedCoordinates
paypay  ∈ changedCoordinates
books   ∈ changedCoordinates
unseen  ∉ changedCoordinates
```

The proof does not pair any original Effect with any replacement Effect.

## Qualified boundary

Observation 258 establishes:

```text
complete observable quantity diff
    derived from original + replacement Event evidence
    finite
    exact for LocusId × MeasureId quantity change
    no retained diff authority required
    no Effect lineage required
```

Combined with Observations 256–257:

```text
which exact Effect became which exact Effect?
    not currently retained

what physical quantities changed?
    completely derivable
```

The projection remains intentionally lossy. It does not recover:

- which exact Effect became which exact Effect;
- within-coordinate Effect rearrangements whose aggregate delta is zero;
- causal explanation;
- capture/posting chronology;
- accounting interpretation beyond the retained coordinate.

Equal or zero coordinate deltas therefore must not be promoted into lineage claims.

## Stop condition

Do not add a persistent correction-diff table or cross-Event Effect correspondence merely to enumerate physical quantity changes. A new retained relation is earned only if a future concrete query requires information that cannot be reconstructed from retained original/replacement Events.
