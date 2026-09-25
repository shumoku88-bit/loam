# LOAM additive fold census — draft 2026-09-25

Status: **RESEARCH DRAFT — observation only / no implementation authorized**

Baseline production:

```text
main 8b26bfe8cb953d2543879cbe93570d020d2c7f92
```

Companion map:

- `docs/research/MATHEMATICAL_STRUCTURE_MAP_DRAFT_2026-09-25.md`

## Question

Which current LOAM folds that produce `Int`, `Quantity`, or small exact
quantity summaries are instances of the same additive/compositional shape?

The goal is not to create a generic fold framework. The goal is to discover
where production currently repeats the same mathematics, and where a future
proof, transient summary, or algorithmic refinement might remove repeated work
without merging semantic authority.

## Scope and method

This pass inspected production-shaped `foldl`, `foldr`, `foldlM`, and
selected `.sum` uses in Core, Application, review/report, publication,
export, presentation, and CLI code.

It deliberately excludes:

- parser state machines whose accumulator is not a quantity summary;
- TUI input/event folds;
- tests and historical observations except as prior evidence;
- persistence framing;
- generic collection folds whose purpose is not arithmetic.

The classification below is structural. "Homomorphism candidate" means the
current function appears to have a concatenation/combine law **for fixed query
context**. It is not a theorem until separately qualified.

---

# Fold classes

## A — pure additive fold

Shape:

```text
item -> Int
List item -> sum
```

Candidate law:

```text
F(xs ++ ys) = F(xs) + F(ys)
```

Order should be observationally irrelevant.

## B — fixed-selector additive fold

Shape:

```text
item -> if predicate(item, fixedContext)
        then contribution(item, fixedContext)
        else 0
List item -> sum
```

For a fixed query context this is still a strong additive-homomorphism candidate.

The selector itself may carry important household semantics and must not be
abstracted away merely because the reducer is addition.

## C — fail-closed additive fold

Shape:

```text
item -> Option contribution
List item -> Option total
```

A missing prerequisite aborts the complete answer.

A possible combine law would need a lifted carrier such as:

```text
some a ⊗ some b = some (a + b)
none   ⊗ _      = none
_      ⊗ none   = none
```

That is only a research candidate. The failure meaning must remain visible.

## D — product / keyed summary fold

The accumulator contains more than one additive component:

```text
(Int × Int)
(Int × Int × Nat)
finite key -> Int
```

These may still be compositional, but the combine operation is product-wise or
key-wise rather than scalar addition.

## E — order-sensitive or non-additive fold

A useful negative control. Examples include "take the last value" or folds whose
meaning depends on the accumulator's ordered history.

These should not be forced into the additive bucket.

## F — already-indexed additive refinement

The repository already contains a direct-list semantic aggregate and a faster
transient index with a correspondence theorem. This is the strongest existing
example of the research direction.

---

# Census

| Location / function | Class | Fixed selector / contribution | Order status | Existing proof/evidence | Research note |
| --- | --- | --- | --- | --- | --- |
| `Core.Event.quantityAt` | B | exact EffectCoordinate | proven insensitive | `quantityAt_perm` | canonical coordinate projection |
| `Core.EventMemory.quantityAtRecorded` | A/B | Event -> `Event.quantityAt` | proven insensitive | `quantityAtRecorded_perm` | strong append-law candidate |
| `Core.BalancedMovement.movementTotalQuanta` | A | all changes | additive by definition | append law appears in reversal proof support | archetypal scalar fold |
| `Core.BalancedMovement.quantityAt` | B | one coordinate | expected insensitive | Observation 159 factorization evidence | free-Abelian image boundary |
| `Core.ActualReversal.physicalQuantaAt` | B | locus + measure | intended insensitive | used in exact inverse semantics | physical projection only |
| `Core.ActualReversalBalance.physicalMeasureQuanta` | B | one Measure | proven insensitive | `physicalMeasureQuanta_perm` | same-measure sum |
| `Application.CapacityInspection.capacityAt` | B | Measure + CapacityCoordinate | no named perm theorem found | direct fold | same reducer as movement/event projections |
| `Application.ConsumptionInspection.eventConsumptionAt` | B | Measure + routing status + Purpose | selector is semantic | direct fold | routing stays outside reducer |
| `Application.ConsumptionInspection.foldRecordedConsumptionWhere?` | C | validity lookup + caller selector/project | fail-closed | shared production helper | strongest partial-additive candidate |
| `Application.CapacityWindowInspection.capacityAtAdmittedEffectiveWindow?` | C | effective date + Measure + coordinate | fail-closed | admitted CapacityEvidence prerequisite | likely same lifted combine shape |
| `Application.CapacityWindowInspection.entitlementAtAdmittedEffectiveThrough?` | C | closed time window + Measure + Purpose | fail-closed | admitted CapacityEvidence prerequisite | sibling of previous fold |
| `Application.RelationDischargeFrontier.dischargeTotal` | A | admitted discharge quantity | no named append theorem found | admission happens before fold | pure post-admission total |
| `Application.OpenRelationFrontier.currentCoverageFor` | B | source Event/Effect pair | reference aggregate | direct semantic specification | see F row below |
| `Application.OpenRelationFrontier.buildCoverageIndex` | F | source key -> summed Int | indexed | `buildCoverageIndex_getD_eq_currentCoverageFor` | existing model for future optimizations |
| `Application.ScheduledBalanceInspection.aggregateCoordinate` | B | end-exclusive horizon + coordinate | query-fixed | direct fold | future balance projection |
| `Application.ScheduledCommitmentInspection.managedFor` | B | pressure class + Purpose | query-fixed | partition already semantic | reducer is plain addition |
| `Application.ScheduledCommitmentInspection.unmanaged` | B | unmanaged partition rows | query-fixed | direct fold | sibling partition total |
| `Application.ScheduledCommitmentInspection.unrouted` | B | unrouted partition rows | query-fixed | derived through `filterMap + sum` | same additive family |
| `Application.ScheduledCommitmentInspection.unresolvedEligibility` | B | unresolved partition rows | query-fixed | `.sum`; parity theorems with row views | same additive family |
| `TransactionsFlowReview.rowTotal` | A | column -> Event coordinate quantity | expected insensitive | incidence-matrix research | scalar row projection |
| `TransactionsFlowReview.rowActivity` | D | sign partition | expected insensitive | G2-023 derived-summary audit | `positive × negative × count` product summary |
| `TransactionsFlowReview.measureResidual` | B | one Measure | expected insensitive | Observation 233 semantics | Event/Measure conservation witness |
| `StockFlowReview.eventTrackedQuanta` | B | selected coordinate set | query-fixed | direct fold | same selected-coordinate image used repeatedly |
| `StockFlowReview.boundaryQuanta` | B | current + date < boundary | query-fixed after date validation | project validates dates first | one pass per boundary today |
| `StockFlowReview.windowChanges` | D | current + half-open window + sign | query-fixed | internal parity check | product summary `positive × negative` |
| `StockFlowReview.currentTrackedQuanta` | A | balance rows | plain sum | direct fold | trivial reusable law |
| `MerchantExpenseReview.contributionFor?` | B | merchant + Measure + Expense role | semantic selector | query-relative coverage checked separately | per-Event contribution |
| `MerchantExpenseReview.Snapshot.knownTotal` | A | contribution rows | plain sum | exactness gated separately | good separation of total vs completeness |
| `CycleFundingInspection.backing` | A | selected balance rows | plain sum | selection/Nodup checked earlier | scalar summary |
| `CycleFundingInspection.assigned` | B | positive part of Remaining | per-row `max x 0` then sum | direct fold | additive after local nonlinear map |
| `CycleSpendingPaceReview.eligiblePoolEffectQuanta` | B | selected coordinate set | query-fixed | direct fold | scheduled contribution |
| `CycleSpendingPaceReview.eligible` | A | balance rows | plain sum | direct fold | duplicate shape with other balance totals |
| `CycleSpendingPaceReview.deductions` | B | date horizon + local deduction | query-fixed | direct fold | sum after semantic Scheduled selection |
| `CycleSpendingPaceReview.selectedEventQuanta` | B | selected coordinate set | query-fixed | direct fold | same shape as Stock-Flow tracked Event quantity |
| `CycleSpendingPaceReview.eligiblePoolAtEndOfDay` | B | current + validOn <= date | query-fixed after validation | history parity check | repeated across history dates |
| `ConditionalBalancePathReview.currentSelectedQuanta` | A | balance rows | plain sum | direct fold | same balance subtotal family |
| `ConditionalBalancePathReview.occurrenceSelectedQuanta` | B | selected coordinates + matching Measure | query-fixed | direct fold | coordinate fold over one occurrence |
| `ConditionalBalancePathReview.bucketChanges` | D | date -> summed Int | key aggregate | final buckets sorted afterward | finite-map summary candidate |
| `ConditionalBalancePathReview.finalAtHorizon` | E | last emitted point | **order-sensitive** | explicit path semantics | negative control |
| `ConditionalBalancePathReview.lowWater` | E-ish | minimum balance | order-insensitive result but non-additive | path semantics | semilattice/min candidate, not additive |
| `MovementAdmission.positive` | B | positive part of signed Effects | item-local | admission rule | `sum (max 0 q)` |
| `CapacityPublisher.Proposal.balance` | A | all proposal deltas | plain sum | used by `isBalanced` | local proposal algebra |
| `PlainTextAccountingExport.measureTotals` | D | Measure -> total | keyed aggregate | export validation | mechanically duplicated with Beancount |
| `BeancountExport.measureTotals` | D | Measure -> total | keyed aggregate | export validation | mechanically duplicated with PTA export |
| `Presentation.Reports.roleQuanta` | B | Measure + AccountingRole | presentation selector | presentation-only | not an authority candidate |
| `Cli.HouseholdObservationCli` budget totals | A | row field sums | presentation/transport | CLI-only | no new semantic abstraction justified |

---

# Strong findings

## F1 — the additive algebra is already real, not hypothetical

LOAM already proves permutation independence for its two most central quantity
projections:

```text
Event.quantityAt
EventMemory.quantityAtRecorded
```

and Observation 159 independently identified the fixed-Measure coordinate image
as a free-Abelian-style finite vector.

This means the census is not starting from an aesthetic resemblance. It is
extending a structure already machine-observed in Core.

## F2 — selection and reduction are repeatedly separable

Many folds have this shape:

```text
semantic question
    -> decide whether one item contributes
    -> exact Int contribution
    -> addition
```

Examples:

- routing selects Consumption;
- time selects Capacity;
- correction/currentness + time selects Stock-Flow;
- AccountingRole selects Merchant Expense;
- Scheduled pressure classification selects Commitment.

The selection laws are different and should remain named.

The reducer law is often the same.

This reinforces the companion-map decomposition:

```text
semantic admission / selection
        ↓
small mathematical image
        ↓
report / presentation
```

## F3 — fail-closed folds form a distinct family

`foldRecordedConsumptionWhere?` and the Capacity effective-window folds are not
ordinary sums because missing required evidence returns `none`.

However, their failure is global and absorbing: once one required lookup is
missing, no numeric total is justified.

That suggests a precise future research question:

> Does each fail-closed fold factor through a product/chunk combine where
> failure is absorbing and successful partial totals add?

Do not replace these functions with such an abstraction yet. The important
result of this census is only that their shared shape should be tested
separately from ordinary additive folds.

## F4 — tuple summaries are first-class mathematical images

Two important reports already accumulate product summaries:

```text
Transactions-Flow rowActivity
    (positive, negative, activeEventCount)

Stock-Flow windowChanges
    (positive, negative)
```

G2-023 already showed why `RowActivity.net` and `gross` should be derived
from the independent partitions rather than retained separately.

The next mathematical observation is that these product summaries are natural
combine targets for chunked computation:

```text
(p1, n1, c1) ⊕ (p2, n2, c2)
  = (p1+p2, n1+n2, c1+c2)
```

Again, this is a candidate law, not yet a promoted production abstraction.

## F5 — OpenRelation already demonstrates the complete optimization pattern

`OpenRelationFrontier` contains both:

```text
currentCoverageFor
    = direct semantic list aggregation

buildCoverageIndex
    = transient HashMap aggregate
```

with the theorem:

```text
buildCoverageIndex_getD_eq_currentCoverageFor
```

This is almost exactly the desired pattern for future optimization work:

```text
simple semantic specification
        ≡ theorem
fast transient summary
```

No new authority is introduced.

This should be treated as the positive control for future R1-derived work.

---

# Repeated-work pressure exposed by the census

These are **observation targets**, not optimization tickets.

## P1 — Stock-Flow reconstructs several additive answers by repeated passes

After `validateSelectedDates`, `StockFlowReview.project` currently computes:

```text
boundaryQuanta ... start
boundaryQuanta ... endExclusive
windowChanges ...
```

Each traverses the same `records` list, while each Event may again traverse its
Effects through `eventTrackedQuanta`.

A candidate one-pass summary for fixed coordinates/start/end could carry:

```text
startBoundary
endBoundary
positiveWindowChange
negativeWindowChange
```

with component-wise addition.

Research obligation before any implementation:

1. define the simple multi-pass reference result;
2. define a one-pass candidate summary only in an experiment;
3. prove/result-check exact equality;
4. measure whether the real report path is worth changing.

The existing internal parity law:

```text
start + net = end
```

must remain visible rather than being optimized away.

**Research value: high.**

## P2 — Transactions-Flow row summaries repeatedly rescan columns

`Snapshot.rows` derives all represented coordinates from the selected columns.

Both shared presentation and the TUI then do approximately:

```text
for each coordinate:
    rowActivity snapshot coordinate
        -> scan every column
            -> Event.quantityAt
                -> scan Event effects
```

So the current presentation computation has a repeated row × column ×
per-Event-coordinate-projection shape.

Observation 233 already gives the correct mathematical object: the sparse
coordinate/Event incidence matrix.

A future research-only candidate could build in one column pass a transient map:

```text
EffectCoordinate ->
  { positive : Int
    negative : Int
    activeEvents : Nat }
```

and separately retain per-column evidence for focused contribution views.

The critical semantic constraint is unchanged:

```text
no invented source/destination edges
no collapse of retained Event/Effect identity
no cross-Measure addition
```

This is not evidence to retain row summaries in canonical state. It is a
candidate transient derived index.

**Research value: very high.**

## P3 — Daily Pace history repeats date-prefix aggregation

`CycleSpendingPaceReview.projectHistory` maps over recent dates and calls a
reconstruction that includes historical selected-Actual accumulation.

For small display windows this may be entirely acceptable. The mathematical
shape nevertheless resembles a prefix scan:

```text
date1 -> aggregate through date1
date2 -> aggregate through date2
...
```

A prefix-summary formulation may exist after records are date-qualified.

Do not optimize without measurement because the requested history length is
small and simplicity may dominate.

**Research value: medium; implementation priority currently low.**

## P4 — per-Measure export aggregation is duplicated

Both:

```text
PlainTextAccountingExport.measureTotals
BeancountExport.measureTotals
```

implement the same list-backed key aggregate:

```text
MeasureId -> summed Int
```

This is genuine mechanical duplication.

It does **not** by itself justify a generic export framework. A later subtraction
experiment could ask whether one tiny internal helper yields a net source
reduction while keeping export semantics separate.

**Research value: medium-low; clean compression candidate.**

---

# Negative findings

## N1 — not every Quantity fold is an additive total

`ConditionalBalancePathReview.finalAtHorizon` intentionally returns the last
path point. Representation order there is semantic after date bucketing/sorting.

Do not generalize all `foldl` uses through a commutative aggregate API.

## N2 — lowWater belongs to a different algebra

`lowWater` is min-like, not additive.

It may have an associative/commutative semilattice reading, but importing a
lattice abstraction merely for this function would be theory-first design.

Keep it as a boundary marker.

## N3 — local nonlinear mapping does not destroy outer additivity

Examples:

```text
max remaining 0
max effect 0
sign partition
```

The per-item map is nonlinear, but once the map is fixed the list result may
still be additive over concatenation.

Therefore "linear algebra" is too narrow a label for R1. "Compositional finite
summary" is the safer umbrella.

## N4 — keyed summaries may preserve observable ordering details

The mathematical content of `measureTotals` or `bucketChanges` is a finite
key-to-sum map, but the current List representation may preserve first-seen
ordering before a later sort or renderer.

A future finite-map refactor must explicitly check whether output ordering is
observable at that boundary.

---

# Candidate laws for later experiments

No theorem is requested by this census. These are the smallest useful statements
to test later.

## L1 — scalar append law

For fixed query context:

```text
aggregate (xs ++ ys)
=
aggregate xs + aggregate ys
```

First candidates:

- `Event.quantityAt`;
- `EventMemory.quantityAtRecorded`;
- `CapacityInspection.capacityAt`;
- `TransactionsFlowReview.rowTotal`;
- `RelationDischargeFrontier.dischargeTotal`.

## L2 — product append law

```text
summary (xs ++ ys)
=
combine (summary xs) (summary ys)
```

First candidates:

- Transactions `rowActivity`;
- Stock-Flow `windowChanges`.

## L3 — fail-closed chunk law

For a fixed admitted lookup world:

```text
partialAggregate (xs ++ ys)
=
partialAggregate xs ⊗ partialAggregate ys
```

where failure is absorbing.

First candidates:

- `foldRecordedConsumptionWhere?`;
- Capacity effective-window folds.

## L4 — keyed aggregate correspondence

```text
lookup (buildIndex xs) key
=
directAggregate xs key
```

This law is already realized for OpenRelation coverage.

Potential later candidates:

- per-Measure totals;
- date buckets;
- Transactions-Flow row summaries.

---

# Provisional R1 result

The census supports a stronger statement than the initial map could safely make:

> A large fraction of LOAM's numeric read-side work is not arbitrary iteration.
> It is repeated construction of small compositional summaries after semantic
> selection has already decided which evidence contributes.

The likely reusable mathematics is therefore **not** "one generic report
framework".

It is a family of very small laws:

```text
scalar additive summary
product additive summary
fail-closed lifted summary
keyed additive summary
```

with domain-specific selectors kept outside those laws.

This is exactly compatible with the established Compression Audit rule:

```text
share algebra and mechanics
preserve semantic authority
```

---

# Suggested next observation

Do not implement any shared fold helper yet.

The highest-leverage next research step is **R2 report factorization**, starting
with the two places where repeated work is already visible:

1. **Transactions-Flow**
   - identify the smallest transient sparse summary that supports
     `rowTotal`, `rowActivity`, and current presentation without losing
     focused Event contributions;
2. **Stock-Flow**
   - identify the smallest one-pass summary equivalent to the three current
     additive passes while retaining the explicit parity check.

This would answer a more useful question than "can these folds be generalized?":

> Can several current answers provably factor through one smaller transient
> mathematical image?

That answer should be known before any production abstraction or optimization.
