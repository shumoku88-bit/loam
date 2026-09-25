# LOAM report factorization map — draft 2026-09-25

Status: RESEARCH DRAFT — observation only / no implementation authorized

Baseline production:

    main 8b26bfe8cb953d2543879cbe93570d020d2c7f92

Companion drafts:

- docs/research/MATHEMATICAL_STRUCTURE_MAP_DRAFT_2026-09-25.md
- docs/research/ADDITIVE_FOLD_CENSUS_DRAFT_2026-09-25.md

## Question

Can current Transactions-Flow and Stock-Flow answers factor through smaller
transient mathematical images without erasing evidence that current consumers
actually observe?

This is not a shared-report-framework proposal. It is a factorization study:

    rich admitted input
        -> candidate transient image
        -> existing answers

For each candidate image ask both:

1. Which current answers can be reconstructed exactly?
2. Which current answers become impossible because the image forgot observable information?

No production representation, theorem, cache, index, or persistence change is
authorized by this draft.

# 1. Transactions-Flow

## 1.1 Current retained image

TransactionsFlowReview.Snapshot retains only:

    start
    endExclusive
    columns : List Column

    Column
      Event
      date
      description

Cells and rows are derived. This remains a good authority boundary.

## 1.2 Information ladder

Current semantics expose a natural sequence of progressively smaller images:

    T0 selected Columns with full Event / Effect evidence
         |
         | Event.quantityAt
         v
    T1 sparse Event x EffectCoordinate incidence quantities
         |
         | aggregate by row, classify sign per Event-cell
         v
    T2 row summary
         EffectCoordinate ->
           positive
           negative
           activeEvents
         |
         +--> net   = positive + negative
         +--> gross = positive - negative
         v
    T3 scalar row net

Each downward step forgets something. This is an observational factorization
map, not a sequence of canonical representations.

## 1.3 T0 is still required

RoleFlowReview.unresolvedEffects emits individual unresolved Effects. This is
intentional: numerical cancellation must not masquerade as complete
AccountingRole evidence.

MerchantExpenseReview likewise observes individual Effects when deciding
query-relative completeness and when retaining unresolved AccountingRole
witnesses.

Therefore:

    same coordinate totals
        !=
    same completeness evidence

A future row-summary index may accelerate quantity observations, but it must be
derived beside selected Columns rather than replacing them.

## 1.4 T1 supports native quantity observations

A sparse incidence image can plausibly support:

- cellAt
- rowTotal
- rowActivity
- measureResidual
- focused contributing-Event detail

Conceptually:

    (EventId, EffectCoordinate) -> Int

with Event/date/description metadata still available from the selected Column.

### Critical aggregation order

The cell quantity is Event.quantityAt, not one raw Effect.

Repeated same-coordinate Effects inside one Event must be aggregated before the
cell sign is classified.

Counterexample:

    one Event
      food/jpy +100
      food/jpy -100

Correct incidence cell:

    food/jpy = 0

and that Event contributes zero to activeEvents.

A global summary that classifies the two raw Effects separately would produce
the wrong positive/negative partitions and contributor count.

Any future acceleration therefore needs the two-level shape:

    per Event:
        aggregate Effects by EffectCoordinate
    then:
        combine Event-coordinate cells into global row summaries

## 1.5 Represented rows are richer than nonzero cells

Snapshot.rows is currently derived from every raw Effect coordinate in the
selected Events, then deduplicated and sorted.

So a coordinate can be represented even when same-coordinate Effects cancel to
a zero cell.

Sparse presentation later omits rows with activeEvents = 0, but RoleFlow begins
from the complete represented-coordinate set.

A sufficient transient image therefore needs both:

    representedCoordinates
    nonzero Event-coordinate cells

or an equivalent representation. Storing only nonzero cells is too coarse.

## 1.6 T2 supports summary presentation

For one represented coordinate:

    RowSummary
      positive     : Int
      negative     : Int
      activeEvents : Nat

Then:

    rowTotal = positive + negative
    net      = positive + negative
    gross    = positive - negative

Presentation.Reports.presentTransactionsFlow and the TUI summary rows appear to
factor through T2 plus the window bounds and selected Event count.

A later experiment should test:

    summaryIndex[coordinate]
        = rowActivity snapshot coordinate

    rowTotal snapshot coordinate
        = summaryIndex[coordinate].net

## 1.7 Focused detail needs T1

The Transactions-Flow detail view identifies contributing Events and displays
their context. T2 has forgotten Event identity.

Thus:

    summary mode       -> T2
    focused detail     -> T1 + Column metadata

This matches the already-qualified sparse-summary / focused-detail design.

## 1.8 RoleFlow splits across levels

RoleFlow classified rows need:

    represented coordinates
    + row net
    + AccountingRole

so they can plausibly factor through T2.

RoleFlow unresolved Effect witnesses still require T0.

RoleFlow is therefore naturally a product of:

    quantity factorization
    +
    evidence-completeness frontier

A numeric summary cannot replace both.

## 1.9 Merchant Expense remains a T0 overlay

Merchant Expense has additive known contributions, but its exactness boundary
observes individual Effects.

It must not be used to justify replacing Transactions-Flow Columns with a
coordinate-only image.

## 1.10 Transactions-Flow verdict

The useful shape is branched:

                     selected Columns T0
                       /          \
                      /            \
                     v              v
          evidence overlays      incidence T1
          Role / Merchant            |
          unresolved                 v
                                row summary T2
                                  /       \
                                 v         v
                            summary UI   RoleFlow
                                       classified rows

The strongest future experiment is a transient incidence/row index derived from
the existing Columns, with correspondence to the current direct definitions.

# 2. Stock-Flow

## 2.1 Current inputs and result

StockFlowReview.project composes:

    BalanceReview.Snapshot
    ActualReview.Record list
    explicit half-open window

The public Snapshot already retains only independent result components:

    reconstructedStart
    increasesAcrossEvents
    decreasesAcrossEvents
    currentTracked

while netChange and reconstructedEnd are derived.

The repeated-work pressure is in construction, not in the public result shape.

## 2.2 Current passes

After endpoint validation production performs conceptually:

    Pass 0  validateSelectedDates
    Pass 1  boundaryQuanta start
    Pass 2  boundaryQuanta endExclusive
    Pass 3  windowChanges

All four may recompute eventTrackedQuanta for the same current Event.

currentTrackedQuanta is separate because it comes from BalanceReview rows.

## 2.3 Per-record contribution

For fixed selected coordinates and window, compute once:

    q = eventTrackedQuanta coordinates record.event

Cases:

Non-current:
    contributes nothing

Current with q = 0:
    contributes nothing
    date is not required

Current with q != 0:
    date must exist and be a valid ISO date

Then:

    date < start
        startBoundary += q
        endBoundary   += q

    start <= date < endExclusive
        endBoundary += q
        q > 0 -> positiveWindow += q
        q < 0 -> negativeWindow += q

    date >= endExclusive
        no selected-window/boundary contribution

## 2.4 Candidate construction summary

A conceptually sufficient scan image is:

    StockFlowScan
      startBoundary  : Int
      endBoundary    : Int
      positiveWindow : Int
      negativeWindow : Int

with fail-closed date admission.

Successful partial summaries combine component-wise by addition.

The public Snapshot follows from:

    reconstructedStart    = startBoundary
    increasesAcrossEvents = positiveWindow
    decreasesAcrossEvents = negativeWindow
    currentTracked        = sum BalanceReview rows

endBoundary remains available for the current parity check.

## 2.5 Minimal answer and qualification witness differ

Mathematically:

    endBoundary
      = startBoundary + positiveWindow + negativeWindow

So a denotational answer can derive the end boundary.

But production deliberately computes an independent end boundary and checks:

    start + net = end

before returning the answer.

That redundancy has verification value.

Therefore:

    minimal public answer
        !=
    minimal construction / qualification witness

A future one-pass experiment should retain endBoundary during construction and
preserve the parity check.

## 2.6 One-pass factorization is plausible but not free

A sequential one-pass candidate can plausibly:

1. inspect each record once;
2. compute selected Event quantity once;
3. preserve current date-refusal rules;
4. update all four scan components;
5. retain the final parity check.

Two obligations remain.

### Exact refusal witness

Current validation reports the first offending contributing record in list
traversal order.

A sequential one-pass implementation can preserve that.

A parallel/chunked combine may change which error is reported unless the error
carrier retains ordering or witness priority.

So numeric commutativity does not make the whole fail-closed function freely
parallelizable.

### Independent-check value

The current multi-pass code computes start, end, and window partitions in
separate functions.

Collapsing them into one branch structure reduces implementation diversity.

A future correspondence proof to the current reference functions may justify
that trade, but it should be explicit.

## 2.7 Stock-Flow verdict

The likely factorization is:

    BalanceReview rows
        -> currentTracked

    ActualReview records
        -> fail-closed StockFlowScan
             startBoundary
             endBoundary
             positiveWindow
             negativeWindow

    StockFlowScan + currentTracked
        -> existing Snapshot

This is a cleaner candidate than any generic report abstraction.

# 3. The reports should remain separate

Transactions-Flow and Stock-Flow both use date windows and addition, but their
date-admissibility domains differ.

Transactions-Flow needs a date for every current quantity-bearing Event because
any such Event can become an incidence column.

Stock-Flow needs a date only when a current Event changes the selected stock
coordinates.

Therefore no generic shared window validator is earned.

Reusable mathematics begins after each report has selected its own semantic
contribution.

# 4. Factorization matrix

| Existing answer | T0 raw Columns | T1 incidence | T2 row summary | StockFlowScan |
| --- | ---: | ---: | ---: | ---: |
| Transactions cellAt | enough | enough | no | n/a |
| Transactions rowTotal | enough | enough | enough | n/a |
| Transactions rowActivity | enough | enough | enough | n/a |
| Transactions measureResidual | enough | enough | no | n/a |
| Transactions summary presentation | enough | enough | enough | n/a |
| Transactions focused contributors | enough | enough + metadata | no | n/a |
| RoleFlow classified rows | enough | enough | enough + represented rows | n/a |
| RoleFlow unresolved Effects | required | no | no | n/a |
| Merchant exactness witnesses | required | insufficient | no | n/a |
| Stock-Flow Snapshot | records + balances | n/a | n/a | enough + currentTracked |
| Stock-Flow parity witness | records | n/a | n/a | requires endBoundary |

"Enough" here means observationally plausible from current definitions, not yet
formally proved.

# 5. Highest-value later experiments

## RF-1 — Transactions sparse-summary correspondence

Experiment-only structure:

    representedCoordinates
    per-Event sparse coordinate totals
    rowActivity summary

Compare with current production definitions for:

- represented rows
- cellAt
- rowTotal
- rowActivity
- measureResidual
- focused contributors

Required negative witnesses:

- repeated same-coordinate Effects
- exact same-coordinate cancellation inside one Event
- zero-net / high-gross across Events
- multiple Measures
- represented coordinate with zero cell
- Effect permutation

RoleFlow/Merchant unresolved frontiers must remain T0-derived.

## RF-2 — Stock-Flow one-scan correspondence

Compare one sequential fail-closed scan against the current construction.

Must preserve:

- successful Snapshot
- start boundary
- independently accumulated end boundary
- positive/negative partitions
- currentTracked input
- missing-date refusal
- invalid-date refusal
- zero selected quantity not requiring a date
- superseded Event inertness
- final parity check

Measure performance only after correspondence succeeds.

## RF-3 — rowTotal equals RowActivity.net

Small theorem-shaped question:

    rowTotal snapshot coordinate
      =
    (rowActivity snapshot coordinate).net

This would connect two currently separate full-column scans and clarify that they
are two observations of one row quantity meaning.

# Current verdict

The study does not support one shared Flow engine.

It supports a narrower rule:

> Compress repeated derived computation, not the evidence distinctions that
> make the answer justified.

Transactions-Flow has a promising transient incidence/row-summary acceleration
boundary beside its retained Columns.

Stock-Flow has a promising fail-closed product summary for construction while
its public result is already appropriately compressed.
