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

## Observed Alloy results

Alloy 6.2.0 + Sat4j produced the complete expected result set:

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

The first CI attempt stopped before solving because the field name `open` collided with an Alloy 6 reserved word. Renaming the field to `activeScheduled` changed only model syntax, not the question or expected result set. The corrected exact-head run passed the solver and result qualification.

## Interpretation

The same Scheduled movement can have opposite selected impact under two different balance views. In the synthetic payment:

```text
Bank selected  -> negative impact
Rent selected  -> positive impact
```

So incoming / outgoing direction is relative to the selected balance question. It need not be stored as an intrinsic Income / Expense or transaction-kind fact.

Scheduled facts alone do not determine the selected balance impact. Alloy finds a counterexample when two worlds retain the same active Scheduled set but select different balance Loci.

Once the active Scheduled set and the balance-view selection are both fixed, Alloy finds no bounded counterexample to the selected-impact answer. The smallest current decomposition is therefore:

```text
open Scheduled
+ replaceable BalanceView selection
    -> Scheduled impact on the balances currently being asked about
```

The transfer specimen adds an important projection boundary:

```text
Bank -2 -> Wallet +2
```

has zero total impact when both Bank and Wallet are selected, but both selected Loci still change. A future practical projection must therefore retain per-Locus effects rather than replacing them with one net number.

Finally, the same Scheduled facts and the same BalanceView still do not determine an allocation-sensitive answer. Varying only Eligibility changes that answer. When Eligibility is also fixed, the ambiguity disappears in the bounded model:

```text
open Scheduled
+ BalanceView
+ separate Eligibility / Backing evidence
    -> allocation-sensitive question
```

This preserves Observation 048 rather than weakening it. BalanceView says which balances are currently being asked about; it does not say which held quantity may fund household allocation.

## Consequence for vocabulary

This observation gives no reason to add a new canonical `holding Locus` classification merely to distinguish household Scheduled funding from payment relative to the current balance view.

The existing replaceable BalanceView already carries the additional query-relative selection needed for that narrower answer.

That does **not** mean a holding, eligibility, liquidity, or backing distinction can never be needed. It means this particular household question does not earn a new canonical concept yet.

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

It establishes only that the existing application balance selection is sufficient, in this bounded vocabulary, to interpret open Scheduled effects *relative to the balances currently being viewed*.
