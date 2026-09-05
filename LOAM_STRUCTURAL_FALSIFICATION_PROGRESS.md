# LOAM Structural Falsification Progress

Status: **S001-S012 cross-reference reviewed; two-item structural near queue selected**

Review date: 2026-09-06
Review baseline main: `28af8afc1cbf7e57d4b3f7ee7477e5dc692ccff0`

This file is the current progress authority for `LOAM_STRUCTURAL_FALSIFICATION_ATLAS.md`.
The atlas owns the structural specimen descriptions and attack modes. This file owns current Work / Finding state after cross-reference.

The structural corpus is deliberately separate from F001-F200. A structural result does not change domain-falsification counts and does not create production work by itself.

## State model

```text
Work
  REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | SURVIVED | COUNTEREXAMPLE | REDUNDANT
```

Interpretation:

- `DONE / REDUNDANT` means existing LOAM evidence already contains a direct representative of the structural question.
- `READY / UNTESTED` means the structural family survived cross-reference and has a small enough next witness to justify near formal work.
- `REVIEWED / UNTESTED` means the gap appears real, but it is not currently a better near observation than the selected queue.

`REDUNDANT` here does not mean the structural pattern is unimportant. It means the repository had already tested that pattern before the structural atlas gave it one catalogue name.

## Review result

```text
Corpus total                   12
Cross-reference reviewed       12

DONE / REDUNDANT                9
READY / UNTESTED                2
REVIEWED / UNTESTED             1
OBSERVING                       0
```

The striking result is that most structural/meta pressure was already present in LOAM as scattered observations. The atlas is therefore primarily a reverse index and gap detector, not a new research program layered on top of the old one.

# DONE / REDUNDANT

## S001 — retained-primitive deletion

**Work:** DONE  
**Finding:** REDUNDANT

Direct evidence already exists in Observation 146.

Observation 146 asks exactly which historical-admission identities are structural and which are representation debt. It attempts deletion/reconstruction separately for Event identity, Effect identity, and ActualValidityFact identity.

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

This is already a direct specimen of the S001 procedure: remove one retained distinction, ask what selected later queries lose, and keep only what remains independently observable.

S001 remains useful as a catalogue family for future primitives, but a new observation is not needed merely to establish that LOAM can perform this reverse-direction attack.

## S002 — quotient / identity granularity

**Work:** DONE  
**Finding:** REDUNDANT

Observations 052, 067, and 146 already attack concrete identity quotients.

They show, among other things, that:

```text
Effect coordinate/value
  -/-> Effect identity

Event content + date
  -/-> Event identity
```

Two Effects may share selected coordinates/value while later provenance distinguishes them. Two Events may share payload/date while later Correction distinguishes them.

So collapsing those identities into the proposed coarser equivalence classes loses legitimate queries. The exact S002 structural move is already qualified for important current identities.

## S004 — permutation / alpha-renaming invariance

**Work:** DONE  
**Finding:** REDUNDANT

Several direct representatives already exist:

- `Event.quantityAt_perm` proves Effect list permutation cannot change the selected quantity-at-coordinate answer;
- `EventMemory.findById?_perm` proves identity lookup is independent of Event-memory representation order under unique identity;
- correction / Scheduled lifecycle persistence deliberately gives row order no chronology authority;
- Observation 078 proves selected quantity projections are invariant under fresh EventId / EffectKey renaming while identity lookup remains an explicit negative boundary.

This is exactly the S004 discipline: allowed transformations are query-relative, and identity-sensitive questions are excluded rather than accidentally normalized away.

## S005 — conservative / neutral extension

**Work:** DONE  
**Finding:** REDUNDANT

Application 006 directly proves conservative fact extension in Lean.

For an arbitrary later fact family it proves that adding the family and forgetting it returns exactly the old image, preserves old memberships, and leaves a representative old projection unchanged.

That closes the selected structural question:

```text
new independent evidence
  need not perturb old projections that do not opt into it
```

S005's possible `zero-net pair` variant remains a valid future metamorphic test if a concrete projection needs it, but no new broad structural observation is required just to establish neutral extension as a LOAM pattern.

## S006 — local composition

**Work:** DONE  
**Finding:** REDUNDANT

Observation 199 is a direct composition experiment.

It composes three already-earned distinctions:

```text
burden allocation
+ refund source provenance
+ prior discharge evidence
```

and asks whether a fourth independent degree of freedom is required for the selected full-refund consequence.

The smaller partial combinations admit counterexamples, while the full existing-evidence combination determines the selected answer in the bounded model. No new evidence family is earned.

This is exactly the S006 method: compose already-qualified seams before inventing another noun.

## S009 — query-relative minimality

**Work:** DONE  
**Finding:** REDUNDANT

This structural law predates the atlas by a large margin.

Observations 004 and 005 first establish that sufficient retained memory depends on the future operation/question vocabulary. Observation 029 generalizes the relationship in Lean:

```text
future vocabulary
  -> observational equivalence
  -> sufficient retained summary
```

For `small ⊆ large`, equivalence under the larger vocabulary implies equivalence under the smaller one, and a summary sufficient for the larger vocabulary remains sufficient for the smaller.

The Observations 079-084 audit later reuses the same law for checker interpretation, result reuse, privacy projections, marginals/joint questions, and query-shape-dependent evidence.

Therefore S009 is not merely partially anticipated. It is already an explicit general law in LOAM.

## S010 — verification-of-verification

**Work:** DONE  
**Finding:** REDUNDANT

The exact robustness pattern already exists in Observation 060, with Observation 080 supplying the epistemic boundary.

Observation 060 does more than report a green safety result:

- it supplies a concrete mid-publication crash/recovery witness;
- it checks an inductive invariant rather than only one fixed trace length;
- it introduces an `UnsafeNext` sensitivity model where reversing writer order must produce the bad state;
- the result note explicitly says the witness and sensitivity checks keep the model from becoming vacuous.

Observation 080 separately establishes that a bounded Alloy result, finite scope, and a Lean theorem under premises do not collapse into one context-free `SUCCESS` fact.

So S010 describes a robustness discipline LOAM has already exercised directly. This does **not** require mutation-testing every historical observation. Apply the pattern again only when a concrete high-consequence result lacks enough confidence.

## S011 — formal abstraction -> production semantics

**Work:** DONE  
**Finding:** REDUNDANT

Observations 192 and 193 already form a particularly clean bridge.

Observation 192 proves a general future-context observational-equivalence law in Lean using abstract deterministic states, operations, and selected terminal questions.

Observation 193 then takes that abstract result into already-existing production semantics without adding a new production primitive:

```text
EventMemory
+ EventCorrectionMemory
+ EventCorrection
+ CorrectionFrontier
+ quantityAtCorrectionFrontier?
```

Two worlds that are equal under the current selected production question become distinguishable after the same future Correction relation is appended, exactly as the Observation-192 future-context law predicts.

That is a direct S011 representative: formal abstraction and actual Core/Application semantics are connected by the same selected observation rather than merely being described with similar words.

Real-data quantity parity provides another practical bridge at a different layer, but it is not needed to close S011 as a new structural category.

## S012 — cross-authority partial publication

**Work:** DONE  
**Finding:** REDUNDANT

This family is already unusually well represented.

Observations 059 and 060 study physically separate Event and Correction authorities.

Observation 059 finds that individually atomic stream replacement is not enough. The selected safe bounded protocol requires:

```text
writer: relation -> Event
reader: Event -> relation
```

and explicitly finds counterexamples for the opposite writer/reader orderings.

Observation 060 adds crash/restart, explicit retry, a representative interrupted-publication witness, and an unsafe-order sensitivity model.

More recently, PR #431 applies the same law in practical Scheduled replacement publication:

```text
publish replacement relation first
then publish replacement Scheduled occurrence
```

The relation-first interrupted state fails closed because its endpoint is not yet present, and the retry path reuses the retained replacement identity before publishing the missing occurrence.

So cross-authority partial publication is not an untested meta concern in LOAM. It is already both formally observed and practically exercised.

# Unresolved structural pressure

## S003 — split / merge representation invariance

**Work:** READY  
**Finding:** UNTESTED

Nearby evidence exists, but it does not close the structural question.

`BalancedMovement.quantityAt` / Event quantity projections aggregate quantities at a coordinate, and Observation 120 shows that split/merged **realization semantics** can require extra apportionment evidence. Observation 153 also distinguishes routing subject granularity.

Those results warn that decomposition is sometimes semantic, but LOAM does not yet have one explicit law of the form:

```text
for query Q that ignores decomposition provenance,
replace one quantity q at coordinate c
with q1 and q2 at c where q1 + q2 = q
-> Q is unchanged
```

paired with the negative boundary:

```text
identity/provenance-sensitive Q
may change
```

This is a small, central representation-invariance question and is the first structural near candidate.

### First witness recommendation

Use one Event / one selected `Locus × Measure` coordinate.

Compare:

```text
World A
  one Effect carrying q

World B
  two Effects carrying q1 and q2
  q1 + q2 = q
```

First prove/check equality only for the existing quantity projection. Do not claim that the two worlds are globally equivalent. Reuse Observation 052 as the negative identity/provenance boundary.

Likely first instrument: **Lean**, with J only if finite decomposition geometry adds a distinct answer.

## S008 — history length / bounded-topology pressure

**Work:** READY  
**Finding:** UNTESTED

Application 007 is strong nearby evidence but is still a representative executable specimen rather than a general frontier theorem. Its main sample includes:

```text
A -> B -> C
X -> Y
U
```

and checks row-order independence plus rejection of branching, cycles, and dangling references.

Observation 060 proves an inductive transition invariant for its publication protocol, but that is not a theorem that every current finite correction/replacement frontier law is independent of graph path length.

So one gap remains:

> Does an important current frontier property survive arbitrary admitted linear-chain length, or is it only demonstrated by short examples?

### First witness recommendation

Start with the existing Correction frontier rather than inventing a generic graph library.

Check lengths 1, 2, 3, and a generated finite family. If the property is clearly structural, promote only the narrow useful law to Lean.

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

Observations 083 and 084 provide strong nearby pressure: separately adequate marginals can lose a later joint question, and the evidence sufficient for a 2 x 2 joint shape can fail at 3 x 3.

But the exact S007 topology has not been directly tested:

```text
A + B admissible
A + C admissible
B + C admissible
A + B + C not admissible / ambiguous
```

No current practical three-way seam was found during this review that justifies paying the state-space cost now.

Keep S007 as a watchlist item. Promote it only when repeated two-hop composition checks expose one concrete three-authority or three-relation interaction.

# Structural near queue

The unresolved items were scored using the atlas `C / D / W / N` rule.

| Order | ID | C | D | W | N | Total | Reason |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | S003 | 3 | 3 | 3 | 3 | 12 | Directly attacks Core representation leakage with a tiny query-bounded witness. |
| 2 | S008 | 3 | 2 | 3 | 2 | 10 | Current correction/replacement frontiers make path-length independence practical, and the next theorem can stay narrow. |
| watch | S007 | 1 | 3 | 1 | 3 | 8 | Potentially destructive but no concrete current triple seam and likely larger state space. |

Only one structural item should normally move to `OBSERVING` at a time.

## Relation to the domain queue

The structural queue does **not** automatically preempt the F-series domain queue.

The review baseline includes Observation 199, which closes F076 as absorbed composition. The remaining domain queue should continue to be re-read from `LOAM_FALSIFICATION_PROGRESS.md` before starting new work.

A structural item should jump ahead only when:

- a current practical change exercises that exact structural seam;
- the structural result could invalidate evidence currently being relied upon;
- or the selected witness is so small that it can close uncertainty without opening a new implementation front.

## Recommended next structural observation

**S003** is the best first structural observation.

It is small enough to avoid creating a generic equivalence framework, but strong enough to answer a foundational question:

> When LOAM's selected quantity query cannot observe decomposition, does arbitrary Effect splitting leak into the answer anyway?

The desired outcome is not "split and merge are always equivalent."

The useful boundary is narrower:

```text
quantity-only observation
  should factor through quantity-preserving decomposition

identity/provenance observation
  may distinguish the decomposition
```

That would connect the existing simple `quantityAt` algebra to an explicit representation-invariance law without erasing the identity distinctions already earned by Observations 052, 067, and 146.

## Boundary

This review adds no production type, persistence format, CLI/TUI surface, canonical household data, generic quotient/equivalence framework, mutation-testing framework, or multi-authority transaction mechanism.

It only records what the repository had already answered and narrows the genuinely new structural pressure to a very small set.