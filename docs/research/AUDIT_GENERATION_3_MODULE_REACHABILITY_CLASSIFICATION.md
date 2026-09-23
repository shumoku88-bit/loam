# Generation 3 — module reachability classification correction

Status: **AUDIT INSTRUMENT REPAIRED**

## Trigger

The module-granularity inventory reported these as "production-like modules
unreachable from declared roots":

- `Loam.Examples.PhysicalInventory`
- `Loam.Examples.ScientificObservation`
- `Loam.Examples.ScientificFutureContext`

Each file is explicitly a non-household example/probe. None claims production
runtime ownership.

## Finding

The inventory excluded `Tests` and `Observations` from its production-like
unreachable count, but not the equally explicit `Examples` layer.

The modules were therefore not stale production surfaces. The observation
instrument was assigning the wrong population label.

## Repair

Exclude `Examples` only from the summary count:

```text
Production-like modules unreachable from declared roots
```

The modules remain fully present in the TSV, DOT graph, Markdown inventory, line
counts, dependency graph, and co-change evidence. No source module is hidden from
the audit.

## Expected result

At the current Generation-3 baseline the summary should stop reporting the three
Examples as production-like. Remaining unreachable production candidates stay
visible for individual interpretation, including the separately classified
`Loam.MerchantExpenseReview`.

## Decision

This is an audit-instrument correction, not a product-code simplification.

Do not make an Example reachable merely to satisfy a production reachability
metric, and do not delete a valid Example merely because no executable root imports
it.
