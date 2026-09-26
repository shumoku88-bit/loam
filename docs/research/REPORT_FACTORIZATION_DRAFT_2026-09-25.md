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

# 6. RF-1 finite Lean probe result

Observation 320 implements the candidate Transactions-Flow factorization only on
the research surface and tests it against current production observations.

Qualified head:

    c7f85df7431782ffb4b28c3ffa1cd2902c342931

Lean Proof Surfaces run:

    36145185286
    Build selected live Lean research witnesses: SUCCESS

The experiment builds:

    raw Effects
        -> Event-local coordinate cells
        -> global coordinate row summaries

and checks the selected witness snapshot against current
TransactionsFlowReview.

The successful finite correspondence set covers:

- represented coordinate rows;
- cellAt for every selected Event / represented coordinate pair;
- rowActivity on every represented row;
- rowTotal = sparse row-summary net on every represented row;
- focused contributing Event identities;
- per-Measure residuals.

The falsification fixtures include:

- repeated same-coordinate Effects;
- exact same-Event same-coordinate cancellation;
- cross-Event positive/negative cancellation;
- zero-net/high-gross pressure;
- multiple Measures;
- a represented coordinate with a zero Event cell.

Most importantly, the exact same-Event cancellation witness confirms the
required aggregation order:

    raw Effects
        -> first aggregate by coordinate inside one Event
        -> only then classify cell sign / active Event contribution

A raw-Effect sign bucket is therefore not equivalent to current
Transactions-Flow semantics.

This is a **finite executable correspondence result**, not yet a theorem for
arbitrary Snapshots. It upgrades RF-1 from "plausible factorization" to
"survived deliberately hostile finite witnesses".

The next mathematical question, if pursued, is general correspondence rather
than production implementation.

# 7. RF-1 general additive laws — Observation 321

Observation 321 moves two RF-1 edges beyond finite witness testing.

Qualified research head:

    9f269c13ccd82cbd96ca76f800f6c4c7d1ff60ea

Lean Proof Surfaces run:

    36147111120

All three Lean surfaces passed:

- product Lean surface: SUCCESS;
- selected live research witnesses: SUCCESS;
- durable Lean proof surface: SUCCESS.

The research theorem is still isolated from production reachability.

## 7.1 rowTotal is not an independent quantity meaning

For arbitrary Transactions-Flow Snapshot and arbitrary EffectCoordinate:

    rowTotal snapshot coordinate
      =
    (rowActivity snapshot coordinate).net

The proof is by induction over the selected Column list.

Its invariant is:

    scalar total
      =
    accumulated positive + accumulated negative

for an arbitrary scan prefix / suffix state.

The contributor count is irrelevant to the numeric invariant and therefore
remains unconstrained by the proof.

This means current rowTotal and rowActivity.net are two presentations of one
quantity semantics, not two independent report meanings.

## 7.2 Event-local coordinate aggregation is exactly Event.quantityAt

Observation 321 also proves, for arbitrary Event and EffectCoordinate:

    eventCellQuanta event coordinate
      =
    (Event.quantityAt event coordinate.locus coordinate.measure).quanta

where eventCellQuanta is a research-only left fold that:

- scans every retained Effect;
- selects exactly one EffectCoordinate;
- accumulates all matching exact signed quanta.

The proof is by induction over the Effect list and establishes equivalence with
the existing right-fold Event.quantityAt definition.

Therefore the first RF-1 factorization edge is now general:

    Event.effects
        -> Event-local coordinate aggregation
        = Event.quantityAt

This formally protects the aggregation order identified by Observation 320.

## 7.3 What remains unproved

Observation 321 does not prove that one particular sparse finite-map
representation is globally equivalent.

A future concrete sparse builder would still need correspondence for:

- coordinate-key uniqueness;
- lookup after repeated same-coordinate insertion;
- represented zero-cell coordinates;
- reconstruction of represented row keys;
- contributor identity lookup.

Those are representation laws rather than quantity algebra.

So RF-1 now separates cleanly into:

    proved arithmetic core
        +
    not-yet-selected finite-map representation

No production optimization follows automatically.

# 8. RF-2 numeric-pass fusion — Observation 322

Observation 322 proves a universal correspondence for the arithmetic part of
Stock-Flow construction while deliberately leaving the existing fail-closed
date-validation pass untouched.

Qualified research head:

    d70ec0ca8f24ff491008c390a3f0736c6f752260

Lean Proof Surfaces:

    36147789932 — SUCCESS

Compression Audit:

    36147789943 — SUCCESS

## 8.1 What is now general

For arbitrary:

- selected EffectCoordinate list;
- ActualReview.Record list;
- start/end strings;
- initial accumulators;

one fused record fold produces exactly the same four numeric components as the
three separate current-style numeric folds:

    start boundary
    end boundary
    positive window change
    negative window change

The fused step computes one selected Event quantity for a dated current record
and routes that quantity to all relevant result components.

The proof factors through one-record projection correspondence and then proves
whole-list equality by induction over the Record list.

## 8.2 What this means for the current shape

The numeric construction is therefore not intrinsically three independent
passes.

Its mathematical image is one product accumulator:

    StockFlowNumericSummary
      startBoundary
      endBoundary
      positiveWindow
      negativeWindow

with component-wise accumulation after each record's semantic selection.

So the current conceptual construction can be reduced, without changing
numeric meaning, from:

    validate dates
      + start-boundary scan
      + end-boundary scan
      + window-change scan

to:

    validate dates
      + one fused numeric scan

This statement is now a general Lean result on the research surface.

## 8.3 Why validation remains separate for now

The current validation pass is not merely a Boolean gate.

It preserves a specific fail-closed observation:

- only current records matter;
- zero selected quantity does not require a date;
- the first contributing record lacking a date reports that Event identity;
- the first contributing record with an invalid date reports that Event identity.

Fusing validation into the numeric scan is operationally plausible, but its
correctness obligation includes exact first-failure witness/order, not only
addition.

That is a sequencing/refusal theorem and should be tested separately.

## 8.4 Useful redundancy remains

The fused numeric summary retains both:

    endBoundary

and:

    startBoundary + positiveWindow + negativeWindow

even though they should agree for a valid ordered window.

Therefore the existing parity check can survive a future one-scan
implementation. Arithmetic fusion does not require deleting the independent end
accumulator.

This preserves the distinction:

    repeated traversal
        may be removable

    independent qualification witness
        may remain valuable

No production optimization is authorized by Observation 322.

# 9. RF-2 complete fail-closed fusion — Observation 323

Observation 323 extends the Stock-Flow fusion result from arithmetic to
left-to-right refusal semantics.

Qualified research head:

    71a9b72aa0128775f9790f2a65cec329a3ffdb9f

Lean Proof Surfaces:

    36163341504 — SUCCESS

Compression Audit:

    36163341359 — SUCCESS

## 9.1 General theorem

For arbitrary:

- selected EffectCoordinate list;
- ActualReview.Record list;
- start/end strings;
- initial numeric Scan;

the research one-pass function is exactly equal to the research two-pass
reference:

    fused coordinates start end records initial
      =
    twoPass coordinates records start end initial

The two-pass reference performs:

    validate records left-to-right
        then
    numeric fold

The fused function performs:

    for each record, left-to-right:
        validate this record
        if accepted, update numeric Scan
        if rejected, return immediately

The equality is over:

    Except String Scan

so it covers both success and failure observations.

## 9.2 What failure equality includes

The per-record refusal mirrors the current Stock-Flow validation rules:

- superseded records are inert;
- zero selected quantity does not require a date;
- nonzero selected quantity requires a date;
- a retained date must be a valid ISO calendar date;
- the message embeds the offending EventId;
- traversal order determines the first failure.

Because the theorem proves equality of the complete Except value, an earlier
numeric accumulator update cannot leak past a later refusal.

The visible answer remains the same first error.

## 9.3 What is now mathematically compressible

Combining Observations 322 and 323 gives this research result:

    current conceptual shape

      validate all selected records
      + start boundary scan
      + end boundary scan
      + window change scan

    can factor into

      one sequential fail-closed scan
        -> error message
        or
        -> {
             startBoundary
             endBoundary
             positiveWindow
             negativeWindow
           }

without changing the research reference semantics.

The end boundary remains independently accumulated, so the final Stock-Flow
parity check can remain an independent witness.

## 9.4 Remaining production boundary

Observation 323 intentionally does not claim a direct general equality against
the public StockFlowReview.project function.

The public project also owns:

- endpoint date validation;
- start < end validation;
- selected-coordinate derivation from BalanceReview;
- currentTracked derivation from current balances;
- final parity refusal;
- public Snapshot construction.

Its internal validation helpers are private.

The research result therefore isolates the record-scan core. A production
change, if ever justified, should connect this proven scan semantics to the
public project boundary rather than treating the research duplicate as a second
authority.

## 9.5 Consequence for the mathematical map

Stock-Flow is now a strong concrete example of:

    fail-closed sequential semantics
        ×
    additive product accumulator

The additive components compose freely after each record is admitted, while
the error observation remains left-biased and order-sensitive.

This is a useful counterexample to an over-broad "all report folds are
commutative monoids" story.

The numeric carrier is compositional.

The complete observable computation is sequential because first-failure
identity matters.

No production change is authorized by Observation 323.

# 10. Stock-Flow public-shell factorization — Observation 324

Observation 324 extends the Stock-Flow map outward from the record-scan core to
the public project shell.

Qualified research head:

    73b9a9972bfef32ac0da73a6c59aa48bd20cb6ad

Lean Proof Surfaces:

    36206138925 — SUCCESS

Compression Audit:

    36206138942 — SUCCESS

All three Lean proof-surface jobs passed:

- product Lean surface;
- selected live research witnesses;
- durable Lean proof surface / axiom audit.

## 10.1 Small outer image

The research candidate shows that after BalanceReview has already produced its
Snapshot, Stock-Flow needs only this balance image:

    BalanceImage
      coordinates
      currentTracked

The selected record stream then factors through:

    Except String Scan

where:

    Scan
      startBoundary
      endBoundary
      positiveWindow
      negativeWindow

The outer shell consumes only:

    endpoints
    BalanceImage
    Except String Scan

and then applies:

    endpoint validation
    -> window-order validation
    -> scan refusal/success
    -> parity gate
    -> public StockFlowReview.Snapshot construction

No Event or Effect evidence is observed by the outer shell after the scan
boundary.

## 10.2 General shell laws

Observation 324 proves generally that:

- malformed endpoints dominate any scan result;
- reversed valid endpoints dominate any scan result;
- a scan error passes through unchanged;
- a successful parity-preserving Scan constructs exactly the expected Snapshot;
- parity failure remains the same explicit internal refusal.

Therefore the outer report shell is already completely described by the small
factorization above.

## 10.3 Public production pressure

The research factorProject was also compared observationally with the public
StockFlowReview.project entrance on closed cases covering:

- successful boundary/window reconstruction;
- first missing date;
- first invalid date;
- zero selected quantity with no date;
- superseded undated record;
- malformed endpoint dominating record failure;
- reversed window dominating record failure.

All selected witnesses agree with the public production result, comparing either
the complete successful Snapshot or the exact error text.

This is executable pressure, not a universal production theorem.

## 10.4 Exact remaining bridge

A universal theorem:

    research factorProject
      =
    public StockFlowReview.project

for arbitrary inputs is deliberately not claimed from the Observation module.

The remaining obstacle is architectural rather than mathematical:
StockFlowReview's current construction helpers are file-private.

The missing production-local bridge is therefore narrow:

    private selectedCoordinates
      = research BalanceImage.coordinates

    private currentTrackedQuanta
      = research BalanceImage.currentTracked

    private validateSelectedDates
      + boundaryQuanta start
      + boundaryQuanta end
      + windowChanges
      =
    proved one-pass fail-closed Scan

Once those equations are available inside StockFlowReview, the already-proved
outer shell determines the same public result.

This makes the remaining proof obligation concrete without creating a second
authority.

## 10.5 Current Stock-Flow map

The complete research picture is now:

    BalanceReview.Snapshot
      -> {coordinates, currentTracked}
                       \
                        \
    ActualReview.Record list
      -> one sequential fail-closed Scan
             {
               startBoundary
               endBoundary
               positiveWindow
               negativeWindow
             }
                        /
                       /
    endpoint gates
      -> parity
      -> StockFlowReview.Snapshot

The mathematical compression target is therefore not "a generic flow engine".

It is one very specific record-scan kernel plus a small outer shell.

No production refactor is authorized by Observation 324.

# 11. Transactions-Flow sparse incidence representation — Observations 325–327

Observations 325–327 move the Transactions-Flow sparse-map idea from finite
fixtures to a concrete general representation specification.

Qualified research head:

    97f2a39319ac30fbfe1596854762e566ed84cbca

Lean Proof Surfaces:

    36207277155 — SUCCESS

Compression Audit:

    36207277099 — SUCCESS

All three Lean surfaces passed:

- product Lean surface;
- selected live research witnesses;
- durable Lean proof surface / axiom audit.

## 11.1 Event-local sparse cell map

Observation 325 chooses a concrete transient cell representation:

    EventId token
      -> HashMap (Locus token, Measure token) Int

The coordinate hash key is the exact token pair, not display text or an
ad-hoc concatenated string.

For arbitrary Events and coordinates it proves:

    cellIndex.getD coordinate 0
      =
    Event.quantityAt event coordinate

It also proves key-presence correspondence:

    cellIndex.contains coordinate
      =
    raw Effects contain that EffectCoordinate

Therefore same-Event cancellation does not erase coordinate representation.

A coordinate whose exact summed cell quantity is zero still has a retained
transient key when raw Effects represented it.

## 11.2 Snapshot cell lookup

Observation 325 also builds an EventId-keyed map of Event-local cell maps and
proves, for arbitrary Snapshots, coordinates, and EventIds:

    sparseCellAt
      =
    TransactionsFlowReview.cellAt

The tail-first EventId index preserves current first-match semantics even for an
arbitrary research Snapshot containing duplicate EventIds.

This is a representation theorem, not an assumption of production uniqueness.

## 11.3 Higher observations factor through the sparse cell map

Observation 326 replaces each direct Event.quantityAt row projection with the
concrete sparse-cell lookup and proves for arbitrary Snapshots:

    indexedRowActivity
      =
    TransactionsFlowReview.rowActivity

and therefore:

    indexedRowActivity.net
      =
    rowTotal

It also proves focused contributor EventId lists are unchanged.

So the per-Event sparse incidence map preserves:

- cell values;
- row positive/negative partitions;
- active Event count;
- row net;
- focused contributor identity.

The represented-row list remains separate because raw coordinate occurrence is
itself observable.

## 11.4 Global RowActivity map specification

Observation 327 defines a global research specification:

    CoordinateKey -> RowActivity

over exactly Snapshot.rows.

For arbitrary Snapshots it proves:

- every represented coordinate maps to exactly production rowActivity;
- unrepresented coordinates are not invented;
- represented zero-activity coordinates remain present as keys.

This makes the global row-map meaning precise without yet choosing the fastest
construction algorithm.

The specification deliberately computes values through the already-proved
sparse-cell route. It is therefore a semantic target, not a performance claim.

## 11.5 Remaining Transactions-Flow question

The representation question is now mostly closed.

The remaining performance-specific problem is narrower:

    current semantic specification
      Snapshot.rows
        x
      sparse-cell-derived rowActivity
        -> RowIndex

versus a candidate faster builder:

    selected Columns
      -> one incremental sparse RowIndex construction

The later builder would need to prove lookup/key correspondence to Observation
327's RowIndex.

In particular it must preserve:

- Event-local same-coordinate aggregation before sign classification;
- represented zero rows;
- positive/negative partitions;
- active Event count;
- focused contributor identity where that identity view is requested separately;
- no replacement of retained Columns as evidence authority.

This is now an algorithm-refinement question rather than an unresolved semantic
question.

# 12. Transactions-Flow one-pass RowIndex refinement — Observation 328

Observation 328 proves that the already-qualified global RowIndex meaning can be
constructed incrementally over the selected Column stream.

Qualified research head:

    ff4813bb88922491f2f230264cde8a18736623b5

Lean Proof Surfaces:

    36207987852 — SUCCESS

Compression Audit:

    36207987863 — SUCCESS

All three Lean proof-surface jobs passed:

- product Lean surface;
- selected live research witnesses;
- durable Lean proof surface / axiom audit.

## 12.1 Algorithm shape

The research builder uses two deliberately separated stages.

First, it seeds exactly the represented row keys from Snapshot.rows:

    represented coordinate
      -> zero ActivityState

Second, it scans selected Columns once from left to right.

For each Column:

    raw Effects
      -> Event-local CellIndex
      -> deduplicated Event coordinates
      -> update only pre-seeded global row keys

The Event-local CellIndex is the already-proved Observation 325 representation,
so same-Event repeated Effects are summed before sign classification.

The updater refuses to insert a row key that Snapshot.rows did not seed.
Therefore the incremental builder cannot manufacture new represented rows.

## 12.2 General refinement theorem

For every Transactions-Flow Snapshot and every EffectCoordinate:

    fastRowActivity? snapshot coordinate
      =
    Observation327.buildSnapshotRowIndex(snapshot).get?(coordinateKey coordinate)

This is a pointwise extensional equality against the semantic RowIndex
specification, not a finite fixture comparison.

The proof separates represented and unrepresented coordinates:

- represented rows start from an explicit zero state and accumulate exactly the
  production per-Column quantity step;
- unrepresented rows start absent and remain absent because updates never insert
  missing seed keys.

## 12.3 Preserved meaning

The one-pass refinement therefore preserves the RowIndex laws already
established by Observations 325–327:

- exact Event-local coordinate aggregation;
- sign classification only after Event-local aggregation;
- positive / negative row partitions;
- active Event count;
- represented zero-activity rows;
- no invented row keys;
- arbitrary Snapshot Column multiplicity, including duplicate EventIds.

Retained selected Columns remain the evidence-bearing review image. The transient
RowIndex is still derived acceleration state only.

## 12.4 What remains performance-specific

Observation 328 qualifies the *shape* of the one-pass algorithm, not the final
fastest local mechanics.

Its Event-coordinate dedup list is intentionally simple research machinery.

A future implementation may replace that local dedup step with a HashSet,
HashMap key iteration, or another transient finite-set representation.

Such a replacement no longer needs to rediscover Transactions-Flow semantics.
It needs only to preserve the already-qualified per-Column update law and the
pointwise RowIndex correspondence above.

The Transactions-Flow question has therefore moved from:

    can a sparse one-pass summary preserve meaning?

to:

    which transient local representation builds the same qualified summary
    most simply and efficiently?

No production optimization is authorized by Observation 328.

# 13. Transactions-Flow CellIndex support compression — Observation 329

Observation 329 narrows the remaining local algorithm question further.

Observation 328 used both:

```text
Event.effects
  -> CellIndex
  -> exact per-coordinate quantity

Event.effects
  -> eventCoordinates
  -> one deduplicated visit per represented coordinate
```

The second path is now shown to carry no independent Event-local information.

For arbitrary Events and coordinates, Observation 329 proves:

- `CellIndex.keys` is duplicate-free;
- a coordinate key is present exactly when that coordinate occurred in raw
  Event evidence;
- the CellIndex value remains exactly `Event.quantityAt`;
- exact same-Event cancellation keeps the represented key even when the summed
  value is zero.

Therefore the qualified local image is already:

```text
CoordinateKey -> Int
```

with key presence encoding representation and the value encoding the exact
aggregated cell.

The explicit list-membership dedup stage in Observation 328 is therefore
informationally redundant. A later optimized builder can iterate CellIndex keys
directly.

This does not claim a formal runtime bound. It removes one concrete
list-membership dedup mechanism that can become quadratic in the number of
distinct coordinates within one Event.

## 13.1 Newly exposed next question

The next compression question is stronger:

```text
current:
    Snapshot.rows
      -> seed global zero RowIndex
      -> scan Columns

candidate:
    empty global RowIndex
      -> scan Columns
      -> first observed CellIndex key inserts zero row then applies Event cell
```

If the candidate can be proved to end with exactly the same represented key set
and RowActivity values, then the separate `Snapshot.rows` pre-pass is also
derivable rather than operationally necessary for summary construction.

That would leave sorting only at presentation time where ordered rows are
actually requested.

No production optimization is authorized by Observation 329.

---

# 14. Transactions-Flow support/order separation — Observation 330

Observation 330 isolates the remaining meaning carried by `Snapshot.rows`.

For every Snapshot and EffectCoordinate it proves that row membership is exactly
selected raw Effect coordinate occurrence.

Therefore:

```text
raw selected Effect coordinates
    -> represented-row support

eraseDups
    -> duplicate-free representation

mergeSort
    -> presentation order
```

The latter two operations do not add row-support meaning.

This separates two concerns that Observation 328 still combined:

```text
semantic support
    !=
ordered row presentation
```

A global summary may therefore discover row support while scanning evidence and
sort only when an ordered row view is requested.

No production change is authorized by Observation 330.

# 15. Seedless one-pass RowIndex — Observation 331

Observation 331 removes the final research pre-seeding dependency.

Qualified proof head:

    c99ab4c8b28dcc0ce4551b5042e7feec0adbf82c

Lean Proof Surfaces:

    36209767624 — SUCCESS

The candidate starts from an empty HashMap.

For each selected Column:

```text
raw Effects
    -> Event-local CellIndex
    -> iterate CellIndex keys exactly once
    -> first key occurrence inserts zero ActivityState and applies the cell
    -> later occurrences update the existing state
```

For every Snapshot and EffectCoordinate, Observation 331 proves:

```text
seedlessRowActivity? snapshot coordinate
    =
Observation327.buildSnapshotRowIndex(snapshot).get?(coordinateKey coordinate)
```

This is a general pointwise refinement theorem, not a fixture check.

The theorem preserves the subtle zero-cancellation boundary:

- coordinate support follows raw occurrence;
- Event-local aggregation happens before sign classification;
- visiting a CellIndex key inserts the global key even when its summed quantity
  is exactly zero;
- later Event cells update that retained zero state normally.

So Transactions-Flow summary construction no longer mathematically requires:

1. a separate Event-coordinate list dedup;
2. a precomputed sorted `Snapshot.rows` list;
3. a zero-seeding pass over that list.

Retained selected Columns remain evidence authority. The RowIndex remains
transient derived acceleration state.

## 15.1 Paired high-cardinality measurement

After the general proof succeeded, a measurement-only paired benchmark compared:

```text
baseline:
    Snapshot.rows
      -> rowActivity for every represented row

candidate:
    Observation331 seedless RowIndex
      -> convert transient keys to coordinates
      -> one final coordinate sort
```

Synthetic pressure shape:

- each Event has exactly two Effects;
- one shared `cash/jpy` coordinate;
- one distinct `expense-N/jpy` coordinate;
- N Events therefore produce N+1 represented rows.

This is intentionally a high-row-cardinality sparse pressure case, not a claim
about ordinary household row counts.

Qualified benchmark commit:

    e60e3d9daf2ce74d040b399a577ba5a8b949f341

GitHub Actions run:

    36210361690 — SUCCESS

Runner:

    ubuntu-24.04

Three paired repetitions were taken per size. Baseline and candidate order was
alternated across repetitions. The complete timed row results were retained and
compared for exact equality after measurement.

| Events | Rows | Current median | Seedless median | Speedup | Current growth | Seedless growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 250 | 251 | 143.7 ms | 8.3 ms | 17.24x | - | - |
| 500 | 501 | 572.7 ms | 16.6 ms | 34.45x | 3.98x | 1.99x |
| 1,000 | 1,001 | 2.2 s | 33.7 ms | 67.22x | 3.95x | 2.02x |
| 2,000 | 2,001 | 8.9 s | 66.9 ms | 133.71x | 3.95x | 1.98x |
| 4,000 | 4,001 | 36.4 s | 136.9 ms | 266.06x | 4.06x | 2.04x |

Within this measured shape, doubling Events and represented rows costs about 4x
for the current materialization and about 2x for the seedless candidate.

This is empirical evidence of the repeated-row-scan pressure predicted by the
factorization study. It is not a general asymptotic proof and the fixture is
deliberately harsher than an ordinary household ledger.

### Measurement correction

An earlier version of the benchmark computed semantic-equality reference values
before entering the timed region. Those results showed both paths nearly equal
and nearly linear, but the setup allowed pure computed values to be shared or
hoisted and therefore did not provide trustworthy evidence about reconstruction
cost.

That result was discarded.

The qualified run above instead retains the actual timed results and compares
those exact results after timing. The large change in observed scaling is why
the corrected instrumentation is the recorded result.

## 15.2 Remaining empirical question

The high-cardinality case earns a stronger measurement, not automatic production
promotion.

The remaining practical question is:

```text
with a household-sized fixed row universe
    and a long Event history,

does seedless construction still remove enough repeated work
to justify its transient HashMap machinery?
```

That case should be measured separately before any production optimization is
proposed.

No production optimization is authorized by Observation 331 or this benchmark.

---

# Current verdict

The study does not support one shared Flow engine.

It supports a narrower rule:

> Compress repeated derived computation, not the evidence distinctions that
> make the answer justified.

Transactions-Flow has a promising transient incidence/row-summary acceleration
boundary beside its retained Columns.

Stock-Flow has a promising fail-closed product summary for construction while
its public result is already appropriately compressed.
