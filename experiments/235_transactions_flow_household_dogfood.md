# Observation 235 — Does the Transactions-Flow incidence view reveal anything useful in current household Actual evidence?

Status: **QUALIFIED HOUSEHOLD VALUE — incidence semantics earned / dense grid rejected**

LOAM baseline: `1a2244311662115f91a3310d8ed7509e81cfbfdf`

Household data baseline: `shumoku88-bit/loam-data` `448ad1c68aba5d6b6a657d27c3c5fc7c833092d0`

Selected window:

```text
[2026-09-01, 2026-09-10)
```

This observation is a dogfood measurement over the current household evidence. It adds no production code, no copied household journal, no new canonical authority, and no new report ontology.

## Starting point

Observation 233 qualified the mechanically safe primitive:

```text
row    = EffectCoordinate = (LocusId, MeasureId)
column = Event
cell   = exact signed Quantity
```

Observation 234 qualified the existing correction-aware `ActualReview.Record` boundary as sufficient for selecting one explicit half-open matrix window.

The remaining question is human rather than mechanical:

> Does keeping the Event dimension visible reveal something that Stock–Flow net change and a sequential journal hide?

## Current household measurement

For the selected September window, the current retained Actual evidence yields:

```text
Event columns                  44
EffectCoordinate rows          17
possible dense cells          748
nonzero cells                  99
nonzero density              13.2%
```

All represented selected coordinates in this window use JPY. Every selected Event has zero JPY residual.

The dense matrix is therefore mathematically valid but visually mostly empty:

```text
86.8% of possible cells are zero
```

That is the first dogfood result:

> **Do not promote the literal dense zero grid as the production presentation.**

The incidence semantics survive; the naive rendering does not.

## What net change hides

The useful signal appears where positive and negative activity cancel inside one row total.

### Cash

Across the selected window:

```text
cash net change       0 JPY
positive activity  +30,000 JPY
negative activity  -30,000 JPY
gross activity      60,000 JPY
active Events            2
```

The two current observations are structurally very different despite cancelling exactly in the period total:

```text
2026-09-01  lesson income from B-chan   cash +30,000
2026-09-06  cash -> smbc                cash -30,000
```

A closing-minus-opening or row-total-only view says only:

```text
cash: 0
```

The incidence view says:

```text
cash moved substantially and returned to the same net position
```

No source/destination pairing needs to be invented to see that fact.

### PayPay

Across the same window:

```text
paypay net change        +147 JPY
positive activity     +11,286 JPY
negative activity     -11,139 JPY
gross activity         22,425 JPY
active Events               26
```

Again, the net value is tiny relative to the amount of observed movement.

This is not merely a balance fact. It is a **circulation / churn observation**:

```text
large two-sided activity
+
small final net change
```

The matrix preserves the Event contributions that make that distinction visible.

### SMBC

The same pattern appears at another scale:

```text
smbc net change        +1,963 JPY
positive activity     +30,000 JPY
negative activity     -28,037 JPY
gross activity         58,037 JPY
active Events               24
```

A single net number discards most of the period's movement structure.

## Selected row totals

The period row totals remain useful as one margin of the matrix:

```text
lesson-income   -30,000
point                -94
point-income         -59
cash                   0
paypay              +147
snacks              +354
food-stock          +356
learning            +718
shipping            +720
transport           +773
household-goods    +1,526
coffee             +1,912
smbc               +1,963
tobacco            +4,500
wifi               +4,810
book               +5,565
food               +6,809
```

The selected JPY row totals sum to exact zero.

That conservation is an observation of this current window, not a new universal Core Event law.

## Value beyond Stock–Flow

Stock–Flow answers a boundary question well:

```text
opening
+ net change
= closing
```

The incidence view answers a different question:

```text
which Event contributions produced that net change?
```

The cash example is the clearest separator:

```text
Stock–Flow row margin: 0
Incidence structure:   +30,000 then -30,000 in distinct Events
```

The matrix therefore earns explanatory value even when its row total adds no new quantity.

## Value beyond Recent Journal

A chronological journal already contains every Event, so the incidence view does not reveal new canonical facts.

Its value is structural alignment:

```text
same EffectCoordinate
across many Events
visible on one axis
```

That makes repeated contribution, cancellation, churn, and sparse participation easier to inspect than scanning a sequential journal entry by entry.

This is a change of lens, not a new authority.

## Dense presentation rejected

The full current window would be approximately:

```text
17 rows × 44 Event columns
```

with only 99 nonzero cells.

A terminal surface that renders all 748 cells would spend most of its visual budget showing zero and would require awkward horizontal navigation.

The production presentation should therefore preserve the incidence semantics but use one or more sparse/focused forms such as:

```text
selected coordinate -> contributing Events only
selected Event      -> nonzero coordinates only
row summary          -> net / positive / negative / gross / count
paged sparse matrix  -> omit zero-only visual space
```

These are presentation candidates, not new semantic primitives.

## Qualified production direction

Observation 235 qualifies a small next step:

```text
shared TransactionsFlowReview
  built over ActualReview
  with explicit half-open window
  EffectCoordinate rows
  Event columns
  exact cells
  row totals
  per-Measure Event residuals
```

It does **not** qualify a dense TUI matrix yet.

The shared review boundary is worth promoting because:

1. Observation 233 qualified the incidence semantics;
2. Observation 234 qualified reuse of the existing correction/date boundary;
3. current household evidence demonstrates explanatory value beyond net change;
4. no source/destination relation or second semantic engine is required.

## Still rejected

The household dogfood does not authorize:

- Locus-to-Locus flow edges;
- Sankey arrows;
- inferred source/destination pairing;
- transfer classification from sign;
- AccountingRole interpretation hidden inside the primitive;
- Purpose interpretation hidden inside the primitive;
- cross-Measure addition;
- a dense 17 × 44 zero-heavy production screen;
- any new canonical writer or persistence format.

## Result

The original Report Semantics hypothesis survives in a narrower and stronger form:

```text
Transactions-Flow Matrix semantics       KEEP
Locus-to-Locus inferred flow             REJECT
literal dense zero grid                  REJECT
sparse/focused incidence presentation    INVESTIGATE
shared read-only review boundary          EARNED
```

The important gain is not another conventional report. It is a lens that can say:

> "This coordinate ended almost where it started, but a large amount moved through it during the period."

That distinction is invisible in the net alone and requires no invented edge to recover.
