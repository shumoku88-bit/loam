# Observation 242 — Accounting projection factorization

Status: **QUALIFIED — coordinate-preserving RoleFlow / RoleBalance factorization survives bounded falsification**

Baseline:

```text
434879788e611bd6954bfa807670e7cbaeecda6b
docs(audit): checkpoint accounting capability surface (#810)
```

Qualified model head before this documentation update:

```text
3262cbc724248bf06f2554c33df47a10c564f3c5
```

Qualified CI:

```text
workflow: Observation 242
run:      34739206588
job:      103675899131
result:   SUCCESS
Alloy:    6.2.0 / Sat4j
```

## Trigger

The accounting capability checkpoint classified several familiar reports as projection gaps rather than new-ontology gaps and proposed two shared families:

```text
RoleFlow
RoleBalance
```

Before production work, this observation tries to falsify that compression.

The question is not whether LOAM can print familiar report names. It is:

> What is the smallest shared answer from which P&L-, Balance-Sheet-, Trial-Balance-, and Net-Worth-shaped views can still be recovered without erasing independently observable information?

## Prior evidence kept fixed

This observation does not repeat earlier AccountingRole work.

- Observation 049 established that physical placement does not determine Asset / Liability / Equity / Income / Expense meaning.
- Observations 216 and 217 established that partial role-aware reports must preserve unresolved evidence separately from numeric role totals; an unresolved net quantity of zero does not imply completeness.
- Observation 219 qualified explicit zero-origin coverage for the selected household balance use.
- The production accounting capability audit records recognition, valuation, finality, tax, and rich investment policy as separate pressure outside the selected scope.

Observation 242 deliberately uses fully classified Loci to isolate a different loss channel: **aggregation and stock/flow collapse**.

## Candidate family shape under pressure

A first reading of the checkpoint could be compressed too aggressively to:

```text
role -> quantity
```

for flow and balance answers.

That loses account / coordinate identity. Trial Balance and detailed accounting views need to distinguish two Loci even when their quantities cancel or sum to the same role total.

The surviving candidate is therefore coordinate-preserving:

```text
RoleFlow
  EffectCoordinate (Locus x Measure)
  + AccountingRole
  + selected-window quantity change
  + unresolved Effect frontier   -- inherited from Obs. 216/217

RoleBalance
  EffectCoordinate (Locus x Measure)
  + AccountingRole
  + as-of quantity
  + independent origin/completeness support
  + unresolved / unsupported frontier
```

Role totals are derived conveniences, not the shared semantic basis.

## Why Trial Balance is the strongest pressure

A conventional Trial Balance is account-granular and as-of.

Two worlds can have the same Asset total while distributing it differently:

```text
World A
  cash  2
  bank  8

World B
  cash  5
  bank  5

Asset total = 10 in both worlds
```

A role-total projection cannot distinguish those worlds, but the Trial Balance rows differ.

Likewise, the same selected-period flow does not determine an as-of balance: pre-window history can differ while current-window movement is identical.

The checkpoint phrase `selected Trial Balance flow rows` is therefore too weak. Trial Balance belongs on the as-of balance side of the factorization.

## Household-data pressure

Current household AccountingRole evidence classifies many Asset, Liability, Equity, Income, and Expense Loci.

Current zero-origin coverage, however, covers only five JPY holding coordinates:

```text
cash
paypay
smbc
yucho
all-country
```

Therefore current evidence can support a broad occurrence-time RoleFlow projection more readily than a complete all-account RoleBalance / Trial Balance projection.

That asymmetry must remain visible. A report must not turn absent origin support into an implicit zero balance merely to become complete.

## Alloy model

`242_accounting_projection_factorization.als` uses two worlds with:

```text
Locus x Measure coordinates
AccountingRole per Locus
selected-window flow per coordinate
as-of balance per coordinate
independent balanceSupported set
```

The model intentionally excludes partial AccountingRole classification because Observations 216/217 already qualified that frontier. It also excludes recognition, valuation, hierarchy, closing/finality, and sign-presentation policy.

## Executed result

Alloy produced exactly the required matrix:

```text
sameRoleTotalsDifferentTrialBalance                     SAT
sameFlowDifferentTrialBalance                           SAT
sameBalanceDifferentProfitAndLoss                       SAT
sameNumericBalanceDifferentSupport                      SAT

RoleTotalsDetermineSelectedViews                        SAT counterexample
FlowFamilyDeterminesTrialBalance                        SAT counterexample
BalanceFamilyDeterminesProfitAndLoss                    SAT counterexample
NumericBalanceDeterminesCompleteness                    SAT counterexample

CoordinateFlowDeterminesProfitAndLoss                   UNSAT counterexample
CoordinateBalancePlusSupportDeterminesBalanceViews      UNSAT counterexample
CoordinateFamiliesDetermineSelectedViews                UNSAT counterexample
```

The expected-result checker passed in CI.

## Findings

### 1. Role totals are too compressed

Alloy found worlds with identical per-role totals but different Trial Balance rows.

Therefore:

```text
role -> quantity
```

is not a sufficient shared report basis once account / Locus-granular views are in scope.

The shared row must preserve at least the exact `Locus x Measure` coordinate together with its AccountingRole.

### 2. Flow and as-of balance are independently observable

The model found both directions of separation:

```text
same selected-period flow
    != same Trial Balance

same as-of balances
    != same selected-period P&L
```

So one universal `RoleQuantity` scalar family would erase a real distinction. The two-family split is earned in this bounded scope.

### 3. Numeric balance is not completeness

The model found worlds with the same numeric balances but different `balanceSupported` evidence.

Therefore:

```text
same balance value
    != same justified balance answer
```

Origin/completeness support cannot be inferred from the number and must remain an independent frontier.

This is the stock-side analogue of Observation 217's result that an unresolved net quantity of zero does not imply complete classification.

### 4. Coordinate RoleFlow is sufficient for the selected P&L-shaped view

With AccountingRole and the exact coordinate flow vector fixed, Alloy found no world with a different selected P&L row answer.

No independent `ProfitLoss` semantic engine is earned by this bounded vocabulary.

### 5. Coordinate RoleBalance plus support is sufficient for selected balance views

With AccountingRole, exact coordinate balances, and support fixed, Alloy found no world with different:

```text
Balance Sheet rows/frontier
Trial Balance rows/frontier
Net Worth by Measure/frontier
```

No independent `BalanceSheet`, `TrialBalance`, or `NetWorth` semantic engine is earned by this bounded vocabulary.

### 6. The two coordinate families together determine all selected views

With both families fixed, the combined selected report answer could not vary in the bounded model.

The surviving factorization is therefore:

```text
coordinate RoleFlow
+
coordinate RoleBalance with support
+
AccountingRole
+
existing unresolved frontiers
    -> selected conventional accounting views
```

## Qualified report mapping

```text
RoleFlow
  -> P&L
  -> income / expense breakdown

RoleBalance
  -> Balance Sheet
  -> Net Worth
  -> Trial Balance

role totals
  = derived summaries over coordinate rows
```

This argues against separate semantic engines named `ProfitLossReview`, `BalanceSheetReview`, `TrialBalanceReview`, and `NetWorthReview` unless later product pressure discovers an additional independent coordinate.

## Important non-claims

This result does not establish:

- accrual / deferred recognition;
- period closing or retained-earnings policy;
- adjustment/finality workflow;
- debit/credit presentation as canonical state;
- hierarchy or inherited accounting roles;
- cross-Measure valuation;
- FX gain/loss;
- formal cash-flow classification;
- tax accounting;
- rich investment accounting;
- production completeness for current household Trial Balance.

Those remain separate pressure and must not be hidden inside these two projection families.

## Production gate

Do not add four report engines from this observation.

The next production question is smaller:

> Can one shared correction-aware coordinate-flow review and one shared supported as-of coordinate-balance review reuse current production authorities without duplicating Actual, correction, or balance semantics?

In particular, investigate whether the production boundary can compose existing `ActualReview` / correction-aware window mechanics and existing zero-origin quantity mechanics rather than introducing a second accounting reader.

Only after that boundary is established should Reports connect P&L / Balance Sheet / Trial Balance / Net Worth presentations.

## Verdict

```text
Role-total compression sufficient                         NO
one universal stock/flow quantity family sufficient       NO
numeric balance alone proves completeness                  NO
coordinate RoleFlow sufficient for selected P&L           YES (bounded)
coordinate RoleBalance + support sufficient for BS/TB/NW  YES (bounded)
separate named report semantic engines earned              NO EVIDENCE
next pressure                                               production reuse boundary
```
