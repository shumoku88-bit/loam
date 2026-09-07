# Observation 222 — Is BasisCut an independent primitive or overlap repair?

Status: **QUALIFIED CURRENT-OPERATING-MODE RESULT**

Research starting point: LOAM `260437ec3f3c374732bde4a609a21b9aefbdca1b`

## Pressure

Observation 220 showed that the current-quantity answer can factor through one finite origin snapshot. It deliberately left `BasisCut` unresolved because `BasisCut` represented a different practical problem: an observed starting quantity could already contain a real occurrence that was also retained as an Event, causing double counting.

The current HRA-backed household image no longer has a `basis-cut.tsv`. Historical repository evidence shows that this was not accidental:

- on 2026-09-02 loam-data added one PayPay cut row `basis-2 -> record-1`;
- on 2026-09-03 the historical-data move removed that cut, replaced the nonzero basis image with five zero bases, removed the then-current Event correction file, and imported the historical journal/Event world.

So the practical question is now:

> Is `BasisCut` a quantity primitive LOAM must retain, or is it only required when the selected origin state and selected Event history overlap?

## Existing production meaning

Application 011 defines one cut row as:

```text
basis correction root × Event correction root
```

meaning:

> this observed basis already reflects this remembered Event occurrence.

The production reader follows the Event root to its current correction terminal and excludes that occurrence from the post-basis Event contribution.

That was a valid and necessary repair for the old dogfood shape.

## Candidate invariant

The candidate is not "subtract cut quantities once".

It is a stronger selected-image invariant:

```text
origin snapshot
and
selected Event world
must not overlap in represented occurrence content
```

Equivalently:

> no selected Event occurrence is already reflected in the selected origin snapshot.

Under that invariant an ordinary current quantity is simply:

```text
origin quantity + correction-aware selected Event quantity
```

and no per-basis Event exclusion relation is needed.

There are at least two cut-free normal forms for one old overlapping image:

```text
A. later origin snapshot + only post-origin Events
B. earlier origin snapshot + full retained Events from that earlier origin
```

The current household reconstruction chose the second style and presently has exact zero origins.

## Lean probe

`222_basis_cut_overlap_normalization.lean` uses production `BasisCut` and production Event-correction quantity semantics.

Synthetic shape:

```text
observed basis = 100

pre-snapshot occurrence
  pre-v1 -> pre-v2
  effective quantity = -12

later occurrence = -7
```

The overlapping image without a cut produces `81` because `-12` is counted again.

The production root cut produces `93`.

Two cut-free non-overlap images also produce `93`:

```text
origin 100 + later-only Event -7
= 93

origin 112 + full effective Events (-12, -7)
= 93
```

So at one selected revision the cut can be replaced by a non-overlapping representation.

## Critical negative control: static absorption is not stable

Extend the old pre-snapshot occurrence:

```text
pre-v1 -> pre-v2 -> pre-v3
pre-v3 effective quantity = -9
```

The production root cut still returns `93`, because the observed basis `100` remains the current anchor and the entire corrected occurrence remains excluded.

But the one-time earlier origin `112` now gives:

```text
112 - 9 - 7 = 96
```

To preserve the old snapshot-anchor semantics it would have to be reconstructed as:

```text
109 - 9 - 7 = 93
```

Therefore:

```text
BasisCut
!=
one-time arithmetic folded into OriginSnapshot
```

The cut carries a real semantic choice about which evidence anchors current quantity when a pre-origin occurrence is corrected later.

## Executed result

The dedicated Observation 222 workflow compiled production `Loam.Application.BasisCut` and then checked every executable witness against the latest main-based branch head.

The selected matrix succeeded:

```text
overlap without cut                     -> 81
production root cut                     -> 93
later-origin + post-origin Events        -> 93
earlier-origin + full Events             -> 93
root cut after another Event correction  -> 93
static absorbed origin after correction  -> 96
reconstructed/rebased origin             -> 93
```

The negative-control inequality between static absorption and reconstructed origin was also accepted by Lean.

Workflow run `34121369198`, job `101739926267`, completed **SUCCESS**.

## Interpretation

`BasisCut` is best understood as **overlap evidence** between two quantity sources:

```text
observed state
and
retained change history
```

It is not required by quantity addition itself.

If LOAM wants to support this operating mode indefinitely:

```text
arbitrary observed snapshot
+ arbitrary retained pre-snapshot Event history
+ later correction on both sides
```

then BasisCut or a stronger temporal/reconciliation model remains genuinely useful.

If LOAM instead adopts the current reconstruction operating invariant:

```text
selected origin + selected Event world are non-overlapping
historical backfill crossing the origin triggers reconstruction/rebase
rather than coexistence
```

then the practical current-state path does not need BasisCut.

## Consequence for human-facing starting-quantity commands

This invariant changes what `starting-quantity` is allowed to mean.

A writer must not silently install a new snapshot over an Event world that already contains occurrences included in that snapshot. That recreates the exact overlap BasisCut was invented to repair.

A future OriginSnapshot cut should therefore choose one explicit policy, for example:

1. create/replace an origin only when the selected Event image is known to begin after it; or
2. perform an explicit atomic reconstruction/rebase of origin + selected Event image.

`correct-starting-quantity` can become atomic replacement of the current origin image only if this non-overlap invariant is preserved.

## Current household qualification pressure

The current loam-data image has:

- no `basis-cut.tsv`;
- no basis-correction file;
- five exact-zero basis coordinates;
- reconstructed historical Event evidence already carrying the prior opening quantities.

Observation 219 already established exact current-balance parity for those five coordinates with zero-origin coverage.

So no current household answer presently requires BasisCut.

## Finding

```text
BasisCut semantic pressure
    REAL

BasisCut as universal quantity primitive
    NOT EARNED

BasisCut needed when origin/Event representations overlap
    YES

BasisCut needed under explicit non-overlap reconstruction invariant
    NO, for the selected current-state model

one-time cut-to-origin arithmetic rewrite
    UNSAFE as a durable equivalence under later Event correction
```

The next production step should not merely delete `basis-cut.tsv` support. It should make the non-overlap invariant explicit at the OriginSnapshot writer boundary, then remove BasisCut from the practical current-state path only where that invariant is enforced.

## Non-goals

Observation 222 does not authorize:

- pretending the historical BasisCut pressure never existed;
- silently converting arbitrary post-event observations into pre-event origins;
- inferring chronological order from Event storage order or Git history;
- deleting Event correction semantics;
- turning HRA into permanent LOAM ontology;
- introducing Date/Time or Account into Core;
- production OriginSnapshot persistence yet.
