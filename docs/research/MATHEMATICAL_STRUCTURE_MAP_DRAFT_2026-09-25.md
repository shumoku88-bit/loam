# LOAM mathematical structure map — draft 2026-09-25

Status: **QUALIFIED RESEARCH MAP — R1–R6 survey and second production-pressure pass complete / no broad abstraction authorized**

Survey baseline:

```text
main 8b26bfe8cb953d2543879cbe93570d020d2c7f92
```

Second-pass harvest checkpoint:

```text
main b32058d0d22b1b6d77a05a76a620ce1b8254583f
through PR #1346
```

## Question

Where does LOAM already contain recurring mathematical structure, and where might
that structure eventually help with:

- proof reuse;
- code compression;
- asymptotic improvement;
- incremental computation;
- clearer separation between retained evidence and derived projections?

This document is **not** an implementation plan.

It does not authorize introducing Mathlib, category theory, generic algebraic
typeclasses, a new persistence representation, or a broad rewrite. The working
rule remains the existing LOAM design philosophy:

```text
share algebra and mechanics
preserve semantic authority
```

The map therefore distinguishes:

- **earned structure** — already present and qualified in production/research;
- **strong candidate** — repeated current code gives concrete pressure;
- **research candidate** — mathematically plausible, but not yet earned;
- **boundary / no-go** — similarity exists but current evidence says not to merge it.

## Repository-scale observation

At this baseline the repository contains roughly:

```text
506 Lean files
35  Loam/Core modules
20  Loam/Application modules
38  Review/Inspection-shaped top-level/report modules
17  Persistence modules
```

The important observation is not file count. LOAM has already shown that a
physical module count is much larger than its independent semantic concept
count.

Compression Audit Phase 3 is a binding prior result for this map. It already
rejects several tempting large abstractions:

```text
NO generic Memory ontology
NO generic serializer/schema framework
NO generic transaction/publisher framework
NO global identity service
NO generic revision/history framework
NO generic authority/image framework
```

Any mathematical compression proposed later must stay below those semantic
boundaries unless new evidence overturns them.

---

# Draft map

## MATH-1 — finite additive image

**Status: EARNED / ACTIVE PRODUCTION IMAGE**

Representative modules:

- `Loam/Core/Quantity.lean`
- `Loam/Core/Event.lean`
- `Loam/Core/EventMemory.lean`
- `Loam/Core/BalancedMovement.lean`
- `Loam/Core/Capacity.lean`
- `Loam/TransactionsFlowReview.lean`
- `Loam/StockFlowReview.lean`

Existing research:

- Observation 159 — free-Abelian projection boundary
- Observation 233 — Transactions-Flow incidence matrix
- Observation 250 — Ledger denotation boundary

Second-pass production harvest:

- PR #1333 factored the repeated admitted Capacity window additive scan;
- PR #1337 promoted the measured Daily Pace finite-vector history fold;
- PR #1346 promoted one transient `Effect.measureTotals` image shared by
  normalized Actual ordinary-Event balance admission, Beancount export, and
  plain-text accounting export;
- #1346 removed 22 net production/refactor lines while keeping independent
  Measures separate and leaving exact-reversal proof-carrying balance on its
  existing path.

For a fixed coordinate space and Measure, many LOAM projections have the shape:

```text
finite retained effects
    -> coordinate-wise signed integer totals
    -> selected report observation
```

Observation 159 already identifies the finite additive image with a
free-Abelian-style finitely supported integer vector, while explicitly refusing
to quotient retained Event / Effect identity or provenance.

### What may eventually be possible

1. Reuse one family of additive laws across Balance, Consumption, Capacity,
   Stock-Flow, Transactions-Flow, and other report calculations.
2. Separate report computation into:
   ```text
   semantic selection
       -> additive image
       -> presentation
   ```
3. Prove selected aggregators satisfy a concatenation law:
   ```text
   F(xs ++ ys) = F(xs) ⊕ F(ys)
   ```
   when the selector/context is fixed.
4. If such a law is earned, derive chunked, incremental, or parallel evaluation
   without changing canonical authority.
5. Compute several report totals from one transient coordinate aggregate instead
   of repeatedly traversing the same Event/Effect lists.

### Main boundary

Do **not** identify retained evidence merely because additive projections agree.

```text
same quantity image
    !=
same Event identity / Effect identity / provenance / correction history
```

Independent Measures also remain separate.

**Potential payoff:** very high  
**Risk of semantic over-compression:** high  
**Next research pressure:** classify current folds by whether they are genuinely
homomorphic after semantic selection is fixed.

---

## MATH-2 — finite keyed-set mechanics

**Status: EARNED / MATURE**

Representative module:

- `Loam/Core/FiniteKeyed.lean`

Representative users:

- EventMemory
- ScheduledMemory
- CapacityMemory
- AttentionMemory
- ActualValidityMemory

Current qualified mathematics already includes:

- projected-key `Nodup`;
- lookup invariant under representation permutation;
- fresh append preserves uniqueness;
- transient HashMap lookup is extensionally equal to canonical List lookup.

### What may eventually be possible

Only narrow proof/mechanics reuse as new keyed memories appear.

### Boundary

Compression Audit Phase 3 already rejects turning this into a universal
`Memory α` household ontology.

**Potential payoff:** medium, mostly proof/code subtraction  
**Risk:** low if kept mechanical  
**Priority:** low, because the strongest useful extraction already exists.

---

## MATH-3 — finite partial successor / replacement structure

**Status: EARNED / MATURE**

Representative modules:

- `Loam/Application/ReplacementFrontier.lean`
- `Loam/Application/CorrectionFrontierSemantics.lean`
- `Loam/Application/CorrectionFrontierIndexed.lean`
- `Loam/Application/ActualValidityFrontier.lean`
- `Loam/Application/ScheduledInspection.lean`

Current structure is approximately:

```text
finite directed successor relation
+ unique sources
+ unique successors
+ reference closure
+ acyclicity
-> admitted frontier
```

This is already one of LOAM's clearest examples of mathematics supporting both
compression and performance. List/reference specifications coexist with
HashMap/HashSet implementations connected by correspondence proofs.

### What may eventually be possible

- reuse further indexed algorithms when a concrete repeated traversal is measured;
- derive stronger complexity guarantees for the admitted partial-injection domain.

### Boundary

Do not generalize it into a universal revision/history ontology. Multi-parent
resolution, retraction, routing, and temporal validity have distinct semantics.

**Potential payoff:** medium  
**Current maturity:** high  
**Priority:** pressure-driven only.

---

## MATH-4 — temporal change-point selection

**Status: MEASURED / PRODUCTION DEFERRED AT CURRENT SCALE**

Representative modules:

- `Loam/Core/HistoricalRouting.lean`
- `Loam/Core/RoutingEffective.lean`
- Actual routing users
- Scheduled routing users

Historical routing is already a precise algebra:

```text
unique (subject, effectiveOn)
+ linear order on effective coordinate
+ latest visible assertion
-> managed / unmanaged / unrouted
```

Selection is proved invariant under representation permutation. The effective
coordinate even has an explicit least `initial` point rather than fabricating a
date.

This looks naturally like a finite **change-point representation of a
piecewise-constant function over ordered time**.

### What may eventually be possible

1. Prove an ordered/indexed lookup implementation equivalent to the existing
   list fold.
2. Build a transient per-subject ordered index for repeated historical queries.
3. State change-point compression laws: intermediate representation changes that
   preserve every `statusAt subject time` observation.
4. Reuse the same temporal selection laws without merging Actual and Scheduled
   routing authority.

### Boundary

Time order is semantic; list order is not. `initial` is observably distinct
from the first dated coordinate.

**Potential payoff:** medium-high for repeated historical queries  
**Risk:** medium  
**Current pressure checkpoint:** Actual routing administration does issue same-time bulk queries, and a 28-subject / 29-entry production-shaped benchmark measured about 1.88x faster status selection through the transient image. The absolute saving was only about 178 µs while a proved production trial added about 243 net production/proof/test lines, so promotion remains deferred until the absolute workload becomes materially larger.

---

## MATH-5 — windowed additive queries

**Status: EARNED / NARROW PRODUCTION PROMOTIONS HARVESTED**

Representative modules:

- `Loam/Application/ConsumptionInspection.lean`
- `Loam/Application/CapacityWindowInspection.lean`
- `Loam/StockFlowReview.lean`
- `Loam/TransactionsFlowReview.lean`
- `Loam/MerchantExpenseReview.lean`
- `Loam/CycleSpendingPaceReview.lean`

A recurring computational shape is:

```text
admitted world
    -> select by currentness / date / routing / role / purpose
    -> project exact Quantity
    -> additive fold
```

The semantic selectors differ, but the reducer is repeatedly integer addition.

Examples include:

- Event/Effect coordinate totals;
- Consumption;
- Entitlement;
- Stock-Flow boundary reconstruction;
- Transactions-Flow row totals;
- Merchant known totals;
- Daily Pace pools and deductions.

### What may eventually be possible

- distinguish **selector laws** from **reducer laws** explicitly;
- share proofs for additive reducers without sharing semantic selectors;
- fuse multiple folds over the same admitted image;
- derive prefix/window summaries or incremental views when the selection law
  permits it;
- identify which queries are list homomorphisms and which require richer summary
  state.

External algorithmic literature gives this question a precise shape: list
homomorphisms are functions for which a concatenation law with an associative
combiner exists, enabling divide-and-conquer evaluation. Incremental view
maintenance studies the related problem of updating derived queries from deltas
rather than recomputing whole inputs.

### Boundary

Correction selection, routing, date validity, role completeness, and merchant
coverage are not additive facts. They remain upstream admission/selection
semantics.

Second-pass production results:

- PR #1333 unified duplicated Capacity window folds behind one admitted selector
  boundary;
- PR #1337 replaced repeated Daily Pace Actual-history rescans with one
  finite-vector fold after measurement showed about 1.9–2.0x at seven days,
  about 3x at 30 days, and about 3.6x at 90 days;
- the final additive census found no further production site with the same
  selector and reducer pressure strong enough to justify a wider window-query
  framework.

**Current payoff:** harvested where concrete duplication or measured repeated
work existed  
**Risk:** medium if selection and reduction stay separate; high if merged  
**Reopen when:** a new consumer repeats the same selected additive image or a
measured window path shows material repeated work.

---

## MATH-6 — incidence / linear representation of flows

**Status: EARNED / PRODUCTION DERIVATION PROMOTED / FURTHER CACHE DEFERRED**

Representative modules:

- `Loam/TransactionsFlowReview.lean`
- `Loam/StockFlowReview.lean`

Existing Observation 233 already qualifies:

```text
row    = (LocusId, MeasureId)
column = Event
cell   = exact signed Quantity
```

This is an incidence-style matrix without inventing source/destination edges.

### What may eventually be possible

- derive row totals, residuals, Stock-Flow summaries, and selected report views
  from one transient sparse matrix/vector representation;
- exploit sparse-coordinate algorithms;
- use matrix language to expose which reports are merely different linear
  projections of the same selected Event world.

### Boundary

No invented transfer edges, no cross-Measure addition, no automatic accounting
role from sign, and no loss of retained Effect identity in canonical evidence.

Second-pass production results:

- PR #1321 promoted the seedless bulk `Snapshot.rowActivities` projection;
- PR #1338 reused one selected Transactions-Flow Snapshot across Web
  Transactions Flow and Role Flow;
- PR #1340 shared the Income & Expense Measure summary, removing 19 net
  production lines;
- PR #1339 measured an additional shared-row-image cache and found essentially
  no gain across 1,000–25,000 selected Events, so no retained cache or broader
  report-image abstraction was added.

Merchant Expense remains separate because it observes Event identity, Merchant
coverage, AccountingRole resolution, and unresolved witnesses that the sparse
row image forgets.

**Current payoff:** narrow report factorization already harvested  
**Risk:** medium-high if the image is allowed to replace richer witnesses  
**Reopen when:** another consumer can prove factorization through the existing
transient image and removes measurable work or net source/proof.

---

## MATH-7 — observational equivalence and factorization

**Status: EARNED RESEARCH TOOL / DO NOT PROMOTE YET**

Existing research:

- Observation 159 — vector equivalence
- Observation 179 — preservation polarity
- Observation 180 — observational closure
- Observation 191 — quotient factorization

LOAM already has a useful meta-question:

```text
Which retained differences can this projection observe?
```

A selected observation family induces an equivalence relation over richer
evidence. This can be used as a **compression test**:

```text
candidate summary S is sufficient for report R
iff
R cannot distinguish evidence values that S identifies
```

### What may eventually be possible

Use observational factorization to justify that a transient summary contains
exactly enough information for a report, or to prove that a proposed compression
would erase something observable.

This may be more useful as a research method than as production code.

### Boundary

Do not introduce quotient types, Galois frameworks, or generic observation
machinery merely because the mathematics exists.

**Potential payoff:** high for deciding what may safely be forgotten  
**Direct runtime payoff:** low  
**Risk:** low as research, high as premature architecture.

---

## MATH-8 — information order / lattice / fixed-point readings

**Status: GLOBAL RAW-EVIDENCE ORDER REJECTED BY COUNTEREXAMPLE**

Observation 337 tests the simplest candidate reading:

```text
less retained raw evidence <= more retained raw evidence
```

using append-only Actual-validity provenance.

The base history contains one admitted correction path:

```text
root -> revision-1
```

The extended history appends one fresh revision fact and one fresh exact
correction edge:

```text
root -> revision-1
     \
      -> revision-2
```

Both raw histories satisfy their storage-level uniqueness invariants. The base
semantic validity frontier is defined, while the extended semantic frontier
fails closed because sibling successors do not justify one current date.

Therefore:

```text
more retained raw provenance
    !=
more semantically admitted information
```

A repository-wide information lattice must not be inferred from raw evidence
inclusion or append-extension.

### Boundary

This does not rule out narrower domain-specific partial orders. A future order
would have to encode its own admissible-refinement relation rather than equating
evidence quantity with semantic information.

**Potential payoff:** domain-specific only  
**Risk of theory-first design:** confirmed high  
**Priority:** no global lattice/fixed-point abstraction.

---

## MATH-9 — lifecycle state machines

**Status: DESCRIPTIVE / NO SHARED CODE COMPRESSION EARNED AT CURRENT PRESSURE**

Representative domains:

- Scheduled occurrence / completion / retirement / replacement;
- Attention item / closure;
- publication/recovery protocols.

`ScheduledInspection` already distinguishes terminal meanings and explicit
failure states. This can be viewed as a finite transition system with guarded
edges.

### What may eventually be possible

- prove reachability / impossibility properties;
- state transition preservation across persistence/writer implementations;
- use TLA+/Alloy models as executable counterexample search before Lean
  promotion.

### Boundary

A common state-machine vocabulary does not mean Scheduled, Attention, Actual
correction, and writer publication are one lifecycle.

**Potential payoff:** high for assurance, uncertain for LOC reduction  
**Priority:** medium for protocol questions, low for generic code extraction.

---

## MATH-10 — sorting and order-preserving algorithm refinement

**Status: MEASURED / PRODUCTION PROMOTED**

Observation 335 qualified the exact refinement boundary between the former
fold-of-insertion sorter and `List.mergeSort`: both retain the same input
multiset and produce the same ordered result on the reachable Actual domain,
where EventId uniqueness discharges the otherwise-dangerous equal-key case.

The paired benchmark then measured:

| current entries | insertion sort | mergeSort | speedup |
| ---: | ---: | ---: | ---: |
| 250 | 6.7 ms | 581 µs | 11.58x |
| 1,000 | 105.2 ms | 3.0 ms | 34.62x |
| 4,000 | 1.6 s | 16.8 ms | 96.18x |
| 8,000 | 6.5 s | 36.6 ms | 178.90x |

PR #1326 promoted the narrow substitution. Production
`ActualJournalProjection.sortEntries` now uses `mergeSort` with the same
date-then-EventId ordering. No retained sorted state or generic sorting
framework was introduced.

Observation 335 remains live because it is the theorem witness for the promoted
algorithmic refinement.

**Current payoff:** large asymptotic improvement on one measured path  
**Risk:** low while the ordering relation and reachable no-distinct-ties
invariant remain unchanged  
**Reopen when:** another production sorter exhibits independently measured
pressure.

---

## MATH-11 — normalization / canonical-image laws

**Status: QUALIFIED / NARROW COMPRESSION HARVESTED**

Representative modules:

- `Loam/Persistence/VersionedRows.lean`
- `Loam/Persistence/NormalizedActualPersistence.lean`
- `Loam/Persistence/NormalizedCapacityPersistence.lean`
- proof-carrying admitted evidence types.

The useful result is not one repository-wide notion of normalization. Three
different shapes are now distinguished.

### 1. Exact framing round trip

`VersionedRows` already proves that framing rows and immediately decoding the
same newline-safe frame returns exactly the original row list:

```text
rows
  -> encodeVersionedRows
  -> decodeVersionedRows?
  -> same rows
```

This is representation mechanics only.

### 2. Actual wire canonicalization can collapse selected representation order

Observation 338 used the production normalized-Actual decoder, full semantic
admission, and encoder. Two admitted wires with the same Effect order and facts,
but different interleaving of row families, converged to one encoder-selected
wire. Reapplying decode/encode to that image was a fixed point.

The result is deliberately local. It does not establish permutation freedom for
Event order, Effect order, revision order, Relation order, or Discharge order.

Observation 338 was harvested from the live Lean umbrella after this conclusion
was recorded. Its executable proof remains in Git history through PR #1342.

### 3. Capacity has a semantic admission fixed point, not global wire canonicalization

Observation 339 proved for every already-admitted `CapacityEvidence` that:

```text
CapacityEvidence.ofParts?
  evidence.movements
  evidence.effective
= some evidence
```

The law follows directly from the `complete` proof carried by the type.

At the wire level, however, two valid Capacity documents with reversed Movement
order remained two distinct decode/encode fixed points. The normalized Capacity
codec therefore preserves that order rather than selecting one global
permutation-normal form.

Observation 339 was harvested from the live Lean umbrella after the general law
and the wire-order boundary were recorded. The proof remains in Git history
through PR #1343.

### Production compression harvested

The cross-family audit found four hand-written recursive row traversals in
`LocusAdmissionPersistence` and `ZeroOriginCoveragePersistence` that were
exactly the existing `List.mapM` behavior already used by neighboring codecs.

PR #1344 replaced those helpers directly:

```text
+4 / -32
= 28 production lines net removed
```

No generic persistence framework, authority change, row-order change, or wire
change was introduced.

### Stop conditions

Current remaining persistence families do not justify a wider abstraction:

- Actual and Scheduled routing have visibly different subject/time syntax and
  authority meaning despite sharing `RoutingHistory`;
- Attention and CurrentQuantityAnchor expose some family-grouping
  canonicalization, but no current production duplication is removed by naming
  that law;
- Scheduled lifecycle has three physical terminal sections, but collapsing their
  small codecs would hide Completion / Retirement / Replacement distinctions
  for only a few lines of source reduction.

Therefore MATH-11 currently supports **local fixed-point/canonical-image laws and
small mechanical subtraction**, not a universal normalization API.

### Boundary

Persistence, filesystem behavior, malformed input, version compatibility, and
crash recovery remain runtime/test obligations. A pure normalization theorem
does not replace IO qualification.

**Potential payoff:** harvested at current pressure  
**Risk:** low while laws remain family-local  
**Next pressure:** reopen only when a concrete consumer repeats admission or a
second codec duplicates enough mechanics to produce net code/proof reduction.

---

## MATH-12 — UI/runtime refinement

**Status: EARNED / SEPARATE FROM HOUSEHOLD MATHEMATICS**

The existing Lean language-power audit already records refinement theorems for:

- pure Screen vs DenseScreen;
- list vs array lookup;
- diff application;
- compiled widget semantics;
- dirty-row rendering.

This is an important proof pattern:

```text
simple specification
    ≡
optimized representation
```

but it is not evidence that household domains should share a new algebra.

It should remain a positive example of optimization-by-refinement.

---

# Cross-cutting decomposition hypothesis

The strongest current whole-system hypothesis is not one grand algebra.

It is a **three-stage decomposition**:

```text
1. semantic admission / selection
   correction, routing, time, role, provenance, completeness
                |
                v
2. compact mathematical image
   finite keyed set / partial successor relation /
   additive coordinate vector / temporal change-point view
                |
                v
3. observation / presentation
   balance, flow, stock-flow, merchant, pace, UI/export
```

Most dangerous abstractions try to merge stage 1.

Most promising mathematical compression appears in stage 2.

Most repeated computation appears where stage 3 independently rebuilds similar
stage-2 summaries.

That suggests a useful future research rule:

> Search first for a smaller mathematical image that several projections can
> share, but prove that each projection factors through it before changing
> production representation.

---

# Second-pass outcome ledger

The original R1–R6 queue has been executed. It is retained here as a compact
outcome ledger rather than an open implementation roadmap.

| Pass | Outcome |
| --- | --- |
| R1 additive fold census | **Complete.** Capacity fold sharing (#1333), Daily Pace finite-vector promotion (#1337), and shared Effect Measure totals (#1346) were harvested. No further same-selector/same-reducer production duplication currently earns abstraction. |
| R2 report factorization | **Complete at current pressure.** Stock-Flow scan fusion (#1323), Transactions-Flow bulk row activity (#1321), Web snapshot reuse (#1338), and Income & Expense summary sharing (#1340) were promoted. Additional row-image caching measured neutral (#1339). |
| R3 temporal change points | **Measured / deferred.** Current Actual routing shape measured about 1.88x faster through a transient fixed-time image, but only about 178 µs absolute saving for about 243 added production/proof/test lines (#1341). |
| R4 journal sorting | **Promoted.** Observation 335 + benchmark qualified merge sort; PR #1326 replaced quadratic-shaped insertion mechanics. |
| R5 observational sufficiency | **Qualified research tool.** Observation 336 proves one smaller Merchant scalar image is sufficient for `exactTotal?`, but insufficient for the full diagnostic surface. |
| R6 information order | **Counterexample complete.** Observation 337 rejects raw-evidence append/inclusion as a repository-wide semantic information order. |

The queue reopens only from new production pressure. A mathematical resemblance
alone is not a reason to add architecture.

# Current second-pass disposition

This replaces the earlier research-leverage ranking with the current disposition.

| Area | Current disposition | Next trigger |
| --- | --- | --- |
| MATH-1 additive image | production image shared narrowly | duplicated same-selector additive fold or measurable repeated work |
| MATH-2 finite keyed sets | mature | new keyed memory with repeated mechanics |
| MATH-3 frontier / replacement | mature | measured repeated traversal |
| MATH-4 change points | measured, deferred | materially larger routing history/query batch |
| MATH-5 windowed additive queries | narrow promotions harvested | new same-selection window pressure |
| MATH-6 incidence image | production derivation promoted; wider cache rejected | new factorizing consumer with measurable benefit |
| MATH-7 observational equivalence | keep as research decision tool | proposed lossy summary/compression |
| MATH-8 lattice/information order | global raw-evidence order rejected | domain-specific admissible-refinement relation |
| MATH-9 lifecycle machines | descriptive only | concrete protocol/reachability question |
| MATH-10 sorting refinement | production promoted | another measured sorter |
| MATH-11 normalization | narrow laws and code subtraction harvested | repeated admission/codec mechanics |
| MATH-12 UI/runtime refinement | mature separate refinement pattern | measured UI/runtime representation pressure |

# External correspondence notes

Two external research families line up with current LOAM pressure without
dictating its architecture:

1. **List homomorphisms / constructive algorithmics** study functions satisfying
   a concatenation law with an associative combiner. Such functions admit
   divide-and-conquer evaluation and are a useful vocabulary for R1.
2. **Incremental View Maintenance** studies when a derived query can be updated
   from changes rather than recomputed from the complete input. This gives a
   useful comparison point for R1/R2, but LOAM must preserve its own
   authority/evidence semantics rather than importing a database view model.

These are comparison lenses only.

---

# Stop conditions

Do not proceed from this map directly to production abstraction.

A candidate earns implementation only if a later observation supplies at least
one concrete benefit:

```text
measured repeated work removed
or
net production source/proof reduction
or
a duplicated universal law becomes one reusable theorem
or
a practical answer becomes derivable without new retained state
```

and also demonstrates that no currently observable semantic distinction is
collapsed.

Until then, this file is a map of possible terrain, not a construction order.

## Second-pass closure — 2026-09-26

The second repository-wide mathematical pass is complete at current production
pressure.

Concrete harvested changes include:

- PR #1321: bulk Transactions-Flow sparse row activity;
- PR #1323: fused selected Stock-Flow record scan;
- PR #1326: qualified journal merge-sort promotion;
- PR #1333: shared admitted Capacity window fold;
- PR #1337: Daily Pace finite-vector history computation;
- PR #1338: shared Web Transactions-Flow snapshot;
- PR #1340: shared Income & Expense summary, 19 production lines net removed;
- PR #1344: persistence row traversal collapse, 28 production lines net removed;
- PR #1346: shared Effect Measure additive image, 22 production/refactor lines
  net removed.

Those last three source-subtraction PRs alone remove at least 69 net
production/refactor lines while reducing duplicated mathematical work.

Research compaction also remained part of the pass. PR #1345 harvested MATH-11
and removed 193 net lines of completed research scaffolding while preserving the
conclusions in this map and the executable history in Git.

Equally important are the explicit non-promotions:

- no fixed-time routing index at the present scale;
- no retained Transactions-Flow row cache;
- no global raw-evidence lattice;
- no universal normalization framework;
- no merging of semantically distinct report, routing, or lifecycle authorities.

The current repository-wide pattern is therefore stable:

```text
semantic admission / selection
        ->
small transient mathematical image
        ->
observation / presentation
```

Further mathematical work should now be pressure-driven rather than map-driven.


## Survey completion and compaction — 2026-09-26

The R1–R6 survey is complete.

The exploratory census and factorization drafts served as working notebooks
while the repository moved from candidate structure to qualified proofs,
measurements, production refinements, and explicit no-go boundaries.

Their durable outcomes now live in:

- this mathematical structure map;
- retained terminal Lean observations;
- production code and regression tests;
- the focused Stock-Flow, temporal-routing, and journal-sort harvest records;
- Git history for retired intermediate proofs and working notes.

Accordingly, the following working drafts are retired from the live tree:

```text
ADDITIVE_FOLD_CENSUS_DRAFT_2026-09-25.md
REPORT_FACTORIZATION_DRAFT_2026-09-25.md
```

This is repository compaction, not evidence erasure. The working documents remain
recoverable from Git history, while the live repository keeps the conclusions
that still guide implementation or future research.

Observation 332 is likewise retired as an intermediate Stock-Flow support-index
experiment. Production adopted the one-scan Record fusion but not a retained or
mandatory selected-coordinate HashMap. Observation 333 remains the terminal
Stock-Flow proof witness and now carries its simple List-membership quantity
helper directly.


## Second-pass measurement appendix

Two benchmark conclusions are worth retaining in the live map.

### Daily Pace finite-vector history

PR #1337 was promoted after exact-result paired measurements showed the
single-scan finite-vector history fold improving over repeated Actual rescans by
about:

- **1.9–2.0x** for the current seven-day Home horizon;
- **~3.0x** at 30 days;
- **~3.6x** at 90 days.

At 10,000 Actual records, representative timings were 103.6 ms → 53.2 ms
(seven days), 315.6 ms → 106.5 ms (30 days), and 864.8 ms → 239.5 ms
(90 days).

The promotion remains narrow: no retained prefix table, persistent index, or
generic window-query framework.

### Shared Transactions-Flow row image

PR #1339 measured constructing `rowActivities` twice versus constructing it
once and sharing the result. Across 1,000–25,000 selected Events the observed
ratio stayed roughly **0.97x–1.02x**, i.e. effectively neutral.

Therefore the sparse row image remains transient and derived. Selected Columns
remain authority, and no retained report cache or wider shared-image abstraction
was added.

The temporary benchmark programs and workflows for both experiments were
retired after harvesting. Full executable detail remains in Git history.
