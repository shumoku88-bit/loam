# Observation 248 — Derived Actual unrouted Expense frontier

Status: **ACTIVE PROBE — research-only derived frontier; production semantics unchanged**

Baseline:

```text
ab1045fc77ca5fe0a5a8b45d31b3446413711ebc
Observation 247 branch head
```

Observation 247 qualified a narrower information distinction:

```text
selected managed Consumption value
!=
completeness of Actual Purpose classification
```

The remaining question is not whether to add an `Answerability` framework. It is smaller:

> Can the open Actual-classification part of CurrentCoverage be exposed as a pure derived list of in-window Expense coordinates that were `unrouted` at each Event's own valid coordinate, while reusing current correction, validity, routing and AccountingRole semantics?

## Candidate derived row

Observation-local only:

```text
EventId
Actual valid coordinate
EffectCoordinate = Locus × Measure
signed aggregate Quantity at that Event/Locus/Measure
```

The row has no independent identity and is not retained state.

Routing is Locus-scoped, so multiple Effects at the same Event/Locus/Measure are aggregated through existing `Event.quantityAt` rather than creating repeated frontier rows or inventing Effect-level routing identity.

## Selection rule under test

For the selected current elapsed window and Measure:

```text
1. apply the admitted Event correction frontier;
2. require ActualValidity for every current frontier Event before deciding window membership;
3. select Events with start <= validOn <= observedAt;
4. enumerate represented Loci for the selected Measure;
5. retain only Loci with explicit AccountingRole.expense;
6. inspect ActualRouting at RoutingEffective.dated(validOn);
7. surface only status = unrouted.
```

Important omissions:

- no positivity requirement: negative Expense refunds remain classification evidence;
- no Asset/Liability/Income/Equity fallback rule;
- no use of current routing in place of Event-valid routing;
- no retroactive interpretation of later routes;
- no stored completeness bit;
- no new authority, persistence or canonical data.

## Executable bounded cases

The Lean witness checks that the derived frontier:

- includes an in-window unrouted positive Expense;
- includes an in-window unrouted negative Expense refund;
- includes an Expense whose route becomes managed only after its Event-valid coordinate;
- applies Event correction first, excluding a superseded target and retaining its replacement;
- excludes managed Expense;
- excludes explicitly unmanaged Expense;
- excludes out-of-window Expense;
- excludes another Measure;
- excludes an unrouted Asset payment coordinate;
- fails closed on an invalid current window;
- fails closed when a current correction-frontier Event lacks ActualValidity.

The correction witness deliberately omits ActualValidity for the superseded target. Success therefore demonstrates that the candidate does not accidentally traverse raw pre-frontier Event history.

## Why signed quantity is retained

Current Consumption is signed. A refund at an Expense Locus can reduce Consumption. Dropping negative quantities from the frontier would create a different classification semantics from the projection whose completeness is being examined.

Therefore the candidate asks whether the coordinate is resolved, not whether its quantity is positive.

## Why this is still research-only

Even if the derived list is mechanically sufficient, that does not prove it deserves:

- a production type;
- a CurrentCoverage field;
- a Review boundary;
- TUI presentation;
- a generalized Answerability abstraction.

The experiment first tests whether the unresolved information can be reconstructed cheaply from evidence LOAM already retains.

## Production gate

If the witness qualifies, the next decision is architectural rather than semantic:

> Is this frontier useful enough in real CurrentCoverage dogfood to graduate as one small derived production projection, preferably beside existing Consumption logic, without creating a parallel routing engine?

A production candidate should either share the exact event/window/routing selection mechanics with Consumption or remain ungraduated. Duplicated semantics that can drift are not an acceptable price for presentation convenience.

## Stop rules

```text
Do not add retained ConsumptionComplete state.
Do not reinterpret later routing retroactively.
Do not treat all unrouted loci as blockers.
Do not drop signed refunds from classification closure.
Do not introduce Effect-level routing identity.
Do not mutate loam-data from this bounded witness.
Do not create a generic Answerability framework from one frontier.
```
