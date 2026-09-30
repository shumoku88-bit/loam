# Let's Kakeibo v5.93 — scheduled, cards, movement, and reconciliation

Date: 2026-10-01  
Status: **primary-help reconstruction from the bundled v5.93 CHM**

## 1. Future view as a combined household horizon

The final help documents one future-list surface that combines:

1. unsettled credit-card payments;
2. future automatic entries;
3. manually entered future-dated ledger rows.

These sources are visually distinguished but shown together.

The view can filter credit, automatic entries, or all future items. It can also show totals by account through a selected horizon and card-withdrawal totals.

This is a strong interaction idea: future pressure is a **single household question** even when its sources have different semantics.

## 2. Automatic-entry rules

The automatic-entry configuration supports a broad recurrence model:

- monthly;
- every N months;
- every N weeks;
- fixed date;
- nth weekday;
- applicability start/end dates;
- fixed or omitted/variable amount;
- category;
- tag;
- account/card;
- holiday shift before/after;
- optional credit settlement postponed by one month.

Invalid month dates such as February 30 are clamped to month-end.

The UI can preview future generated dates.

Variable recurring bills can be registered without a known amount and filled later either in the ordinary ledger or future list.

## 3. Editing recurring rules reaches history only by explicit choice

The help says changing an automatic-entry rule can optionally be applied retrospectively.

That retrospective operation is consequential: corresponding historical generated rows are deleted/reconstructed. Deleting a recurring rule can likewise optionally remove historical generated rows.

This is a useful warning for LOAM:

```text
edit rule != silently rewrite evidence
```

Any equivalent LOAM operation should make the historical consequence explicit and preserve LOAM's correction/evidence model.

## 4. Holiday calendar

Holiday settings are household-book-local.

Holiday knowledge can shift automatic entries and card withdrawals to a preceding/following weekday.

The help documents:

- ordinary fixed holidays;
- nth-weekday / "Happy Monday" style rules;
- applicability year ranges;
- automatic handling for equinox/historical Japanese holiday rules;
- per-household calendars, which the help suggests can also support households associated with different countries.

This is an early example of calendar policy as user data rather than hard-coded scheduling behavior.

## 5. Credit cards

Card configuration includes:

- withdrawal account;
- closing date;
- withdrawal date;
- credit limit;
- holiday shifting;
- installment APR;
- revolving-payment mode;
- fixed or balance-slide revolving plans;
- principal/interest variants;
- applicability periods;
- enable/disable state.

A card that has already been used cannot simply be deleted; it can be disabled.

Changing card configuration does not retroactively rewrite already-generated settlement rows.

## 6. Purchase-to-settlement traceability

The final help documents a tight link between a card purchase and its future settlement.

The user can:

- choose lump-sum/installment/revolving treatment;
- alter the payment method;
- see calculated installment fee/principal details;
- jump from purchase to withdrawal row;
- inspect purchase details from a withdrawal aggregate;
- postpone a selected card purchase by one month;
- restore the original withdrawal timing.

The product history says this bidirectional linkage was introduced as a major Ver.3 feature.

The reusable LOAM principle is:

```text
originating household event
        <- traceable relation ->
future settlement consequence
```

## 7. Transfer assistant

The transfer assistant makes a common movement easy to enter, but its semantics are weaker than LOAM's.

One assistant action writes two ledger rows, for example:

```text
bank expense
cash income
```

Both are placed in a special category excluded from income/expense reports.

Previously used transfer patterns can be reused.

This is an important distinction:

- **good UI idea:** one interaction for one real-world movement;
- **do not copy the storage model:** LOAM already has a first-class Movement model and should not degrade it into compensating income/expense rows.

## 8. Balance adjustment

The balance-adjustment tool asks for:

- date;
- account;
- ledger balance;
- actual observed balance.

For cash, the user may count denominations.

The difference is written as an adjustment, with a suggested use such as unknown spending.

The help explicitly says this should not be put in the transfer/excluded category because doing so would hide real unexplained spending from expense totals.

The surrounding philosophy is pragmatic: a mismatch should not stop continued bookkeeping, and later knowledge can correct it.

LOAM should preserve that human goal while representing uncertainty and correction with its own evidence semantics.

## 9. Multiple currencies

The final help documents multi-currency accounts:

- each account has a currency;
- selecting the account sets the transaction currency;
- non-default currency is displayed explicitly;
- reports can be viewed per currency.

The help does not describe automatic exchange-rate conversion into one universal total. This is a useful contrast with LOAM's explicit Measure/exchange work.

## 10. Candidate LOAM Desk pressure

A desk-style interface could present:

```text
Actual table
     |
     +--> linked Scheduled item
     +--> settlement relation
     +--> future pressure
     +--> balance effect
     +--> correction/reconciliation
```

without copying Let's家計簿's older storage semantics.

The key lesson is to make lifecycle relations navigable from the ordinary ledger instead of forcing the user to mentally join several unrelated screens.
