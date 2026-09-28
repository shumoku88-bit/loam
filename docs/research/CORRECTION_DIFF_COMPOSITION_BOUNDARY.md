# Correction diff / composition boundary

Status: **CURRENT LIVE RESEARCH BOUNDARY — Observations 257–262 graduated from prose**

This document is the current-facing semantic record for LOAM's correction-diff
study. The detailed step-by-step qualification narratives for Observations
257–262 have graduated to Git history. Their Lean witnesses remain live in
`Loam.Observations`.

This is a research boundary, not a production API declaration.

## Live formal witnesses

- `Loam/Observations/Observation257.lean`
- `Loam/Observations/Observation258.lean`
- `Loam/Observations/Observation259.lean`
- `Loam/Observations/Observation260.lean`
- `Loam/Observations/Observation261.lean`
- `Loam/Observations/Observation262.lean`

The sequence asks how much useful correction explanation can be derived from
already-retained Event and EventCorrection evidence without inventing
cross-Event Effect lineage or a second diff authority.

## 257 — coordinate delta needs no Effect lineage

For one `LocusId × MeasureId` coordinate:

```text
before = original.quantityAt coordinate
after  = replacement.quantityAt coordinate
delta  = after - before
```

Observation 257 proves that this exact physical quantity delta is unchanged when
optional Effect identity is erased. Two replacement worlds may disagree about
which local EffectKey names which Effect while producing the same coordinate
change.

Therefore:

```text
"what quantity changed here?"
    does not require Effect lineage

"which exact Effect became which exact Effect?"
    remains a different, unanswered query
```

## 258 — complete finite changed support is derivable

The candidate support for one correction is the deduplicated union of coordinates
physically represented by the original and replacement Events.

Observation 258 proves:

```text
coordinate absent from both Events
    -> delta = 0

delta != 0
    -> coordinate is in candidate support

changedCoordinates
    = candidate support filtered by delta != 0
```

So the changed-coordinate list is exact finite support for observable
`LocusId × MeasureId` quantity change. No persistent diff table is required.

This projection remains intentionally lossy. It does not recover within-coordinate
Effect rearrangement, lineage, cause, chronology, or accounting interpretation.

## 259 — human labels come from presence, not zero quantity

For coordinates already known to be changed, Observation 259 derives:

```text
absent before, present after -> added
present before, absent after -> removed
present before, present after -> changed
```

Presence means physical representation in the Event's Effect list.

Aggregate quantity zero is not a safe proxy for absence because multiple Effects
at one coordinate may cancel to zero. A coordinate can therefore have
`before = 0` and still correctly be labelled `changed`, not `added`.

The labels are read-side descriptions, not retained correction facts.

## 260 — two-step quantity diffs compose

For:

```text
A -> B -> C
```

Observation 260 proves exact telescoping:

```text
delta(A,C) = delta(A,B) + delta(B,C)
```

A raw union of step supports is only an over-approximation because intermediate
changes can cancel. Filtering the aligned union by nonzero summed delta yields
the exact direct endpoint support.

Human labels do not form the same additive algebra. They are recomputed from
endpoint presence. For example, an `added` step followed by a `removed` step
may compose to no endpoint diff row at all.

## 261 — the composition law closes over finite sequences

Observation 261 lifts the two-step result to an arbitrary finite selected Event
sequence.

For a chain beginning at `first` and ending at `last`:

```text
sum of adjacent coordinate deltas
    = direct delta(first,last)
```

The union of every adjacent changed support, filtered by nonzero total chain
delta, is exactly the direct endpoint changed support.

This is a theorem about a selected finite sequence. It does not claim that an
arbitrary `List Event` is authoritative correction history.

## 262 — retained correction topology can justify the selected sequence

Production already owns correction topology through:

```text
EventCorrectionMemory
        |
        v
CorrectionFrontier.correctionFrontierAdmissible
        |
        +-- referenced endpoints exist
        +-- one target has at most one replacement
        +-- one replacement has at most one target
        +-- cycles are refused
        |
        v
admitted disjoint finite correction paths
```

Observation 262 builds a research-only read adapter above that authority. It
follows only retained target-to-replacement edges after production admission and
fails closed on branching, merging, missing endpoints, or cycles.

On the selected admitted linear witness, the extracted Event sequence feeds
Observation 261 and produces the same endpoint delta as the direct
Observation-258 calculation.

Production `CorrectionFrontier` remains the topology authority. The observation
does not introduce persistent chain state, a second chain authority, chronology,
global Effect identity, or cross-Event Effect lineage.

## What production owns today

The durable production side of this boundary is intentionally smaller than the
research toolkit:

- `Loam/Core/EventCorrection.lean` retains Event-level correction edges;
- `Loam/Application/CorrectionFrontier.lean` admits correction topology
  fail-closed and supplies current/root-terminal frontier semantics;
- retained Events remain the physical quantity evidence.

The coordinate diff, complete diff, human explanation, finite composition
helpers, and explicit intermediate-chain reader remain research witnesses rather
than canonical product state.

That asymmetry is intentional.

## Current information boundary

```text
retained Events + admitted EventCorrection topology
        |
        +--> one-coordinate before / after / delta
        |
        +--> exact finite changed-coordinate support
        |
        +--> derived added / removed / changed labels
        |
        +--> exact endpoint quantity diff across a selected finite path
```

None of those arrows establishes:

```text
cross-Event Effect sameness
capture / posting chronology
causal explanation
user intent
accounting interpretation
persistent diff truth
```

## Promotion gate

Do not promote the Observation-262 chain reader merely because the selected
witness works.

A production intermediate-history query would first need stronger reusable
reader evidence, including generic consequences such as order independence and
completeness over admitted correction paths, plus a concrete product need for
intermediate steps rather than the current root/terminal frontier.

Likewise, do not add cross-Event Effect correspondence unless a concrete query
cannot be answered at the coordinate/event level.

## Stop rule

The durable conclusion is:

```text
ordinary correction quantity explanation
    = derivable projection

complete finite diff
    = derivable projection

human change labels
    = derivable projection

endpoint composition
    = derivable algebra

authoritative topology
    = existing CorrectionFrontier

Effect lineage / chronology / diff authority
    = not earned
```

The research result should stay executable without turning its helper structures
into retained production ontology.
