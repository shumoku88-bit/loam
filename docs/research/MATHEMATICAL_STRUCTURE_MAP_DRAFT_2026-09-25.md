# LOAM mathematical structure map — draft 2026-09-25

Status: **QUALIFIED RESEARCH MAP — R1–R6 survey complete / no broad abstraction authorized**

Baseline:

```text
main 8b26bfe8cb953d2543879cbe93570d020d2c7f92
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

**Status: EARNED STRUCTURE**

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

**Status: STRONG CANDIDATE**

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

**Potential payoff:** highest current candidate for combined code compression
and performance improvement  
**Risk:** medium if selection and reduction stay separate; high if merged.

---

## MATH-6 — incidence / linear representation of flows

**Status: EARNED RESEARCH STRUCTURE / STRONG DERIVED CANDIDATE**

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

**Potential payoff:** high for report unification  
**Risk:** medium-high  
**Next research pressure:** identify exactly which current reports factor through
the Transactions-Flow incidence representation.

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

**Status: STRONG DESCRIPTIVE CANDIDATE, UNCLEAR COMPRESSION PAYOFF**

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

**Status: CONCRETE ALGORITHMIC CANDIDATE**

`Loam/ActualJournalProjection.lean` currently implements deterministic journal
ordering through repeated insertion:

```text
sortEntries entries
  = entries.foldl (insertEntry ...) []
```

This is insertion-sort-shaped and therefore has quadratic worst-case comparison
behavior.

Elsewhere, for example Transactions-Flow, LOAM already uses `mergeSort`.

### What may eventually be possible

Replace the implementation with an asymptotically better sort while proving or
testing that:

```text
same input entries
-> same ordering relation
-> same deterministic journal result
```

This is not household-domain algebra, but it is a clean example of using
equational/refinement reasoning to improve performance without changing
semantics.

### Boundary

Do not optimize until this path is measured under a realistic long-history
journal workload.

**Potential payoff:** potentially very high on this one path  
**Risk:** low  
**Priority:** benchmark first.

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

# Candidate research queue

This is deliberately an **observation queue**, not an implementation roadmap.

## R1 — additive fold census

For every production `foldl`, `foldr`, and `foldlM` that produces Quantity
or Int:

1. identify the selector;
2. identify the accumulator algebra;
3. determine whether the result is invariant under permutation;
4. test whether concatenation admits an associative combine law;
5. record whether another production path repeats the same reduction.

Goal: discover genuine homomorphisms rather than invent a generic fold library.

## R2 — report factorization map

For:

- Balance;
- Stock-Flow;
- Transactions-Flow;
- Role Flow;
- Merchant Expense;
- Consumption;
- Capacity / Remaining / Headroom;
- Daily Pace;

record the smallest already-derived image each report needs.

Goal: identify reports that can share one transient summary without sharing
semantic authority.

## R3 — temporal change-point experiment

For `RoutingHistory.statusAt`:

- characterize observational equivalence of histories;
- identify redundant change points, if any;
- compare list fold against an ordered transient index;
- prove or test exact answer correspondence.

No persistence change.

## R4 — long-journal sorting pressure

Benchmark `ActualJournalProjection` at large current-frontier sizes before any
algorithm change.

If quadratic behavior is visible, qualify a merge-sort implementation against
the current ordering result.

## R5 — observational sufficiency test

**Status: QUALIFIED ON MERCHANT EXPENSE via Observation 336**

Merchant Expense supplies the first production-shaped witness.

For the scalar `exactTotal?` observation, a research image containing only
`knownTotal` and one `complete` bit is sufficient. Observation 336 proves the
answer factors through that image in the Observation 191 sense.

The same image is deliberately insufficient for the inspectable diagnostic
surface: it cannot distinguish unresolved Merchant classification from
unresolved AccountingRole classification, while the production Snapshot can.

Result:

```text
one observation may admit a much smaller sufficient image
without that image being sufficient for the whole report surface
```

No production replacement is authorized by this result.

## R6 — information-order counterexample search

**Status: QUALIFIED COUNTEREXAMPLE via Observation 337**

ActualValidityHistory supplies the required counterexample.

A raw append-extension can add only fresh, storage-admissible validity evidence
and still move the semantic validity projection from defined to fail-closed by
creating an ambiguous sibling correction frontier.

Thus ordinary raw evidence extension is not a monotone semantic-information
order.

R6 is complete for the repository-wide question. No global `PartialOrder`,
lattice, or fixed-point abstraction is earned. Narrow domain-specific orders
remain possible only when their relation already encodes admissible refinement.

---

# Current provisional ranking

This ranking is about **research leverage**, not implementation priority.

| Area | Evidence strength | Possible code compression | Possible performance gain | Semantic risk |
| --- | --- | --- | --- | --- |
| Windowed/additive folds | strong | high | high | medium |
| Incidence/additive image | strong | medium-high | high | medium-high |
| Temporal change points | strong | medium | medium-high | medium |
| Replacement/frontier | very strong | mostly realized | already demonstrated | low if narrow |
| Finite keyed memory | very strong | mostly realized | medium | low if narrow |
| Observational factorization | strong research | indirect | indirect | low as research |
| Sorting refinement | concrete | low | potentially high | low |
| Lifecycle state machines | moderate | uncertain | low-medium | medium |
| Normalization laws | moderate | medium | medium | medium |
| Lattice/fixed point | weak/currently speculative | unknown | unknown | high |

---

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


## MATH-5 follow-up — Daily Pace finite-vector history

**Status: MEASURED — PRODUCTION PROMOTION EARNED**

`CycleSpendingPaceReview.projectHistory` currently reconstructs the Actual-backed
eligible pool by validating selected current Actual records once and then
rescanning all Actual records once per requested history date.

A temporary paired benchmark compared that shape with one finite-vector fold:
each current selected Event is quantified once, validated once, and its signed
quantity is distributed to every requested date at or after the Event date.

The benchmark required exact result equality before accepting timings. Batched
forced evaluation on the same runner produced:

| history days | Actual records | repeated scans | finite-vector fold | speedup |
| ---: | ---: | ---: | ---: | ---: |
| 7 | 1,000 | 10.4 ms | 5.4 ms | 1.91x |
| 7 | 5,000 | 52.8 ms | 26.7 ms | 1.97x |
| 7 | 10,000 | 103.6 ms | 53.2 ms | 1.94x |
| 30 | 1,000 | 31.6 ms | 10.6 ms | 2.98x |
| 30 | 5,000 | 158.6 ms | 53.0 ms | 2.99x |
| 30 | 10,000 | 315.6 ms | 106.5 ms | 2.96x |
| 90 | 1,000 | 86.7 ms | 24.2 ms | 3.57x |
| 90 | 5,000 | 434.4 ms | 120.2 ms | 3.61x |
| 90 | 10,000 | 864.8 ms | 239.5 ms | 3.61x |

The current Home surface asks for seven days, so the production-relevant result
is already about a twofold improvement at large Actual frontiers. Longer
hypothetical horizons show increasing benefit.

This earns a narrow production change to the Actual-backed history calculation.
It does **not** authorize a retained index, persistent prefix table, or a generic
window-query framework. Scheduled historical deductions remain outside this
promotion because their terminal/completion semantics are distinct.

The temporary benchmark source and workflow were retired after this result was
harvested; Git history retains the executable measurement apparatus.


## MATH-6 second-pass follow-up — shared sparse row image pressure

**Status: MEASURED — NO FURTHER PRODUCTION PROMOTION EARNED**

After the Web current snapshot began sharing one selected
`TransactionsFlowReview.Snapshot` between Transactions Flow and Role Flow, the
second MATH-6 pass found one remaining structural duplication:

```text
TransactionsFlowReview.Snapshot.columns
    -> Snapshot.rowActivities
    -> Transactions Flow presentation

TransactionsFlowReview.Snapshot.columns
    -> Snapshot.rowActivities
    -> RoleFlow classification
```

The same derived `rowActivities` image also appears repeatedly inside the TUI
Transactions Flow presentation path. This is a genuine stage-2 factorization
opportunity: selected Columns remain authority, while the sparse
`EffectCoordinate -> RowActivity` image is transient derived mechanics.

A temporary paired benchmark therefore compared two independent
`rowActivities` constructions with one construction shared by two consumers.
Fixture size was supplied at runtime so the benchmark input was not a closed
compile-time constant. Every fixture retained two Effects per Event and the
benchmark required equal forced row digests before accepting timings.

On the same GitHub Actions runner:

| selected Events | duplicate construction | shared construction | observed ratio |
| ---: | ---: | ---: | ---: |
| 1,000 | 86 µs | 85 µs | ~1.01x |
| 5,000 | 88 µs | 86 µs | ~1.02x |
| 10,000 | 84 µs | 87 µs | ~0.97x |
| 25,000 | 87 µs | 86 µs | ~1.01x |

No meaningful scaling or speed difference was observed over this range. The
structural duplication is real, but current production pressure does not justify
adding retained derived state, a generic report cache, or a wider shared-image
abstraction merely to remove it.

The MATH-6 boundary remains:

- keep selected Transactions-Flow Columns as the evidence authority;
- keep `rowActivities` transient and derived;
- allow narrow orchestration sharing when it is already natural, as in the Web
  Transactions-Flow Snapshot reuse;
- do not add new caching/state without measured pressure or net source/proof
  reduction;
- keep Merchant Expense separate because it observes Event identity, Merchant
  evidence, and unresolved role witnesses that the row image forgets.

The temporary benchmark source and workflow are retired after harvesting this
negative result. Git history retains the executable measurement apparatus.
