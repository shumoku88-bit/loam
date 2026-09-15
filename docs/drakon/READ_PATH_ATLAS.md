# LOAM Read Path Atlas

Status: visual audit experiment; not production authority and not a code-generation source.

The existing `loam-system-map.drn` has detailed write-path diagrams, while its
`07 Projections & Reports` page is intentionally still only a human-scale index.
This companion atlas gives read/projection paths the same visual inspection
pressure without enlarging the stable system map before the read-side visual
vocabulary has proved useful.

## Build

From the repository root:

```sh
python3 docs/drakon/build_read_map.py
```

This creates the ignored generated file:

```text
docs/drakon/loam-read-path-map.drn
```

Open it in DRAKON Editor.

The current atlas contains:

```text
LOAM Read Path Atlas
+-- 07.0 Read Path Comparison
+-- 07.7 Current Coverage
|   +-- 07.7.1 Current Coverage Read Boundary
|   +-- 07.7.2 Per-Purpose Coverage Projection
|   +-- 07.7.3 Scheduled Pressure Partition
|   +-- 07.7.4 Current Coverage Compatibility Entrances
|   `-- 07.7.5 Headroom Compatibility Composition
`-- 07.8 Cycle Budget
    +-- 07.8.1 Cycle Budget Read Boundary
    `-- 07.8.2 Cycle Funding Composition
```

## Inspect as text

The existing inspector accepts an explicit map path:

```sh
python3 docs/drakon/inspect_map.py \
  docs/drakon/loam-read-path-map.drn --all

python3 docs/drakon/inspect_map.py \
  docs/drakon/loam-read-path-map.drn \
  --diagram "07.7.1 Current Coverage Read Boundary" --geometry
```

Use the text form to compare icon semantics and source traceability. Use an
actual DRAKON Editor screenshot when spatial density, symmetry, branch length,
or an awkward route is itself the evidence.

## Current observed topology

`CurrentCoverageReview.loadSnapshotAt` now resolves and classifies current-open
Scheduled pressure once at the snapshot level. Query-global pressure frontiers
and actionable rows are projected once from that shared partition. Each Purpose
projection receives only its managed Commitment, then composes it with current
Capacity and correction-aware Actual Consumption.

The old per-Purpose Scheduled-frontier copies and their consistency repair are
gone. `CurrentCoverageView` also retains only Entitlement, Consumption, and
managed Commitment; Remaining and Headroom are derived when read.

One ordinary-routing raw-Scheduled compatibility entrance remains in
`CurrentCoverageInspection`. It is not used by production
`CurrentCoverageReview`, but it is still exercised by CurrentCoverage,
Counterpoint, and FourVoice regression stories. The parallel EffectiveRouting
raw-Scheduled shell had no current caller and has been retired; production
EffectiveRouting composition uses the narrower already-qualified
`...EffectiveRoutingWithCommitment?` boundary.

The legacy all-current Headroom composition remains separate because it asks a
different coordinate question from windowed Current Coverage. Its result now
retains independent components and derives commitment/headroom aliases instead
of storing contradictory copies.

Cycle Budget keeps window, CurrentCoverage, physical display balances, funding
selection, and funding summary as independently visible read results. Physical
balance display and funding share one loaded Balance evidence image, while
CurrentCoverage deliberately keeps its existing production reader; the composed
snapshot does not promise a cross-file atomic read.

`CycleFundingInspection.Summary` now retains only the two independent funding
quantities: budgetable backing and remaining assigned. JPY is fixed by admission,
`residualBeforeUnresolved` is derived from those retained quantities, and the
three query-global future-pressure values remain owned by the sibling
CurrentCoverage Scheduled frontier rather than being copied into the funding
summary. `07.8.2` therefore shows one retained funding pair plus derived/contextual
reads instead of parallel stored echoes.

These are observations of the current read topology, not instructions to keep
compressing it. A remaining compatibility or projection boundary is not a
problem merely because it is visible in the atlas.
