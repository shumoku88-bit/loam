# Stock-Flow Fusion Harvest — 2026-09-26

Status: **PRODUCTION PROMOTED / historical witness graduated**

This note records the second concrete harvest from the repository-wide
mathematical compression survey.

It follows the Transactions-Flow seedless RowIndex harvest, but the mathematical
shape is different. Stock-Flow pressure is dominated by repeated traversals of
the same admitted Actual review records and repeated selected-coordinate
membership tests inside each Event.

## Existing production shape

At the start of this study, `StockFlowReview.project` performs:

```text
selected Balance coordinates
    -> validateSelectedDates(records)

records
    -> boundaryQuanta(start)

records
    -> boundaryQuanta(endExclusive)

records
    -> windowChanges(start, endExclusive)
```

The selected Event quantity is derived by scanning Event Effects and testing:

```text
effect.coordinate ∈ selectedCoordinates
```

against a List.

Therefore two independent repeated-work questions exist:

1. repeated Record traversal and repeated Event-local quantity computation;
2. repeated linear List membership for each Effect.

## Already-qualified basis

Merged Observations 322–324 established:

- Observation 322: the three numeric Record folds factor into one product scan;
- Observation 323: fail-closed selected-date validation and numeric accumulation
  factor into one left-to-right Record traversal with the same first error;
- Observation 324: the public shell factors through a small BalanceImage, one
  fail-closed Scan, endpoint gates, and the final parity check.

Observation 324 deliberately stopped before a production change.

## Observation 332 — selected-coordinate support is set-like

Observation 332 proves for arbitrary coordinate Lists and Events that a
transient `CoordinateKey -> Unit` HashMap contains exactly the same selected
coordinate support as List membership.

It also proves:

```text
trackedQuantaSupport(buildSupport coordinates, event)
    =
trackedQuantaList(coordinates, event)
```

and that duplicate coordinates do not change tracked Event quantity.

Therefore coordinate order and multiplicity carry no independent numeric
meaning at the inner Stock-Flow membership boundary.

## Observation 333 — one selected quantity per current Event

Historical Observation 333 closed the last research-local duplication in the
original fused Stock-Flow candidate: validation and numeric accumulation no
longer needed separate selected-quantity computations for the same current
Record.

That result was promoted by PR #1323. Production moved to one left-to-right
fail-closed Record scan in which the exact selected Event quantity is computed
once and then drives date admission and window activity.

The later bounded-history promotion in PR #1399 changed the surrounding
Stock-Flow decomposition again. Historical start quantity is now justified by
`HistoricalBalanceReview` rather than reconstructed as another accumulator of
the same window scan. The remaining production rule is therefore smaller:

```text
current selected Record
    -> selected Event quantity once
    -> date admission when quantity != 0
    -> signed window activity
```

Observation 333's executable reference-vs-candidate wrapper has consequently
graduated to Git history. Current ownership is the production
`StockFlowReview.scanWindow` path plus its focused refusal and arithmetic
regression tests.

## Paired measurement

A temporary benchmark compared three shapes on the same synthetic admitted
inputs:

```text
A production
    validation + three numeric passes
    List membership

B fused-list
    one Record pass
    one selected quantity per current Event
    List membership

C fused-set
    one Record pass
    one selected quantity per current Event
    transient HashMap membership
```

Every timed result was retained and compared after timing. Candidate results had
to equal the public production `StockFlowReview.project` result exactly.

Qualified benchmark commit:

    928657ee4c2b43d48de7d28c70c5e35b63354013

GitHub Actions run:

    36213396550 — SUCCESS

Runner:

    ubuntu-24.04

Fixture:

- one selected Effect per Event;
- selected coordinate rotates through the selected universe;
- all Records current;
- valid dates distributed before, inside and after the requested window;
- three paired repetitions with execution order rotated.

| Selected coordinates | Events | Production | Fused List | Fused Set | Production / List | Production / Set | List / Set |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 2,000 | 13.5 ms | 10.4 ms | 12.5 ms | 1.30x | 1.08x | 0.82x |
| 4 | 10,000 | 67.6 ms | 51.9 ms | 62.1 ms | 1.30x | 1.08x | 0.83x |
| 16 | 2,000 | 20.7 ms | 13.5 ms | 12.6 ms | 1.52x | 1.64x | 1.07x |
| 16 | 10,000 | 104.7 ms | 67.8 ms | 63.4 ms | 1.54x | 1.65x | 1.06x |
| 64 | 2,000 | 49.8 ms | 25.9 ms | 12.9 ms | 1.92x | 3.84x | 1.99x |
| 64 | 10,000 | 251.7 ms | 131.2 ms | 64.1 ms | 1.91x | 3.92x | 2.04x |
| 256 | 2,000 | 163.2 ms | 74.7 ms | 14.1 ms | 2.18x | 11.56x | 5.29x |
| 256 | 10,000 | 833.5 ms | 379.7 ms | 65.4 ms | 2.19x | 12.73x | 5.80x |

## Interpretation

### Record-scan fusion is the broad production candidate

The fused List candidate improved every measured case.

At four selected coordinates it is already about 1.30x faster than current
production, without introducing a second coordinate representation.

Its benefit grows with the selected-coordinate universe because production
repeats the same Event-local work across multiple Record passes.

This is the narrowest earned production change:

```text
keep selected coordinates as List
keep Event evidence unchanged

replace:
    validation pass
    + start-boundary pass
    + end-boundary pass
    + window-change pass

with:
    one left-to-right fail-closed scan
    one selected Event quantity per current Record
```

### Finite-set support is qualified but not the first production move

HashMap support has a clear crossover.

With four selected coordinates it is slower than fused List and only about 1.08x
faster than current production.

At sixteen coordinates it begins to win slightly.

At sixty-four and two-hundred-fifty-six coordinates it becomes substantially
better, reaching about 3.9x and 12.7x versus current production respectively.

That makes finite-set support a real scaling tool, but not a universal
simplification for today's small-selection path.

Adding a threshold or hybrid representation now would increase production
mechanism count. The simpler choice is to retain Observation 332 as qualified
evidence and defer production support-index promotion until real selection
cardinality creates pressure.

## Production decision boundary

PR #1323 promoted the measured one-scan candidate. PR #1399 later separated
historical-start reconstruction from window-flow accumulation, so the current
production decomposition is:

```text
HistoricalBalanceReview
    -> justified start quantity

StockFlowReview.scanWindow
    -> selected coordinates
    -> ONE fail-closed current-Record scan
       - compute tracked Event quantity once
       - require/validate occurrence date only when quantity != 0
       - update signed window partitions

CurrentBalanceReview
    -> independently justified current tracked quantity
```

Keep:

- exact support ownership for historical and current balances;
- selected coordinate List representation;
- exact endpoint/refusal ordering;
- zero-quantity undated acceptance;
- superseded Record inertness;
- public Snapshot shape and presentation.

Do not add merely for this optimization:

- persistent summary state;
- retained indexes;
- a List/HashMap threshold;
- generic aggregation machinery;
- a new Stock-Flow authority.

The transient support-index variant remains mathematically qualified and
measurably valuable only under larger coordinate-cardinality pressure. It is
still research-only.

## Verdict

**Harvest #2 promoted and subsequently simplified: Stock-Flow performs one
fail-closed selected-record window scan with one selected Event quantity
computation per current Record, while historical boundary reconstruction now
belongs to its separately qualified support boundary.**
