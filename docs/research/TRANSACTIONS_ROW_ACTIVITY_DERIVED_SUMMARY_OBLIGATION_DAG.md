# G2-023 — Transactions RowActivity derived-summary obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY CANDIDATE**

Primary instruments: **DRAKONview + obligation DAG + production-consumer reachability**.

## Question

G2-023 follows the result-shape pressure exposed by G2-022, but does not assume every report should be compressed the same way.

The adjacent read boundaries were compared first:

- `StockFlowReview.Snapshot` already derives `netChange` and `reconstructedEnd`;
- `BudgetWindowReview.Row` already derives `remaining`;
- `RoleFlowReview` retains coordinate rows and unresolved witnesses rather than presentation totals;
- `RoleBalanceReview` retains its three evidence partitions rather than presentation aggregates.

The remaining pressure is inside `TransactionsFlowReview.RowActivity`.

Before G2-023 it retained:

```text
net
positive
negative
gross
activeEvents
```

But the row constructor already partitions every nonzero Event contribution into exactly one of two signed sums:

```text
positive >= 0
negative <= 0
```

Therefore:

```text
net   = positive + negative
gross = positive - negative
```

No additional Event, coordinate, role, date, ordering or classification evidence enters either value.

## Obligation graph

For one exact `EffectCoordinate`:

```text
selected Event columns
        |
        v
quantityAt coordinate for each Event
        |
        +--------------------------+
        |                          |
        v                          v
quantity > 0                  quantity < 0
        |                          |
        v                          v
positive partition           negative partition
        |                          |
        +------------+-------------+
                     |
                     v
          retain positive + negative
                     |
          +----------+-----------+
          |                      |
          v                      v
net = positive + negative   gross = positive - negative

nonzero contributing Event count
        |
        v
retain activeEvents
```

`activeEvents` is not derivable from the two quantity partitions. Two rows may have identical positive and negative sums but different numbers of contributing Events, so it remains independent state.

## Why the old shape was redundant

A public `RowActivity` could previously represent internally contradictory combinations such as:

```text
positive = 100
negative = -40
net      = 999
gross    = 1
```

Production `rowActivity` never emitted such a contradiction, but the result type represented four arithmetic values as if they were independent.

The Generation-2 rule is narrower:

```text
retain independent answer components
derive exact arithmetic consequences
```

G2-023 therefore keeps:

```text
positive
negative
activeEvents
```

and exposes same-named derived reads:

```text
activity.net
activity.gross
```

Generalized field notation preserves the production call shape.

## Constructor compression

Before G2-023 the fold retained four running integers:

```text
positive
negative
gross
activeEvents
```

The gross accumulator duplicated the absolute-value consequence of the signed partitions.

The fold now retains only:

```text
positive
negative
activeEvents
```

and constructs a smaller `RowActivity`.

This is implementation compression, not a new semantic rule.

## Consumer reachability

Repository-wide use shows:

- `Loam/Tui/Reports.lean` consumes `activity.gross` for sparse row ordering and renders row summaries;
- `Loam/Tests/TransactionsFlowReview.lean` checks `net`, signed partitions, `gross`, and `activeEvents`;
- no production or test caller constructs `RowActivity` directly;
- `rowActivity` is the single production constructor found for this result type.

Therefore same-named derived functions preserve current read usage while removing contradictory stored copies.

## Preserved boundaries

G2-023 does **not** change:

- selected Event columns or their date/window admission;
- correction-aware `ActualReview` semantics;
- row coordinate derivation;
- `cellAt`;
- `rowTotal`;
- sparse row selection;
- gross-based presentation ordering;
- contributor counts;
- measure residual evidence;
- any accounting-role, transfer, inflow/outflow, debit/credit, income or expense interpretation.

The arithmetic remains intentionally role-neutral.

## Stop point

G2-023 does not remove `positive` or `negative` merely because both can be recomputed from the original Event columns.

Those two partitions are the independently useful two-sided row summary that Observation 236-era presentation pressure introduced: a near-zero net must not hide substantial activity on both sides.

Likewise `activeEvents` stays retained because quantity totals do not determine contributor count.

No generic `DerivedSummary`, report superclass, or shared aggregation framework is added.

## Qualification target

Existing qualification must continue to prove:

- exact row net;
- exact positive and negative partitions;
- exact gross activity;
- exact active Event count;
- sparse Transactions-Flow ordering and rendering;
- neighboring Reports behavior.

If direct Transactions-Flow and production Reports workflows remain green, record:

**G2-023: SIMPLIFY QUALIFIED — Transactions RowActivity retains only positive, negative and activeEvents; net and gross are derived exact consequences of the signed partitions.**
