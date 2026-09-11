# LOAM semantic audit ledger

Status: audit-only working ledger

Baseline: `3227fcf59ae1fa15191378be84ab5527dd57e29c`

Created after the September 2026 product-structure audit. This document records hypotheses and evidence before implementation. An entry in this ledger is not authorization to refactor production code.

## 1. Purpose

LOAM should retain only distinctions that earn independent meaning, information, authority, lifecycle, or safety, while sharing mathematics and mechanics that are genuinely the same.

The target is not the fewest source files, declarations, or lines. The target is:

> the fewest independent implementation principles that preserve every independently observable household distinction.

A physical module count is therefore an audit signal, not a concept count.

The desired shape resembles a strong plumbing/porcelain architecture: a small set of generative semantic and mathematical primitives should support many derived household answers without each answer becoming a new primitive.

## 2. Audit discipline

Before deleting or merging a semantic distinction, ask:

> Can two household worlds agree on the proposed compressed representation but require different correct answers?

If yes, the distinction is independently meaningful and must remain visible somewhere.

Before retaining duplicated implementation, ask:

> Do several semantic families enforce the same structural law with independently copied code?

If yes, test whether a small shared mathematical/mechanical helper can preserve the semantic boundaries while removing duplicated implementation principles.

A candidate concept remains independently justified if removing or merging it causes at least one of the following:

1. a previously impossible invalid state becomes representable or admissible;
2. an externally observable household answer changes;
3. non-reconstructable canonical information is lost;
4. crash, retry, migration, recovery, or fail-closed guarantees weaken;
5. an independently meaningful authority, lifecycle, or reason-to-change is erased.

If none applies and the value is derivable from retained evidence, it should not be counted as an independent primitive even if a named type or module remains useful.

## 3. Audit states

Use these states consistently:

- `UNREVIEWED`: registered but not yet investigated.
- `UNDER_REVIEW`: evidence gathering or formal probing in progress.
- `KEEP`: independent semantic distinction or proven high-value shared primitive.
- `KEEP_WRAPPER`: semantic boundary should remain nominally distinct while mechanics may be shared.
- `SHARE_MECHANICS`: preserve meanings but extract common structural mathematics/mechanics.
- `DERIVED`: no independent retained information; compute from other admitted evidence.
- `MOVE`: meaning remains valid but current architectural layer is probably wrong.
- `COMPRESS`: several current production structures can likely be represented by fewer independent mechanisms.
- `DELETE`: no independent meaning, behavior, safety, compatibility, or recovery reason remains.
- `UNKNOWN`: current evidence is insufficient.
- `IMPLEMENTATION_READY`: audit and formal gates are satisfied and a concrete change may be proposed.

No production refactor should begin merely from `UNDER_REVIEW`, `DERIVED`, `MOVE`, or `COMPRESS`.

## 4. Current physical inventory

At the baseline above:

```text
Loam/Core/*.lean          30 modules
Loam/Application/*.lean   18 modules
Loam/Persistence/*.lean   21 modules
-------------------------------------
                         69 modules
```

For comparison, `docs/research/SEMANTIC_CENSUS_2026-09-08.md` recorded Core 34 plus Application 18 at its earlier baseline. The semantic layers have therefore already contracted from 52 to 48 physical modules while preserving current production behavior.

This is evidence that the current problem is not simple unchecked growth. Some qualified compression has already succeeded.

## 5. Provisional Core census

This is a role census, not a deletion decision.

### 5.1 Strong semantic or evidential candidates

These modules/types currently appear to retain independently meaningful household distinctions or canonical evidence:

```text
Quantity
Measure
Effect
Event
Purpose
Capacity
Scheduled
Attention
AccountingRole
LocusAdmission
ZeroOriginCoverage
OpenRelation
EventDescription
ActualValidity
CapacityEffective
EventCorrection
ActualReversal
ActualValidityHistory
HistoricalRouting
ScheduledTerminal
```

Their internal collections, lookup procedures, or projection helpers may still be compressible. `KEEP` at the semantic level does not imply every line or helper is irreducible.

### 5.2 Strong shared mechanics / algebra

```text
BalancedMovement
FiniteKeyed
```

`BalancedMovement` is a positive control for the desired architecture: one zero-sum movement algebra is shared across different semantic coordinate types without collapsing those coordinate meanings.

`FiniteKeyed` is another positive control: lookup/permutation mechanics are shared while semantic memories remain distinct authorities.

### 5.3 Specializations and representational boundaries

```text
ScheduledRouting
RoutingEffective
EventMemory
CapacityMemory
ScheduledMemory
AttentionMemory
EventCorrectionMemory
EventDescriptionMemory
ActualValidityMemory
CapacityEffectiveMemory
```

These names are useful but should not automatically be counted as independent domain primitives. Several are nominal semantic wrappers over repeated finite keyed collection mechanics.

### 5.4 Derived projection candidate

```text
CorrectionQuantity
```

`CorrectionQuantity` retains no new canonical fact. It computes an effective quantity from `EventMemory` plus explicit correction evidence. Its current Core placement therefore deserves architectural review even if the projection itself remains valid.

## 6. Positive compression precedents

These are controls against over-aggressive deletion.

### PC-001 BalancedMovement

Status: `KEEP`

One mathematical zero-sum movement primitive generates behavior for multiple semantic domains while typed coordinates preserve meaning. This is the model to imitate.

### PC-002 ReplacementFrontier

Status: `KEEP`

Application replacement/supersession mechanics were extracted into one structural helper while family-specific semantic adapters retained authority. This demonstrates the rule:

> share structural mathematics; preserve semantic authority.

### PC-003 FiniteKeyed

Status: `KEEP`

PR #563 extracted keyed lookup and permutation proof mechanics across multiple semantic memories without introducing a universal household `Memory` ontology.

### PC-004 Scheduled terminal consolidation

Status: `KEEP`, continue review of mechanics

Former completion, replacement, and retirement families are now represented by one `ScheduledTerminal` relation whose target distinguishes the three meanings. This reduced physical Core surface while preserving malformed cross-kind conflict for fail-closed application review.

### PC-005 ActualValidity revision identity compression

Status: `KEEP`

Current `ActualValidityHistory` uses Event-rooted base identity and allocates an independent revision identity only when a temporal revision actually occurs. This is an important pattern for auditing other identities: do not allocate an independent identity before independent lifecycle pressure earns it.

## 7. Active audit ledger

### SA-001 Finite keyed semantic memories

Status: `SHARE_MECHANICS` / `KEEP_WRAPPER`
Priority: medium

Observed family includes at least:

```text
EventMemory
CapacityMemory
ScheduledMemory
AttentionMemory
EventCorrectionMemory
EventDescriptionMemory
ActualValidityMemory
CapacityEffectiveMemory
```

Common shape:

```text
items : List Item
unique key law
fail-closed admission
lookup by key
append while preserving uniqueness
representation order has no semantic priority
```

Current evidence already supports sharing lookup mechanics through `FiniteKeyed`.

Open question: is there further net-negative structural extraction beyond lookup/permutation without introducing a generic public household Memory type or thicker adapters?

Formal test:

- define the minimum structural carrier or helper;
- prove representation round trips for selected families;
- prove duplicate-key admission equivalence;
- prove lookup/append behavior commutes with the representation;
- measure production source delta and adapter thickness.

Promotion rule: do not generalize merely because the carriers are isomorphic.

### SA-002 Two-endpoint unique relation mechanics

Status: `UNDER_REVIEW`
Priority: high

Primary current candidate:

```text
ActualReversalMemory
```

Related lifecycle structures should be compared structurally, especially the endpoint-uniqueness portions of `ScheduledTerminalMemory`.

Hypothesis: independently meaningful relation types may share a finite partial-injection / partial-bijection mechanical kernel.

Risk: same endpoint shape does not imply same admission semantics. Scheduled terminal deliberately preserves cross-kind conflict, while reversal has its own inverse-effect semantic obligations.

Formal test:

- model only endpoint uniqueness separately from semantic admission;
- search for counterexamples where genericizing the relation would admit a world one family must reject;
- extract mechanics only if semantic admission remains outside the helper.

### SA-003 Temporal / effective evidence family

Status: `UNDER_REVIEW`
Priority: high

Candidates:

```text
ActualValidity
CapacityEffective
RoutingEffective
HistoricalRouting
```

Question: which pieces are independent retained facts and which are typed coordinates or selection mechanics?

Known caution: Actual occurrence validity is independently observable and must not be collapsed into Event structure merely because most Events have dates in practice.

Formal test:

- construct pairs of worlds with equal Events but different validity/effective evidence;
- record which household answers differ;
- separate independent temporal evidence from reusable latest-visible/coordinate mechanics.

### SA-004 CorrectionQuantity architectural placement

Status: `DERIVED`, possible `MOVE`
Priority: medium

Evidence: `CorrectionQuantity.quantityAtEffective?` computes from `EventMemory` and one explicit `EventCorrection`; it retains no independent canonical information.

Hypothesis: the projection belongs in Application rather than Core, or can be absorbed by a stronger existing inspection boundary.

Required before implementation:

- enumerate all production callers;
- prove observable quantity results unchanged under relocation/absorption;
- verify no proof-import boundary or public API relies on Core ownership as semantic authority;
- check whether removal produces a net simplification rather than merely moving a file.

### SA-005 Practical Core public surface

Status: `UNDER_REVIEW`
Priority: medium

`Loam/Core.lean` identifies itself as the practical Core entry point but imports only a subset of physical Core modules. Production code directly uses Core modules such as `ScheduledTerminal` and `ActualReversal` outside that barrel.

Question: is `Core.lean` a meaningful public semantic surface, an outdated umbrella, or an intentionally narrow convenience import?

Possible outcomes:

- make it accurately represent the intended public Core surface;
- narrow and rename its purpose;
- remove the umbrella if feature-specific imports are the real architecture.

Do not add imports merely to make counts match.

### SA-006 Persistence semantic echo

Status: `UNDER_REVIEW`
Priority: highest

Current physical surface: 21 modules.

Many semantic families own separate persistence files while common mechanics already exist in helpers such as:

```text
TokenSyntax
VersionedRows
SiblingStage
```

Hypothesis: persistence is currently the largest remaining amplification boundary, where one semantic distinction fans out into repeated codec/version/load/save/staging principles.

Audit questions:

- which persistence files own genuinely different wire formats or recovery laws?
- which only specialize the same versioned-row codec pattern?
- can codecs share combinators without erasing format ownership?
- are any persisted fields reconstructable and therefore unnecessary canonical bytes?
- can writer/reader admission be factored without creating a universal serialization framework?

Important: no wire-format change is authorized by this entry.

### SA-007 Application projection fanout

Status: `UNDER_REVIEW`
Priority: high

Current physical surface: 18 modules.

Largest current modules include `ScheduledCommitmentInspection` and `OpenRelationFrontier`, while smaller Inspection/Frontier modules repeat projection vocabulary around the same retained authorities.

Hypothesis: some Application modules are legitimate household questions, while others may be intermediate semantic echoes that can be expressed by a smaller algebra of frontier, selection, and inspection mechanisms.

Audit method:

- classify each module by the household question it answers;
- identify retained information used;
- identify new law introduced;
- identify whether its result is consumed externally or only by another projection;
- merge only when two projections have the same authority and observational behavior.

### SA-008 Scheduled semantic amplification

Status: `UNDER_REVIEW`
Priority: high

Scheduled has a deliberately small Core fact:

```text
ScheduledId + scheduled coordinate + BalancedMovement
```

Production behavior around it now includes memory, terminal lifecycle, routing, inspections, persistence, publishers, continuation routing, reviews, CLI/TUI surfaces.

Question: which of these are necessary independent boundaries and which are repeated orchestration around a small retained fact?

Positive evidence: terminal consolidation and shared continuation routing already reduced duplicated meanings/orchestration.

Formal method: build a dependency graph from retained Scheduled evidence to observable household answers and count independent laws rather than files.

### SA-009 Publisher / Authority / Review semantic echo

Status: `UNREVIEWED`
Priority: high after Persistence/Application

The root `Loam/` surface contains multiple `*Publisher`, `*Authority`, and `*Review` modules for semantic families.

Question: does each own an independent crash/recovery/authority law, or is a common publication protocol repeatedly specialized?

This area must be audited with stronger operational criteria than pure type isomorphism. TLA+ or explicit transition-system reasoning is appropriate when crash/retry/interrupted-publication behavior is involved.

### SA-010 Revision-only identity principle

Status: `UNDER_REVIEW`
Priority: medium

ActualValidityHistory established a useful compression pattern:

> base evidence may reuse the subject identity; allocate a separate fact/revision identity only when a later revision needs independent identity.

Audit other fact-id families for identities that exist from the base case only because historical implementation introduced them.

Formal test:

- compare base identity and revision identity lifecycles;
- find whether two distinct base facts for the same subject must coexist;
- find whether external references target the base fact independently of the subject;
- verify persistence bytes and migration/recovery requirements.

Do not generalize this rule to facts whose base assertions genuinely have independent multiplicity or provenance.

## 8. Semantic amplification metric

Track a qualitative `semantic amplification` signal:

```text
number of first-class declarations/modules/boundaries
----------------------------------------------------
number of independent retained facts and laws
```

A high ratio is an audit smell, not proof of bad design. A semantic fact may legitimately require independent persistence, crash-safe publication, projection, and presentation boundaries.

The useful question is whether each boundary introduces a new invariant or merely repeats plumbing.

## 9. Formal-method toolbox for deletion/compression

Prefer the smallest formal tool appropriate to the claim.

### Lean

Use for:

- representation isomorphisms / round trips;
- derivability proofs;
- observational equivalence of pure projections;
- permutation independence;
- preservation of fail-closed admission;
- commuting diagrams between semantic wrappers and shared mechanics.

### Alloy

Use for:

- searching for two worlds that collapse under a proposed merge but require different answers;
- detecting illegal combinations introduced by separating or merging states;
- bounded counterexamples to alleged derivability;
- testing whether an identity or relation is independently necessary.

### TLA+ / transition models

Reserve primarily for:

- crash/retry/interrupted publication;
- writer ownership;
- multi-step persistence protocols;
- recovery and temporal lifecycle claims.

Do not use a temporal model when a pure Lean theorem or bounded relational counterexample answers the question more directly.

## 10. Implementation gate

An audit entry may become `IMPLEMENTATION_READY` only when the proposed change has explicit answers for all of the following:

```text
[ ] independently observable information preserved
[ ] invalid-state admission is no weaker
[ ] household-visible behavior preserved or intentionally changed
[ ] canonical/wire bytes impact known
[ ] migration requirement known
[ ] crash/retry/recovery impact known where relevant
[ ] semantic authority remains correctly separated
[ ] formal counterexample search/proof appropriate to the claim completed
[ ] production source/mechanism delta is plausibly net simpler
[ ] relevant CI qualification plan identified
```

If the adapters or proof burden become larger than the duplication removed, keep the existing explicit structures.

## 11. Current audit conclusion

The current evidence does **not** support the claim that LOAM has thirty independent Core concepts or that the Core is broadly accidental complexity.

Instead:

1. the semantic kernel contains several strong, already-compressed primitives;
2. some physical Core modules are representations, specializations, or derived projections rather than independent concepts;
3. earlier compression has already reduced Core from 34 to 30 modules;
4. the strongest remaining complexity signal is semantic echo across Persistence, Application, Publisher/Authority/Review, and frontend boundaries;
5. future work should prove which echoes own independent laws before removing them.

The audit should therefore proceed from architecture census to formal counterexample/proof work before any new compression implementation.

## 12. Next audit sequence

No implementation is authorized yet. Refine the ledger in this order:

```text
1. SA-006 Persistence semantic echo
2. SA-007 Application projection fanout
3. SA-002 two-endpoint relation mechanics
4. SA-003 temporal/effective evidence
5. SA-008 Scheduled semantic amplification
6. SA-005 Core public surface
7. SA-009 Publisher/Authority/Review
8. SA-010 revision-only identity sweep
9. SA-004 CorrectionQuantity placement, after caller graph is known
```

For each step, update this ledger with evidence, counterexamples, proofs, and a decision before opening an implementation PR.
