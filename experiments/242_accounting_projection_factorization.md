# Observation 242 — Accounting projection factorization

Status: **candidate bounded factorization / CI pending**

Baseline:

```text
434879788e611bd6954bfa807670e7cbaeecda6b
docs(audit): checkpoint accounting capability surface (#810)
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

The candidate is therefore sharpened to coordinate-preserving rows:

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

This means the checkpoint phrase "selected Trial Balance flow rows" is too weak. Trial Balance belongs on the as-of balance side of the factorization.

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

That asymmetry should remain visible. A report must not turn absent origin support into an implicit zero balance merely to become complete.

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

### Counterexample targets

The model asks Alloy to find witnesses for:

1. same role totals but different Trial Balance rows;
2. same RoleFlow but different Trial Balance;
3. same RoleBalance but different P&L;
4. same numeric balances but different origin/completeness support.

It also checks deliberately false compression claims:

```text
role totals determine all selected views
flow family determines Trial Balance
balance family determines P&L
numeric balance determines completeness
```

All four should have counterexamples.

### Surviving claims

The model then checks whether, in the selected bounded scope:

```text
coordinate RoleFlow + role
    -> P&L rows

coordinate RoleBalance + role + support
    -> Balance Sheet rows
     + Trial Balance rows
     + Net Worth by Measure

both coordinate families together
    -> all selected views
```

These checks should have no counterexample.

## Expected result matrix

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

## Candidate interpretation if qualified

If CI produces the expected matrix, the two-family idea survives but in a more precise form:

```text
NOT
  Role -> scalar

BUT
  coordinate-preserving flow rows
  + coordinate-preserving as-of balance rows
  + AccountingRole
  + completeness/frontier evidence
```

The report mapping then becomes:

```text
RoleFlow
  -> P&L
  -> income / expense breakdown

RoleBalance
  -> Balance Sheet
  -> Net Worth
  -> Trial Balance

role totals
  = derived summaries over those rows
```

This would argue against separate semantic engines named `ProfitLossReview`, `BalanceSheetReview`, `TrialBalanceReview`, and `NetWorthReview` unless later product pressure discovers an additional independent coordinate.

## Important non-claims

Even a successful result does not establish:

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

Do not implement a new accounting report engine from this observation alone.

If the model qualifies, the next production question becomes smaller:

> Can one shared correction-aware coordinate-flow review and one shared supported as-of coordinate-balance review reuse current production authorities without duplicating Actual, correction, or balance semantics?

Only after that boundary is established should Reports connect P&L / Balance Sheet / Trial Balance / Net Worth presentations.
