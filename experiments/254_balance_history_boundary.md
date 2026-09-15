# Observation 254 — balance image versus retained event history

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
main: 331f3f3f3de107f7de3e1e07d4effdc47c607d2f
Observation 253 / PR #926 merged
```

GitHub Actions qualification:

```text
workflow: Observation 254
run:      34988486301
job:      104446654261
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
```

Observed matrix:

```text
sameBalanceDifferentEventPartition                  SAT
selectedHistoriesDifferAtRegisterLevel              SAT
sameEventRegisterDifferentEffectMembership          SAT
BalanceImageDeterminesEventPartition                SAT counterexample
SelectedHistoriesHaveDifferentRegisterImage         UNSAT counterexample
EventRegisterDeterminesEffectMembership             SAT counterexample
```

## Trigger

Observations 250–253 qualified a balance-level connection among LOAM, an REA-shaped interpretation layer, and a Ledger/Pacioli-shaped additive denotation.

That result was intentionally silent about Event identity and register-level history. LOAM Core separately retains opaque stable `EventId`, while its quantity projections sum by `LocusId × MeasureId`. The public `ledger-semantics` README likewise states that its current oracle comparison covers balances and does not yet compare register report rows.

Observation 254 asks:

> Can distinct retained Event histories have exactly the same balance image, and how much event-level evidence is needed before the difference becomes observable again?

The bounded answer is yes: the balance image can erase Event partition, while an Event-indexed quantity view recovers the selected Joined/Split distinction but can still erase finer effect membership.

## Selected fixture

Four retained quantity effects are fixed:

```text
Cash1   CashLocus   JPY   -1
Cash2   CashLocus   JPY   -1
Goods1  GoodsLocus  JPY   +1
Goods2  GoodsLocus  JPY   +1
```

Two histories retain exactly the same effects.

`Joined`:

```text
EventA = Cash1 + Cash2 + Goods1 + Goods2
EventB = empty
```

`Split`:

```text
EventA = Cash1 + Goods1
EventB = Cash2 + Goods2
```

The balance image aggregates only by `Locus × Measure`. The register-shaped observation in this experiment additionally indexes the same exact quantities by Event identity.

## O254-1 — balance collision across distinct Event partitions

Qualified:

```text
sameBalanceDifferentEventPartition = SAT
BalanceImageDeterminesEventPartition = SAT counterexample
```

A balance image is therefore not sufficient evidence for retained Event partition in the selected model.

## O254-2 — Event-indexed quantities recover the selected Joined/Split distinction

Qualified:

```text
selectedHistoriesDifferAtRegisterLevel = SAT
SelectedHistoriesHaveDifferentRegisterImage = UNSAT counterexample
```

The selected one-Event/two-Event distinction becomes observable once Event identity participates in the query coordinate.

This does **not** imply that every register representation determines full history.

## O254-3 — event-indexed aggregate quantities may still forget finer Effect membership

The model gives two additional worlds, `RowLeft` and `RowRight`, freedom to assign equal-quantity effects to Event identities differently.

Qualified:

```text
sameEventRegisterDifferentEffectMembership = SAT
EventRegisterDeterminesEffectMembership = SAT counterexample
```

So adding Event identity to an aggregate register-shaped view is strictly stronger than the selected balance view, yet it is still not automatically a lossless encoding of all retained effect membership.

## Qualified information ladder

```text
retained Event/effect history
        |
        | forget finer membership
        v
Event-indexed quantity view
        |
        | forget Event partition / identity
        v
balance image by Locus × Measure
```

For the selected bounded fixture, both downward arrows are strictly information-losing.

This clarifies the scope of Observations 250–253: their balance-level commutation result is valuable precisely because it is a projection result. It does not license reconstructing retained history from the commuting balance image.

## Deliberate limits

This model does not formalize:

- the full `ledger-semantics` Register implementation;
- dates, payees, descriptions, posting order, or transaction syntax;
- LOAM correction/replacement provenance;
- anonymous-versus-keyed Effect retention policy beyond the selected atoms;
- valuation, prices, lots, booking, recognition, or tax policy;
- REA Agent, Resource, or duality semantics.

The selected `eventFlowAt` function is only a register-shaped event-indexed quantity observer used to locate the information boundary.

## Stop condition

Do not add a production Register, Transaction, or Effect-membership ontology merely because the counterexample exists.

The next useful pressure is narrower:

> Which already-retained LOAM identity is sufficient for the concrete register/history questions we actually want to answer, and where does anonymous Effect structure make exact round-trip recovery intentionally impossible?

That question should be tested before any new production surface is earned.
