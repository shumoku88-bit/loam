# Observation 249 — Cash-flow classification is not derivable from current role evidence

## Question

Can LOAM derive a formal Cash Flow Statement classification (`Operating`, `Investing`, `Financing`) from the accounting evidence it already has, without retaining or selecting another independent classification?

Current production already has strong ingredients:

- correction-aware Actual Events;
- exact signed transaction incidence;
- explicit `AccountingRole` (`Asset`, `Liability`, `Equity`, `Income`, `Expense`);
- explicit report windows;
- Transactions-Flow and RoleFlow projections.

The missing question is narrower:

> Does transaction incidence plus `AccountingRole` uniquely determine the conventional cash-flow class?

## Why Alloy

This is a distinguishability question, not an arithmetic or UI question.

We need only one bounded counterexample where two worlds agree on the evidence currently available to the proposed projection but require different correct cash-flow classifications.

The final model therefore keeps only the exact symbolic incidence shape needed by the question:

```text
cash-out quantity slot
counterpart-in quantity slot
counterpart AccountingRole
```

Both worlds receive the same quantity atoms. Integer arithmetic is deliberately absent because balance arithmetic cannot explain a difference in report classification once the observed transaction shape is fixed.

The independently observable economic distinction remains outside that current projection.

## Two pressure pairs

The bounded examples encode two familiar collisions.

### Asset-role collision

```text
cash -> Asset
```

can represent either:

- an inventory / ordinary operating acquisition -> `Operating`;
- a long-lived equipment acquisition -> `Investing`.

Both expose the same `Asset` accounting role and the same modeled incidence quantities.

### Liability-role collision

```text
cash -> Liability
```

can represent either:

- settlement of an ordinary trade payable -> `Operating`;
- repayment of borrowing principal -> `Financing`.

Both expose the same `Liability` accounting role and the same modeled incidence quantities.

The examples are intentionally schematic. The claim is not that these four economic kinds should become LOAM ontology. They witness that the existing coarse accounting role is insufficient to force one formal cash-flow class.

## Qualified Alloy 6.2.0 results

```text
sameAssetRoleEvidenceDifferentCashFlowClass          SAT
sameLiabilityRoleEvidenceDifferentCashFlowClass      SAT
CurrentLoamEvidenceDeterminesCashFlowClass            SAT  (counterexample)
ExplicitCashFlowClassificationDeterminesReportClass   UNSAT
```

Interpretation:

- the first two SAT witnesses demonstrate concrete collisions under current coarse evidence;
- the failed determination assertion shows that current incidence + `AccountingRole` cannot uniquely derive a formal cash-flow class;
- the final UNSAT check shows that an explicit three-way classification is sufficient for this narrow report-class question once supplied consistently.

An earlier probe coupled the distinguishability question to unnecessary bounded integer arithmetic and accidentally made the entire candidate world unsatisfiable. That arithmetic was removed rather than weakening the expected result: Observation 249 is about information sufficiency, so only the shared observed incidence shape belongs in this model.

## Architectural consequence if qualified

A formal Cash Flow Statement should **not** be implemented by guessing from:

- sign;
- `AccountingRole` alone;
- Locus spelling;
- Purpose naming;
- Transactions-Flow row shape.

If product pressure later requires this report, LOAM will need an independently justified classification or selected reporting policy at an appropriate boundary.

This experiment does **not** decide:

- whether the evidence should attach to Event, Effect, Locus, relation, or another subject;
- whether one universal `CashFlowClass` is the right production vocabulary;
- how jurisdiction-specific policy choices should be represented;
- whether household dogfood currently needs the report at all.

Those remain future design questions.

## Stop rule

Observation 249 is research-only. The SAT counterexamples earn only the statement:

> current retained role/incidence evidence is insufficient to derive the formal cash-flow category uniquely.

It does not authorize a production authority, persistence format, report engine, or UI surface.
