# Observation 260 — compositional correction quantity diffs

Status: **EXPERIMENT — Lean qualification pending**

Baseline:

```text
shumoku88-bit/loam
main: b6c19ce7750849a51bcb350aa3457018c630e6fb
Observation 259 / PR #934 merged
open PR: 0
```

## Trigger

Observations 257–259 established one-step correction explanation:

```text
257  exact before / after / delta at one coordinate
258  exact finite support of all nonzero changed coordinates
259  safe added / removed / changed human labels
```

The next question is whether two successive quantity diffs compose:

```text
A -> B -> C
```

Can the endpoint quantity diff `A -> C` be reconstructed from the two step diffs without retaining a new chain-diff authority?

## Obligation DAG

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

For every `LocusId × MeasureId` coordinate:

```text
delta(A,C) = delta(A,B) + delta(B,C)
```

This is an integer quantity law. It requires no Effect pairing or cross-Event lineage.

## O260-2 — direct changes cannot appear from nowhere

If:

```text
delta(A,C) != 0
```

then at least one of:

```text
delta(A,B) != 0
delta(B,C) != 0
```

must hold. Therefore every direct changed coordinate appears in at least one step `changedCoordinates` list.

## O260-3 — exact composed support

Define:

```text
stepChangedCoordinates
  = eraseDups (changedCoordinates A B ++ changedCoordinates B C)

composedChangedCoordinates
  = stepChangedCoordinates
      |> filter (delta(A,B) + delta(B,C) != 0)
```

Target law:

```text
coordinate in composedChangedCoordinates A B C
<->
coordinate in changedCoordinates A C
```

List order is intentionally not part of this claim. Membership is the semantic read-side support.

This matters because the raw union of step supports is only an over-approximation: intermediate changes can cancel.

## Cancellation witness

Selected fixture:

```text
A
  coordinate absent

B
  coordinate +100

C
  coordinate absent
```

Step interpretation:

```text
A -> B   delta +100   label added
B -> C   delta -100   label removed
```

Endpoint interpretation:

```text
A -> C   delta 0      no changed-coordinate row
```

This deliberately falsifies two overly strong ideas:

```text
changedCoordinates(A,C)
  = raw union of step changedCoordinates

human labels form a simple additive algebra
```

They do not. Quantity deltas compose algebraically; supports require zero-sum filtering; human labels are recomputed from endpoint presence.

## Intended boundary

If qualified:

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

remain narrow endpoint descriptions. For example, `added` followed by `removed` can compose to no final row at all.

Nothing here reconstructs Effect lineage, cause, capture chronology, accounting interpretation, or user intent.

## Stop condition

Do not add persistent composed-diff state or a label-composition ontology merely to explain multi-step correction chains. Retain a new fact only if a future concrete query cannot be reconstructed from the step Events/diffs and endpoint evidence.
