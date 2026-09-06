# LOAM Structural Falsification Progress

Status: **S003 completed; S008 remains the structural near queue**

Review date: 2026-09-06
Review baseline main: `28af8afc1cbf7e57d4b3f7ee7477e5dc692ccff0`
S003 executable qualification head: `914a9e59f50b36c0c442d2accf492c0a41755b1c`

This file is the current progress authority for `LOAM_STRUCTURAL_FALSIFICATION_ATLAS.md`.
The atlas owns the structural specimen descriptions and attack modes. This file owns current Work / Finding state after cross-reference and structural observations.

The structural corpus is deliberately separate from F001-F200. A structural result does not change domain-falsification counts and does not create production work by itself.

## State model

```text
Work
  REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | SURVIVED | COUNTEREXAMPLE | REDUNDANT
```

Interpretation:

- `DONE / REDUNDANT` means existing LOAM evidence already contained a direct representative of the structural question before the structural atlas selected it.
- `DONE / SURVIVED` means a new explicit structural attack was run and the selected law survived its stated proof/check boundary.
- `DONE / COUNTEREXAMPLE` means the attacked structural claim failed.
- `READY / UNTESTED` means the structural family survived cross-reference and has a small enough next witness to justify near formal work.
- `REVIEWED / UNTESTED` means the gap appears real, but it is not currently a better near observation than the selected queue.

`REDUNDANT` here does not mean the structural pattern is unimportant. It means the repository had already tested that pattern before the structural atlas gave it one catalogue name.

## Current result

```text
Corpus total                   12
Cross-reference reviewed       12

DONE / REDUNDANT                9
DONE / SURVIVED                 1
READY / UNTESTED                1
REVIEWED / UNTESTED             1
OBSERVING                       0
```

The main structural finding remains that most meta pressure was already present in LOAM as scattered observations. The atlas is primarily a reverse index and gap detector, not a second large research roadmap.

# DONE / REDUNDANT

## S001 — retained-primitive deletion

**Work:** DONE  
**Finding:** REDUNDANT

Direct evidence already exists in Observation 146.

Observation 146 asks which historical-admission identities are structural and which are representation debt. It attempts deletion/reconstruction separately for Event identity, Effect identity, and ActualValidityFact identity.

Result:

```text
EventId
  retain

EffectKey
  retain

one independently identified initial ActualValidity fact
  not required

later temporal revision identity
  retain on demand
```

This is a direct specimen of the S001 procedure: remove one retained distinction, ask what selected later queries lose, and keep only what remains independently observable.

## S002 — quotient / identity granularity

**Work:** DONE  
**Finding:** REDUNDANT

Observations 052, 067, and 146 already attack concrete identity quotients.

They show:

```text
Effect coordinate/value
  -/-> Effect identity

Event content + date
  -/-> Event identity
```

Two Effects may share selected coordinates/value while later provenance distinguishes them. Two Events may share payload/date while later Correction distinguishes them. Collapsing those identities into coarser equivalence classes therefore loses legitimate queries.

## S004 — permutation / alpha-renaming invariance

**Work:** DONE  
**Finding:** REDUNDANT

Several direct representatives already exist:

- `Event.quantityAt_perm` proves Effect list permutation cannot change the selected quantity-at-coordinate answer;
- `EventMemory.findById?_perm` proves identity lookup is independent of Event-memory representation order under unique identity;
- correction / Scheduled lifecycle persistence deliberately gives row order no chronology authority;
- Observation 078 proves selected quantity projections are invariant under fresh EventId / EffectKey renaming while identity lookup remains an explicit negative boundary.

This is exactly the S004 discipline: allowed transformations are query-relative, and identity-sensitive questions are excluded rather than normalized away.

## S005 — conservative / neutral extension

**Work:** DONE  
**Finding:** REDUNDANT

Application 006 directly proves conservative fact extension in Lean.

For an arbitrary later fact family it proves that adding the family and forgetting it returns exactly the old image, preserves old memberships, and leaves a representative old projection unchanged.

```text
new independent evidence
  need not perturb old projections that do not opt into it
```

S005's possible `zero-net pair` variant remains a future metamorphic test if a concrete projection needs it, but no broad new structural observation is required merely to establish neutral extension as a LOAM pattern.

## S006 — local composition

**Work:** DONE  
**Finding:** REDUNDANT

Observation 199 is a direct composition experiment.

It composes:

```text
burden allocation
+ refund source provenance
+ prior discharge evidence
```

and asks whether a fourth independent degree of freedom is required for the selected full-refund consequence. Smaller partial combinations admit counterexamples, while the full existing-evidence combination determines the selected answer in the bounded model. No new evidence family is earned.

## S009 — query-relative minimality

**Work:** DONE  
**Finding:** REDUNDANT

This structural law predates the atlas.

Observations 004 and 005 first establish that sufficient retained memory depends on the future operation/question vocabulary. Observation 029 generalizes the relationship in Lean:

```text
future vocabulary
  -> observational equivalence
  -> sufficient retained summary
```

For `small ⊆ large`, equivalence under the larger vocabulary implies equivalence under the smaller one, and a summary sufficient for the larger vocabulary remains sufficient for the smaller.

The Observations 079-084 audit later reuses the same law for checker interpretation, result reuse, privacy projections, marginals/joint questions, and query-shape-dependent evidence.

## S010 — verification-of-verification

**Work:** DONE  
**Finding:** REDUNDANT

The robustness pattern already exists in Observation 060, with Observation 080 supplying the epistemic boundary.

Observation 060 supplies a concrete crash/recovery witness, checks an inductive invariant rather than one fixed trace length, and includes an `UnsafeNext` sensitivity model where reversing writer order must produce the bad state. Observation 080 separately establishes that bounded search, finite scope, and a Lean theorem under premises do not collapse into one context-free `SUCCESS` fact.

## S011 — formal abstraction -> production semantics

**Work:** DONE  
**Finding:** REDUNDANT

Observations 192 and 193 form a direct bridge.

Observation 192 proves a general future-context observational-equivalence law in Lean. Observation 193 then instantiates that pressure with existing production semantics:

```text
EventMemory
+ EventCorrectionMemory
+ EventCorrection
+ CorrectionFrontier
+ quantityAtCorrectionFrontier?
```

Two worlds equal under the current selected production question become distinguishable after the same future Correction relation is appended, exactly matching the Observation-192 law.

## S012 — cross-authority partial publication

**Work:** DONE  
**Finding:** REDUNDANT

Observations 059 and 060 already study physically separate Event and Correction authorities.

Observation 059 finds that individually atomic stream replacement is not enough. The selected bounded protocol requires:

```text
writer: relation -> Event
reader: Event -> relation
```

Observation 060 adds crash/restart, explicit retry, an interrupted-publication witness, and an unsafe-order sensitivity model.

PR #431 later applies the same relation-first activation law in practical Scheduled replacement publication. Cross-authority partial publication is therefore both formally observed and practically exercised.

# DONE / SURVIVED

## S003 — split / merge representation invariance

**Work:** DONE  
**Finding:** SURVIVED

Observation 200 directly attacked the first unresolved structural specimen against existing `Loam.Core.Event` semantics.

The proved comparison is:

```text
World A
  one Effect at c carrying left + right

World B
  two distinct Effects at c carrying left and right

selected query
  Event.quantityAt c
```

`Loam/Observations/Observation200.lean` proves for arbitrary Event identity, Effect identities, `LocusId`, `MeasureId`, and exact signed `Quantity` values:

```text
quantityAt_split_merge
```

Therefore the selected quantity projection is invariant under this quantity-preserving one-to-two decomposition.

The same observation also proves:

```text
split_merge_representation_remains_distinct
```

so the retained Effect lists remain observably different representations. The result is deliberately not global Event equivalence and does not erase Effect identity or provenance.

Dedicated Observation 200 CI completed **SUCCESS** on executable head:

```text
914a9e59f50b36c0c442d2accf492c0a41755b1c
```

workflow run:

```text
34006843677
```

The qualified boundary is:

```text
quantity-preserving Effect split / merge
  -> invisible to Event.quantityAt at the decomposed coordinate

but

Effect decomposition / identity
  -> remains retained and available to other questions
```

Observation 120 remains explicit counterpressure: split/merged realization semantics can require independently observable apportionment. S003 therefore establishes a query-induced invariance, not a universal split/merge equivalence.

No production change is earned.

# Unresolved structural pressure

## S008 — history length / bounded-topology pressure

**Work:** READY  
**Finding:** UNTESTED

Application 007 is strong nearby evidence but remains a representative executable specimen rather than a general frontier theorem. Its main sample includes:

```text
A -> B -> C
X -> Y
U
```

and checks row-order independence plus rejection of branching, cycles, and dangling references.

Observation 060 proves an inductive transition invariant for its publication protocol, but that is not a theorem that every current finite correction/replacement frontier law is independent of graph path length.

The remaining question is:

> Does an important current frontier property survive arbitrary admitted linear-chain length, or is it only demonstrated by short examples?

### First witness recommendation

Start with the existing Correction frontier rather than inventing a generic graph library.

Candidate law:

```text
for an admitted finite linear Correction chain,
exactly the terminal Event contributes to the selected correction-aware quantity
```

Keep sibling conflict, missing endpoints, and cycles outside the admitted premise rather than defining winner semantics.

Likely first instrument: **Lean** if the current Application structure supports a small general theorem; Alloy first only if the admission topology itself remains uncertain.

## S007 — pairwise-safe / triple-unsafe composition

**Work:** REVIEWED  
**Finding:** UNTESTED

Observations 083 and 084 provide nearby pressure: separately adequate marginals can lose a later joint question, and evidence sufficient for a 2 x 2 joint shape can fail at 3 x 3.

But the exact S007 topology has not been directly tested:

```text
A + B admissible
A + C admissible
B + C admissible
A + B + C not admissible / ambiguous
```

No current practical three-way seam justifies paying the state-space cost now. Keep S007 on the watchlist until a concrete three-authority or three-relation interaction appears.

# Structural near queue

| Order | ID | C | D | W | N | Total | Reason |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | S008 | 3 | 2 | 3 | 2 | 10 | Current correction/replacement frontiers make path-length independence practical, and the next theorem can stay narrow. |
| watch | S007 | 1 | 3 | 1 | 3 | 8 | Potentially destructive but no concrete current triple seam and likely larger state space. |

Only one structural item should normally move to `OBSERVING` at a time.

## Relation to the domain queue

The structural queue does **not** automatically preempt the F-series domain queue.

Observation 199 closed F076 as absorbed composition. S003 is now also complete. Before starting another structural item, re-read `LOAM_FALSIFICATION_PROGRESS.md` and prefer current domain pressure unless S008 is directly implicated by practical work.

At this checkpoint the intended rhythm is therefore:

```text
S003 complete
  -> return to the domain queue
  -> keep S008 as the next structural candidate
```

## Recommended next structural observation

**S008**, but not automatically next overall.

The structural question is now narrow: whether an existing correction-frontier terminal-contribution law can be lifted from short executable specimens to arbitrary admitted finite linear-chain length without inventing a generic graph framework.

## Boundary

This progress update adds no production type, persistence format, CLI/TUI surface, canonical household data, generic quotient/equivalence framework, mutation-testing framework, or multi-authority transaction mechanism.

Observation 200 adds one proved representation-invariance law and leaves the retained Core unchanged.
