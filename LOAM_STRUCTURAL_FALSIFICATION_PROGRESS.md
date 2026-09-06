# LOAM Structural Falsification Progress

Status: **S003 completed; S008 is the only structural READY item**

Review date: 2026-09-06
Structural corpus: `LOAM_STRUCTURAL_FALSIFICATION_ATLAS.md`

This file is the current Work / Finding authority for S001-S012.
The atlas owns specimen definitions and attack modes. Detailed evidence remains in the referenced Observation / Application / structural records.

The structural corpus is separate from the domain-facing F001-F200 corpus and does not alter its counts.

## Namespace authority

Structural specimen identity is the `S` identifier.

S003 was initially published in PR #441 using the label `Observation 200`, but domain falsification had already assigned Observation 200 to F055 and Observation 201 to F086. That duplicate numeric label is retired.

Current executable authority for S003 is:

```text
Loam/Observations/StructuralS003.lean
experiments/structural_s003_split_merge_invariance.md
.github/workflows/structural-s003-split-merge-invariance.yml
```

The domain Observation sequence remains untouched:

```text
Observation 200 = F055 shorter-month generation policy
Observation 201 = F086 external quantity assertion vs reconstructed history
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
DONE / SURVIVED                 1
READY / UNTESTED                1
REVIEWED / UNTESTED             1
OBSERVING                       0
```

| ID | Work | Finding | Direct evidence / current interpretation |
|---|---|---|---|
| S001 | DONE | REDUNDANT | Observation 146 directly tests retained-identity deletion/compression: EventId and EffectKey remain earned, eager initial ActualValidityFactId does not. |
| S002 | DONE | REDUNDANT | Observations 052, 067, 146 show coordinate/value quotients cannot collapse Event/Effect identity when later provenance or Correction observes it. |
| S003 | DONE | SURVIVED | `StructuralS003` proves quantity-preserving one-to-two Effect decomposition is invisible to `Event.quantityAt`, while the retained Effect representations remain distinct. |
| S004 | DONE | REDUNDANT | `Event.quantityAt_perm`, `EventMemory.findById?_perm`, row-order-independent persistence, and Observation 078 already qualify selected permutation / rename invariance. |
| S005 | DONE | REDUNDANT | Application 006 proves conservative fact extension and preservation of old projections that do not opt into the new family. |
| S006 | DONE | REDUNDANT | Observation 199 composes burden allocation + refund provenance + prior discharge and finds no fourth independent degree of freedom for the selected full-refund consequence. |
| S007 | REVIEWED | UNTESTED | Pairwise-safe / triple-unsafe pressure remains plausible, but no concrete current three-way seam earns the state-space cost yet. |
| S008 | READY | UNTESTED | Application 007 has short correction-chain specimens, but no general law yet says arbitrary admitted finite linear-chain length leaves exactly the terminal Event contributing. |
| S009 | DONE | REDUNDANT | Observations 004, 005, 029 establish vocabulary-relative observational equivalence and sufficiency; 079-084 re-exercise it at later evidence layers. |
| S010 | DONE | REDUNDANT | Observation 060 includes witness, inductive invariant and unsafe-order sensitivity; Observation 080 preserves bounded-vs-theorem epistemic strength. |
| S011 | DONE | REDUNDANT | Observations 192-193 bridge an abstract future-context law into existing Event/Correction/CorrectionFrontier production semantics. |
| S012 | DONE | REDUNDANT | Observations 059-060 plus practical PR #431 qualify relation-first activation / partial-publication recovery for representative cross-authority seams. |

## S003 qualification

The selected comparison is:

```text
World A
  one Effect at c carrying left + right

World B
  two distinct Effects at c carrying left and right

selected query
  Event.quantityAt c
```

`StructuralS003.quantityAt_split_merge` proves equality for arbitrary Event identity, Effect identities, Locus, Measure, and exact signed `Quantity` values.

`StructuralS003.split_merge_representation_remains_distinct` proves that the retained Effect lists are nevertheless different representations.

The qualified boundary is therefore:

```text
quantity-preserving Effect split / merge
  -> invisible to Event.quantityAt at the decomposed coordinate

but

Effect decomposition / identity
  -> remains retained and available to other questions
```

Dedicated renamed Structural S003 CI completed SUCCESS on the namespace-correction executable head in workflow run `34007264693`.

This is query-induced invariance, not global Event equivalence. Observation 120 remains explicit counterpressure because split / merged realization semantics can require independently observable apportionment.

No production change is earned.

## Structural near queue

```text
READY      1
OBSERVING  0
```

| Order | ID | Pressure |
|---:|---|---|
| 1 | S008 | arbitrary admitted finite Correction-chain length vs terminal-contribution law |

S007 remains watchlist pressure only.

For S008, start from the existing Correction frontier. Do not introduce a generic graph framework merely to state the question.

Candidate narrow law:

```text
for an admitted finite linear Correction chain,
exactly the terminal Event contributes to the selected correction-aware quantity
```

Sibling conflict, missing endpoints and cycles stay outside the admitted premise rather than acquiring winner semantics.

## Relation to the domain queue

Re-read `LOAM_FALSIFICATION_PROGRESS.md` before choosing the next overall item.

At this checkpoint the initial six-item domain near queue is exhausted:

```text
Domain READY      0
Structural READY  1  (S008)
```

Do not promote another F specimen merely to keep activity moving. The next honest choices are:

1. run S008 because it is already the one selected structural gap; or
2. deliberately re-rank the remaining domain `REVIEWED / UNTESTED` corpus as a whole.

Neither choice creates runtime/product work by itself.

## Boundary

This progress checkpoint introduces no production type, persistence format, CLI/TUI surface, canonical household data, generic quotient/equivalence framework, mutation-testing framework, graph framework, or multi-authority transaction mechanism.

Its job is only to keep current structural research state and naming authority unambiguous.
