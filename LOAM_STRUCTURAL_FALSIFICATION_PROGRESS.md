# LOAM Structural Falsification Progress

Status: **S003 and S008 completed; no structural READY item remains**

Review date: 2026-09-06
Structural corpus: `LOAM_STRUCTURAL_FALSIFICATION_ATLAS.md`

This file is the current Work / Finding authority for S001-S012.
The atlas owns specimen definitions and attack modes. Detailed evidence remains in the referenced Observation / Application / structural records.

The structural corpus is separate from the domain-facing F001-F200 corpus and does not alter its counts.

## Namespace authority

Structural specimen identity is the `S` identifier.

S003 was initially published in PR #441 using the label `Observation 200`, but domain falsification had already assigned Observation 200 to F055 and Observation 201 to F086. That duplicate numeric label is retired.

Current executable structural authorities include:

```text
S003
  Loam/Observations/StructuralS003.lean
  experiments/structural_s003_split_merge_invariance.md

S008
  Loam/Observations/StructuralS008.lean
  experiments/structural_s008_correction_chain_length.md
```

Future structural executable evidence should prefer its existing S identity instead of competing for the domain Observation number sequence unless one unified numbering authority is deliberately introduced later.

## State model

```text
Work
  REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | SURVIVED | COUNTEREXAMPLE | REDUNDANT
```

- `DONE / REDUNDANT`: equivalent structural pressure was already directly tested elsewhere.
- `DONE / SURVIVED`: a new explicit structural attack was run and the selected law survived its stated boundary.
- `DONE / COUNTEREXAMPLE`: the attacked structural claim failed.
- `READY / UNTESTED`: reviewed and selected for a small next structural probe.
- `REVIEWED / UNTESTED`: real unresolved pressure, but not selected into the near queue.

## Current checkpoint

```text
Corpus total                   12
Cross-reference reviewed       12

DONE / REDUNDANT                9
DONE / SURVIVED                 2
READY / UNTESTED                0
REVIEWED / UNTESTED             1
OBSERVING                       0
```

| ID | Work | Finding | Direct evidence / current interpretation |
|---|---|---|---|
| S001 | DONE | REDUNDANT | Observation 146 directly tests retained-identity deletion/compression: EventId and EffectKey remain earned, eager initial ActualValidityFactId does not. |
| S002 | DONE | REDUNDANT | Observations 052, 067, 146 show coordinate/value quotients cannot collapse Event/Effect identity when later provenance or Correction observes it. |
| S003 | DONE | SURVIVED | `StructuralS003` proves quantity-preserving one-to-two Effect decomposition is invisible to `Event.quantityAt`, while retained Effect representations remain distinct. |
| S004 | DONE | REDUNDANT | `Event.quantityAt_perm`, `EventMemory.findById?_perm`, row-order-independent persistence, and Observation 078 already qualify selected permutation / rename invariance. |
| S005 | DONE | REDUNDANT | Application 006 proves conservative fact extension and preservation of old projections that do not opt into the new family. |
| S006 | DONE | REDUNDANT | Observation 199 composes burden allocation + refund provenance + prior discharge and finds no fourth independent degree of freedom for the selected full-refund consequence. |
| S007 | REVIEWED | UNTESTED | Pairwise-safe / triple-unsafe pressure remains plausible, but no concrete current three-way seam earns the state-space cost yet. |
| S008 | DONE | SURVIVED | `CorrectionFrontier.correctionFrontierMemory?_mem_iff` makes successful frontier membership equal remembered-and-untargeted; `StructuralS008` derives terminal-only membership for an arbitrary finite selected admitted path witness. |
| S009 | DONE | REDUNDANT | Observations 004, 005, 029 establish vocabulary-relative observational equivalence and sufficiency; 079-084 re-exercise it at later evidence layers. |
| S010 | DONE | REDUNDANT | Observation 060 includes witness, inductive invariant and unsafe-order sensitivity; Observation 080 preserves bounded-vs-theorem epistemic strength. |
| S011 | DONE | REDUNDANT | Observations 192-193 bridge an abstract future-context law into existing Event/Correction/CorrectionFrontier production semantics. |
| S012 | DONE | REDUNDANT | Observations 059-060 plus practical PR #431 qualify relation-first activation / partial-publication recovery for representative cross-authority seams. |

## S003 qualification

`StructuralS003.quantityAt_split_merge` proves that one Effect carrying `left + right` and two distinct same-coordinate Effects carrying `left` and `right` produce the same `Event.quantityAt` answer for arbitrary exact signed quantities.

`StructuralS003.split_merge_representation_remains_distinct` simultaneously proves that the retained Effect representations remain different.

So S003 is query-induced invariance, not global Event equivalence.

## S008 qualification

Production `CorrectionFrontier` now exposes the proof-only law:

```text
successful frontier membership
  <->
remembered Event
AND
not targeted by any retained Correction
```

`StructuralS008.arbitrary_linear_chain_terminal_only` derives the selected path consequence without a fixed length bound:

```text
all selected nonterminal Events targeted
+ selected terminal Event untargeted
+ successful production frontier
  -> exactly terminal survives from the selected path
```

The observation deliberately does not create a second graph representation for list adjacency. Existing production admission remains authoritative for whether retained Corrections form disjoint finite paths. Once admission succeeds, frontier membership is target-driven and path length disappears.

A direct production witness also checks:

```text
A -> B -> C -> D -> E
```

and `quantityAtCorrectionFrontier?` returns only terminal Event E's quantity.

Dedicated Structural S008 Lean CI completed SUCCESS on exact executable branch head:

```text
11684a1c112b032f6df04542551f4ebfa79d7e62
```

workflow run `34008008290`.

No runtime semantics changed. The Application addition is theorem-only.

## Structural near queue

```text
READY      0
OBSERVING  0
```

S007 remains watchlist pressure only. Do not promote it merely because S008 is complete.

There is currently no selected next structural observation.

## Relation to the domain queue

Re-read `LOAM_FALSIFICATION_PROGRESS.md` and any newer selection checkpoint before choosing the next overall item.

At this structural checkpoint:

```text
Domain READY      0   (last verified domain progress checkpoint)
Structural READY  0
```

The correct next move is therefore not automatic queue replenishment. Choose a new observation only after a deliberate re-ranking or when practical work exposes a concrete seam.

## Boundary

This progress checkpoint introduces no production type, persistence format, CLI/TUI surface, canonical household data, generic quotient/equivalence framework, mutation-testing framework, graph framework, or multi-authority transaction mechanism.

Its job is only to keep current structural research state and evidence authority unambiguous.
