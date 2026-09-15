# Observation 262 — authoritative correction-chain extraction

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
initial main: 30cf7b1b80d1d8aad3a95a60c2d167218048932c
Observation 261 / PR #936 merged
Evidence Atlas / PR #937 merged
parallel docs work remained semantically orthogonal
```

Qualification:

```text
Selected Lean Observations
run:    35001642531 (#1102)
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    35001642647 (#879)
result: SUCCESS

Purpose Catalog Boundary
run:    35001642555 (#300)
result: SUCCESS
```

## Trigger

Observation 261 qualified exact arbitrary finite diff composition for a selected Event sequence:

```text
E0 -> E1 -> ... -> En
```

But O261 deliberately did not claim that an arbitrary `List Event` is authoritative correction history.

Production already contains the missing topology authority:

```text
EventCorrectionMemory
        |
        v
CorrectionFrontier.correctionFrontierAdmissible
        |
        +-- referenced endpoints must exist
        +-- one target has at most one replacement
        +-- one replacement has at most one target
        +-- cycles are refused
        |
        v
disjoint finite correction paths
```

Observation 262 asks whether that retained production evidence can safely supply the Event sequence expected by O261 without adding a second chain authority.

## Qualified obligation DAG

```text
production correction-frontier admission
        |
        v
follow only explicit retained target -> replacement edges
        |
        v
finite fail-closed Event-id chain
        |
        v
materialize remembered Events
        |
        v
O261 arbitrary finite diff fold
        |
        v
exact endpoint quantity diff
```

Negative branch:

```text
branching / merging / missing endpoint / cycle
        |
        v
production admission = false
        |
        v
no chain exposed
```

## Observation-local read adapter

The research adapter introduces no retained type.

```text
successorId?
walkIds?
correctionChainIdsFrom?
materializeEventIds?
correctionEventChainFrom?
```

`correctionChainIdsFrom?` first requires production `correctionFrontierAdmissible = true`, then verifies the requested start Event is remembered, and only then follows explicit retained correction edges.

Traversal is bounded by:

```text
correction count + 1
```

Fuel exhaustion returns `none`; it never invents a terminal.

## Qualified justification law

Lean proves:

```text
successorId? corrections id = some successor
->
exists retained correction,
  correction.target = id
  and correction.replacement = successor
```

So every adjacency chosen by the reader originates in retained evidence rather than Event order, EventId spelling, dates, or Git history.

## Qualified production topology matrix

Selected four-Event world:

```text
A  10
B  20
C  15
D  30
```

Lean qualifies production admission as:

```text
A -> B -> C -> D        true

A -> B
A -> C                  false   branching

A -> C
B -> C                  false   multi-parent merge

A -> B
B -> A                  false   cycle

A -> missing            false   missing endpoint
```

The observation-local reader returns `none` for every rejected shape.

## Qualified positive connection witness

For the admitted linear path:

```text
A -> B -> C -> D
```

Lean qualifies the derived chain:

```text
[A, B, C, D]
```

Existing production `correctionRootTerminalEvents?` reports:

```text
A -> D
```

and the observation-local extracted chain terminates at the same `D`.

A selected permutation of the correction-memory representation also produces the same path. This is a witness of intended order independence, not a new generic permutation theorem.

## Qualified O261 bridge

The selected quantity coordinate uses:

```text
A = 10
B = 20
C = 15
D = 30
```

Adjacent deltas:

```text
+10, -5, +15
```

O261 over the production-derived path yields:

```text
+20
```

and the direct O258 endpoint delta `A -> D` is also `+20`.

The adapter performs no second diff arithmetic. The general theorem `chainDeltaQuantaAtFrom?_eq_endpoint_of_extracted` delegates every successfully extracted nonempty chain to O261's endpoint law.

## Qualified boundary

Observation 262 establishes the selected production connection:

```text
retained EventCorrection topology
        + production fail-closed admission
        -> safe finite selected correction path
        -> O261 endpoint diff
```

without adding:

```text
persistent chain state
chain-diff authority
cross-Event Effect lineage
global EffectId
chronology field
winner-by-list-position rule
```

Production `CorrectionFrontier` remains the topology authority. The reader is research-only.

This does **not** yet prove generic permutation independence or generic completeness of the observation-local reader for every admitted path. Those are stronger reusable-reader properties and should be earned separately if production needs this adapter.

## Stop condition

Do not promote the observation-local chain reader into production merely because the selected bridge works. Promote only if a concrete product query needs explicit intermediate correction history rather than the existing root/terminal frontier projections; if promoted, first qualify generic order independence and completeness from production admission.
