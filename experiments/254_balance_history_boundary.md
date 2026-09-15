# Observation 254 — balance image versus retained event history

Status: **EXPERIMENT — Alloy qualification pending**

Baseline:

```text
shumoku88-bit/loam
main: 331f3f3f3de107f7de3e1e07d4effdc47c607d2f
Observation 253 / PR #926 merged
```

## Trigger

Observations 250–253 qualified a balance-level connection among LOAM, an REA-shaped interpretation layer, and a Ledger/Pacioli-shaped additive denotation.

That result was intentionally silent about Event identity and register-level history. LOAM Core separately retains opaque stable `EventId`, while its quantity projections sum by `LocusId × MeasureId`. The public `ledger-semantics` README likewise states that its current oracle comparison covers balances and does not yet compare register report rows.

Observation 254 therefore asks:

> Can distinct retained Event histories have exactly the same balance image, and how much event-level evidence is needed before the difference becomes observable again?

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

## Expected matrix

### O254-1 — balance collision across distinct Event partitions

Expected:

```text
sameBalanceDifferentEventPartition = SAT
BalanceImageDeterminesEventPartition = SAT counterexample
```

If qualified, a balance image is not sufficient evidence for retained Event partition.

### O254-2 — Event-indexed quantities recover the selected Joined/Split distinction

Expected:

```text
selectedHistoriesDifferAtRegisterLevel = SAT
SelectedHistoriesHaveDifferentRegisterImage = UNSAT counterexample
```

This does **not** claim that every register representation determines full history. It only checks that the selected one-Event/two-Event distinction becomes observable once Event identity participates in the query coordinate.

### O254-3 — event-indexed aggregate quantities may still forget finer Effect membership

The model gives two additional worlds, `RowLeft` and `RowRight`, freedom to assign equal-quantity effects to Event identities differently.

Expected:

```text
sameEventRegisterDifferentEffectMembership = SAT
EventRegisterDeterminesEffectMembership = SAT counterexample
```

If qualified, adding Event identity to an aggregate register view is strictly stronger than a balance view but is still not automatically a lossless encoding of all retained effect membership.

## Intended information ladder

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

Observation 254 is looking for strictness of these forgetful steps, not for a new production report type.

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

Do not add a production Register, Transaction, or Effect-membership ontology merely because the counterexample exists. A later observation should ask which currently retained LOAM identities are actually required by concrete register/history questions before any new production surface is earned.
