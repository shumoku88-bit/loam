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

The first atlas contains:

```text
LOAM Read Path Atlas
+-- 07.0 Read Path Comparison
`-- 07.7 Current Coverage
    +-- 07.7.1 Current Coverage Read Boundary
    +-- 07.7.2 Per-Purpose Coverage Projection
    `-- 07.7.3 Scheduled Pressure Partition
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

## Current audit question

`CurrentCoverageReview.loadSnapshotAt` derives actionable unresolved Scheduled
rows once at the snapshot level. It also maps every remembered Purpose through
`projectPurpose?`; that function returns both one Purpose-local row and a
`ScheduledFrontier`. The resulting frontier copies are checked by
`consistentFrontier`, then only the first copy is retained in the final
Snapshot.

The Application path underneath explains why this is worth drawing. For a fixed
Measure and horizon, Scheduled pressure selection and classification are shared.
Only managed Commitment asks whether a routed Purpose equals the queried
Purpose. The unmanaged, unrouted, and unresolved-eligibility totals are not
selected by queried Purpose.

The atlas records that topology as an observation only. It does **not** yet claim
that the implementation should be changed. The next step is to inspect the
actual DRAKON geometry and decide whether the local/global coupling is a useful
semantic boundary or accidental repeated projection work.
