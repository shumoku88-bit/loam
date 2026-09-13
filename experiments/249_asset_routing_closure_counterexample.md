# Observation 249 — Expense-only Actual closure is not a general CurrentCoverage boundary

Status: **ACTIVE COUNTEREXAMPLE — production semantics unchanged**

Baseline:

```text
Observation 248 head
102aaf6501327b260156e815380123003d6ffec1
```

## Question

Observation 248 qualified one bounded frontier:

```text
in-window
+ selected Measure
+ AccountingRole.expense
+ Event-valid ActualRouting = unrouted
```

That frontier is useful for Expense routing administration. The next question is stronger:

> If the Expense-only frontier is empty, is the selected CurrentCoverage Actual classification necessarily closed?

Observation 249 answers **no**.

## Real household pressure that found the counterexample

The household Capacity evidence intentionally contains the Purpose `ゆうちょ貯金`, admitted from an HRA transfer source:

```text
2026-08-17  unallocated -> ゆうちょ貯金  5000 jpy
2026-08-29  ゆうちょ貯金 -> unallocated  5000 jpy
```

Canonical Actual contains:

```text
2026-08-18  smbc  -5000 jpy
            yucho +5000 jpy
```

`yucho` is explicitly `AccountingRole.asset`, and current Actual routing has no `yucho` route.

This matters because production Consumption does not consult AccountingRole. It consumes any Locus whose Event-valid Actual route is `managed queriedPurpose`.

Therefore `AccountingRole.expense` is a valid administrative narrowing, but it is not by itself a semantic proof that all CurrentCoverage-relevant routing has been classified.

## Minimal executable counterexample

The Lean witness removes household names and keeps only the necessary distinctions:

```text
Capacity:
  unallocated -> savings Purpose   5000

Actual at coordinate 2:
  bank          -5000   AccountingRole.asset
  savings-asset +5000   AccountingRole.asset
```

Two routing worlds share identical Capacity and Actual:

```text
OPEN
  savings-asset = unrouted

ROUTED
  savings-asset -> savings Purpose
  visible at Event.validOn
```

The Expense-only frontier is empty in both worlds because every Actual Locus is an Asset.

Yet CurrentCoverage changes:

```text
                 OPEN    ROUTED
Entitlement       5000      5000
Consumption          0      5000
Remaining          5000         0
Headroom           5000         0
Expense frontier      0         0
```

So:

```text
Expense-only frontier = empty
```

does **not** imply:

```text
CurrentCoverage classification is closed
```

## Architectural consequence

The missing concept is not another stored completeness bit. The unresolved question is the domain of routing obligation:

> Which Actual Loci are required to have Purpose routing for this CurrentCoverage question?

AccountingRole answers a different question: financial-statement role. It happens to be useful for the existing Expense routing administration surface, but CurrentCoverage itself is role-agnostic once routing evidence exists.

Do not infer the missing domain from quantity sign. Core intentionally gives Effect sign no debit/credit/inflow/outflow semantics.

Do not infer it from account names or current routing either. Either would circularly guess the very classification whose completeness is under examination.

## Stop rules

```text
Do not graduate Observation 248 as a general CurrentCoverage closure frontier.
Do not add retained RoutingRequired / ClassificationComplete state from this counterexample alone.
Do not restrict CurrentCoverage to Expense semantics accidentally.
Do not route Asset loci by sign or spelling.
Do not mutate household data to make the counterexample disappear.
```

## Next gate

There are now two coherent directions, and LOAM should choose rather than blur them:

1. CurrentCoverage is intentionally an Expense-budget surface. Then its semantic domain must say so, and non-Expense goals such as savings belong elsewhere.
2. Purpose remains generic enough to include savings/debt/other goals. Then routing relevance needs a source independent from AccountingRole, or a proof that it can be derived from evidence already retained.

The next research question is therefore smaller and more fundamental than UI answerability:

> Is routing relevance already derivable from Capacity / routing / Actual evidence, or is one independent distinction genuinely missing?
