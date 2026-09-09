# Observation 236 — Can Transactions-Flow stay legible without rendering the dense incidence matrix?

Status: **QUALIFIED — coordinate-first sparse summary + focused contributors / RESEARCH_ONLY**

Research baseline: LOAM `ca4d6316ff8b9d26a344bba157a7289c53974b23`

Qualified head: `489c68781bb5892a20454326f6f1e3dd497bc73a`

Dedicated workflow: Observation 236 run `34322750907`, job `102372908824`, **SUCCESS**.

## Trigger

Observations 233–235 qualified the Transactions-Flow incidence semantics and the production `TransactionsFlowReview` now exposes them without inventing source/destination edges.

Household dogfood also rejected the literal dense presentation. In the selected real window `[2026-09-01, 2026-09-10)`:

```text
44 Event columns
17 EffectCoordinate rows
748 possible cells
99 nonzero cells
13.2% density
```

The semantic matrix is useful; printing its zero rectangle is not.

Observation 236 therefore asks a presentation-only question:

> Can one sparse coordinate summary preserve the matrix's distinctive information, while a focused detail shows only the Event witnesses that actually changed the selected coordinate?

No production TUI state or report query is changed by this observation.

## Candidates

### A. Dense matrix

```text
coordinate × every Event column
```

Rejected by Observation 235. It preserves evidence but spends most screen width and height on zero cells. It also becomes unusable as the selected period grows.

### B. Event-first sparse list

```text
date | Event | nonzero Effects
```

Mechanically safe, but too close to Recent Journal. It does not foreground the key Transactions-Flow question: which household coordinates moved substantially even when period net change is small or zero?

### C. Coordinate-first sparse summary + focused contributors

**Qualified candidate.**

Summary shape:

```text
Coordinate       Net       Gross      Positive    Negative    Events
cash/jpy           0       60000         30000      -30000       2
smbc/jpy       28085       31915         30000       -1915       2
lesson-income  -30000      30000             0      -30000       1
book/jpy        1915        1915          1915           0       1
```

Focused detail for `cash/jpy`:

```text
2026-09-01  +30000  lesson income
2026-09-06  -30000  cash -> smbc
```

The summary is not a replacement accounting classification. `Positive` and `Negative` are signed quantity arithmetic only. They do not mean income/expense, debit/credit, source/destination, or good/bad.

## Why gross activity is useful

The real household dogfood supplied the strongest witness:

```text
cash/jpy
net      0
gross    60000
positive 30000
negative -30000
```

A net-only report erases the movement. A dense matrix preserves it but surrounds it with zeros. The sparse row preserves both the surprising cancellation and its scale.

For the first presentation experiment, rows are ordered by descending gross activity. This is explicitly a presentation salience heuristic, not canonical priority or accounting importance. Stable coordinate spelling is only a deterministic tie-break.

## Mechanical result

The Lean experiment derives all presentation data from the production `TransactionsFlowReview.Snapshot`:

```text
row summary
  = TransactionsFlowReview.rowActivity

focused contributors
  = selected Event columns whose Event.quantityAt coordinate != 0
```

The successful exact-head run checks:

```text
zero-net cash circulation remains visible
cash net = 0
cash gross = 60000
cash active Event count = 2

focused cash detail contains exactly:
lesson +30000
deposit -30000

no unrelated zero Event appears in that detail

dense fixture cells = 12
sparse contribution lines = 6

gross ranking keeps cash first
```

No matrix cells are copied into a second retained representation.

The initial workflow failure was infrastructure-local: the newly promoted production `TransactionsFlowReview` had not yet been built into the observation cache. Adding an explicit `lake build Loam.TransactionsFlowReview` before the probe resolved that without any production source change.

## Qualified interaction candidate

The smallest production TUI candidate is now:

```text
Reports
  Transactions Flow
    explicit shared report window

summary mode
  Up/Down     select coordinate
  Enter       focused contributors

focus mode
  Up/Down     browse only contributing Events
  Back/Escape summary
```

The existing report window editor should be reused. No Transactions-Flow-specific date editor is earned.

The first production surface should not add filtering, sorting menus, charts, Sankey edges, or configurable grouping. Those can be considered only after dogfood demonstrates pressure.

## Promotion gate

A TUI promotion must show:

```text
+ reuses TransactionsFlowReview exactly
+ reuses existing Reports window coordinates
+ no dense zero grid
+ zero-net / high-gross rows remain visible
+ focused detail contains only canonical contributing Events
+ no second cursor/window abstraction if existing Reports state suffices
+ Production TUI CI parity
```

## Non-claims

Observation 236 does not authorize:

- inferred Locus-to-Locus flow;
- Sankey edges;
- accounting-role inference from sign;
- Purpose grouping;
- cross-Measure addition;
- gross activity as importance or risk;
- persistence of matrix cells or presentation rows;
- a new report-window abstraction;
- additional presentation features beyond the qualified sparse summary/detail candidate without new pressure.
