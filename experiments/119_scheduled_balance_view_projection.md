# Observation 119 — Can Scheduled be projected through the balance view?

## Household question

LOAM can now answer three separate practical questions:

```text
Actual      -> what happened?
Scheduled   -> what is expected to move?
Balances    -> what quantity is currently shown at selected loci?
```

The first real household Scheduled dogfood creates a natural next question:

> Can open Scheduled movements be interpreted against the current balance view without introducing AccountType, Asset, Income, Expense, or a new canonical `holding` classification?

The current `balance-view.tsv` is deliberately only replaceable application configuration. It selects `Locus × Measure` coordinates for a current balance question; it does not create canonical facts, accounting roles, or allocation authority.

Observation 048 already established a separate boundary:

```text
what is held
  !=
what may participate in allocation
```

So this observation must not silently turn the balance view into Backing or Eligibility.

## Why Alloy

This is a static relational sufficiency question.

Hold the Scheduled movements fixed and vary only:

- which Loci the balance view selects;
- which selected Loci are additionally eligible for allocation-sensitive reasoning.

Then ask which answers change.

No transition order is involved yet, so Alloy is a better fit than TLA+ or SPIN.

## Synthetic specimen

The model has four neutral Loci and three balanced Scheduled movements:

```text
Payment:   Bank    -3  -> Rent   +3
Funding:   Pension -7  -> Bank   +7
Transfer:  Bank    -2  -> Wallet +2
```

There is intentionally no Account, Asset, Income, Expense, debit, credit, or transaction-kind relation.

For one balance view selecting `Bank + Wallet`:

```text
Payment   has negative selected impact
Funding   has positive selected impact
Transfer  has zero total selected impact
```

The internal transfer still changes both selected Loci individually. A zero selected net therefore must not erase the retained per-Locus Scheduled changes.

## Questions

1. Can the same Scheduled movement read as negative or positive under different balance-view selections?
2. Does Scheduled alone determine selected balance impact?
3. Does Scheduled plus the same balance view determine selected balance impact?
4. If the balance view and Scheduled facts are fixed, can a separate Eligibility selection still change allocation-sensitive impact?
5. Does adding the same Eligibility selection remove that ambiguity?

## Expected Alloy results

```text
balanceViewReadsRelativeDirectionWithoutAccountTypes                 SAT
sameScheduledCanReadDifferentlyThroughDifferentViews                 SAT
sameViewCanStillDifferInEligibilitySensitiveImpact                   SAT
ScheduledAloneDeterminesSelectedOpenImpact                           SAT
ScheduledPlusBalanceViewDeterminesSelectedOpenImpact                 UNSAT
BalanceViewPlusScheduledDeterminesEligibilitySensitiveImpact         SAT
BalanceViewPlusScheduledPlusEligibilityDeterminesEligibilitySensitiveImpact UNSAT
```

For `check` commands, SAT means Alloy found a counterexample to the asserted sufficiency law.

## Candidate interpretation

If the expected result set holds, the smallest current decomposition is:

```text
open Scheduled
+ replaceable BalanceView selection
    -> Scheduled impact on the balances currently being asked about

open Scheduled
+ BalanceView
+ separate Eligibility / Backing evidence
    -> allocation-sensitive question
```

That would mean LOAM does **not** yet need a new canonical `holding Locus` concept merely to distinguish household Scheduled funding from payment relative to the current balance view.

The direction is query-relative:

```text
same movement
+ different selected balance coordinates
= different balance-view interpretation
```

This is different from saying the movement intrinsically *is* Income or Expense.

## Boundary

This observation does not establish:

- safe-to-spend quantity;
- Backing topology;
- liquidity or access policy;
- whether Eligibility should be canonical, historical, or replaceable;
- a forecast that Scheduled quantity will equal later Actual quantity;
- recurrence;
- partial completion;
- priority or oversubscription policy;
- a current-date or horizon policy;
- that balance-view selection is allocation authority;
- that AccountingRole is unnecessary for accounting statements.

It asks only whether the existing application balance selection is enough to interpret open Scheduled effects *relative to the balances currently being viewed*.
