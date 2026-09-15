# Observation 260 — compositional correction quantity diffs

Status: **QUALIFIED by Lean 4.33.1**

Baseline:

```text
shumoku88-bit/loam
main: b6c19ce7750849a51bcb350aa3457018c630e6fb
Observation 259 / PR #934 merged
open PR: 0
```

Qualification:

```text
Selected Lean Observations
run:    34996972655
result: SUCCESS
Lean:   4.33.1

Compression Audit
run:    34996972485
result: SUCCESS

Purpose Catalog Boundary
run:    34996972446
result: SUCCESS
```

## Trigger

Observations 257–259 established one-step correction explanation:

```text
257  exact before / after / delta at one coordinate
258  exact finite support of all nonzero changed coordinates
259  safe added / removed / changed human labels
```

Observation 260 asks whether two successive quantity diffs compose:

```text
A -> B -> C
```

Can the endpoint quantity diff `A -> C` be reconstructed from the two step diffs without retaining a new chain-diff authority?

## Qualified obligation DAG

```text
pointwise delta composition
        |
        v
direct nonzero change occurs in at least one step support
        |
        v
union step supports + filter summed delta != 0
        |
        v
exact direct endpoint changed support
        |
        v
human labels remain endpoint-derived, not additive
```

## O260-1 — pointwise telescoping

Lean qualifies, for every `LocusId × MeasureId` coordinate:

```text
delta(A,C) = delta(A,B) + delta(B,C)
```

This is an exact integer quantity law. It requires no Effect pairing or cross-Event lineage.

The proof uses only core integer algebra; no Mathlib or extra tactic dependency is introduced.

## O260-2 — direct changes cannot appear from nowhere

Lean qualifies:

```text
delta(A,C) != 0
->
delta(A,B) != 0 or delta(B,C) != 0
```

Therefore every direct changed coordinate appears in at least one step `changedCoordinates` list.

## O260-3 — exact composed support

Define:

```text
stepChangedCoordinates
  = eraseDups (changedCoordinates A B ++ changedCoordinates B C)

composedChangedCoordinates
  = stepChangedCoordinates
      |> filter (delta(A,B) + delta(B,C) != 0)
```

Lean qualifies the exact semantic support law:

```text
coordinate in composedChangedCoordinates A B C
<->
coordinate in changedCoordinates A C
```

List order is intentionally not part of this claim. Membership is the semantic read-side support.

The raw union of step supports is only an over-approximation because intermediate changes can cancel. The nonzero-total filter removes exactly those cancelled coordinates.

## Qualified cancellation witness

Selected fixture:

```text
A
  coordinate absent

B
  coordinate +100

C
  coordinate absent
```

Lean qualifies:

```text
A -> B   delta +100   label added
B -> C   delta -100   label removed
A -> C   delta    0   no changed-coordinate row
```

The coordinate is present in both step changed supports, but absent from both the composed endpoint support and the direct O258 endpoint support.

This falsifies two overly strong ideas:

```text
changedCoordinates(A,C)
  = raw union of step changedCoordinates

human labels form a simple additive algebra
```

They do not. Quantity deltas compose algebraically; supports require zero-sum filtering; human labels are recomputed from endpoint presence.

## Qualified boundary

Observation 260 establishes:

```text
complete endpoint quantity diff
    derivable from complete step quantity diffs
    exact after coordinate alignment and zero-sum cancellation
    no retained chain-diff authority required
```

But:

```text
added / removed / changed
```

remain narrow endpoint descriptions. `added` followed by `removed` can compose to no final row at all.

Combined with Observations 257–260:

```text
one-step quantity delta
    exact and lineage-free

one-step changed support
    finite and complete

human one-step label
    safely derived from coordinate presence

multi-step endpoint quantity diff
    compositional by telescoping and cancellation
```

Nothing here reconstructs Effect lineage, cause, capture chronology, accounting interpretation, or user intent.

## Stop condition

Do not add persistent composed-diff state or a label-composition ontology merely to explain multi-step correction chains. Retain a new fact only if a future concrete query cannot be reconstructed from the step Events/diffs and endpoint evidence.
