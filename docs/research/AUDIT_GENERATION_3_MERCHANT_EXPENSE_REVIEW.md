# Generation 3 — Merchant Expense Review boundary

Status: **KEEP_BOUNDARY / DEFER_SURFACE**

## Trigger

The module-granularity inventory currently reports
`Loam.MerchantExpenseReview` as production-like but unreachable from declared
Lake roots.

That signal requires interpretation. Unreachable is a candidate observation, not
by itself a retirement verdict.

## History

The Merchant line was deliberately promoted in Observations 266–269:

- O266 qualified, with Alloy, the narrow household question:
  "How much Expense-role quantity is associated with the same merchant identity
  across current Events in one Measure/window?"
- O269 selected a production promotion boundary ending at the first exact
  Merchant query seam.
- PR #1024 implemented that seam as `Loam.MerchantExpenseReview`.
- PR #1025 separately connected Event Merchant classification to the production TUI.
- PR #1084 later narrowed exactness to query-relevant coverage rather than
  requiring unrelated Merchant classification.

The retained EventMerchant evidence is therefore live production vocabulary,
not abandoned research provenance.

## Current topology

```text
normalized Actual
  |-- current Event/Effect/date evidence
  |-- EventMerchant disposition
  |
  +--> TransactionsFlowReview
  |          |
  |          +-------------------+
  |                              |
AccountingRole authority         |
  |                              |
  +------------------------------+
                 |
                 v
       MerchantExpenseReview
                 |
                 v
       exact / unresolved answer

presentation surface: deliberately deferred
```

The review owns no Merchant amount authority. It derives signed Expense-role
quantity and exposes two independent incompleteness frontiers:

- unresolved Merchant disposition on query-relevant Events;
- unresolved AccountingRole on relevant Effects of the selected Merchant.

## Roadmap relationship

Issue #1095 ranks **Merchant / Counterparty Analysis** as `LATER`.

That decision is interpreted narrowly:

```text
KEEP shared exact answer boundary
DEFER TUI/Web report surface
DO NOT add report inventory merely because the calculation exists
```

It is not evidence that the already-qualified query boundary should be deleted.

## Why this differs from the retired read-only Attention surface

The former `Loam.Tui.Attention` responsibility was superseded by
`AttentionAdministration` at both production entrances.

`MerchantExpenseReview` has no replacement. Its current lack of a presentation
consumer is the intended roadmap stop point, while the semantic question and its
qualified answer remain independently meaningful.

## Tool choice

No new Alloy model is added here because O266 already established the relevant
information boundary and O269 selected its production promotion.

No new Lean theorem is added because this audit asks ownership/reachability rather
than a new algebraic law.

The appropriate evidence is:

- module reachability;
- Git/PR history;
- the already-qualified Alloy result;
- focused Lean executable tests;
- current report-roadmap policy.

## Decision

`Loam.MerchantExpenseReview` = **KEEP_BOUNDARY / DEFER_SURFACE**.

Revisit when one of these occurs:

1. household use asks the Merchant question often enough to earn a TUI/Web/AI
   presentation;
2. a newer shared projection subsumes the exact same answer and unresolved
   witnesses;
3. Merchant evidence itself is retired or reshaped;
4. multi-seller Event pressure invalidates the current Event-scoped Merchant model.

Until then, do not add a report merely to make the module executable-root
reachable, and do not delete the exact query merely to make the reachability
inventory numerically zero.
