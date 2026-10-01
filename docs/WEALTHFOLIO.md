# Wealthfolio export

Status: **experimental disposable cash projection**

LOAM can emit a Wealthfolio-native CSV for transaction-tracked Cash accounts:

```text
loam export wealthfolio DATA_ROOT ACCOUNTING_EPOCH OUTPUT_FILE
```

Example:

```text
loam export wealthfolio ../loam-data 2026-09-01 /tmp/loam-wealthfolio.csv
```

LOAM remains authoritative. The CSV may be deleted and regenerated at any time.

## Scope

The first exporter intentionally handles only LOAM coordinates with explicit
`AccountingRole.asset`.

It emits:

- positive derived Opening Position -> `DEPOSIT`;
- negative derived Opening Position -> `WITHDRAWAL`;
- one-Asset Event increase -> `DEPOSIT`;
- one-Asset Event decrease -> `WITHDRAWAL`;
- multi-Asset Event increases -> `TRANSFER_IN`;
- multi-Asset Event decreases -> `TRANSFER_OUT`.

It does not infer `BUY`, `SELL`, `DIVIDEND`, `INTEREST`, `FEE`, `TAX`,
`CREDIT`, securities, or credit-card semantics.

This is deliberate. Wealthfolio concepts do not become LOAM domain facts merely
because the target supports them.

## Opening balance

The CSV does not create an opening transaction inside LOAM.

Instead:

```text
CurrentQuantityAnchor
        +
BoundedHistorySupport / ZeroOriginCoverage
        +
dated correction-aware Actual
        |
        v
OpeningPositionReview(Accounting Epoch)
        |
        v
Wealthfolio DEPOSIT / WITHDRAWAL target rows
```

If LOAM cannot justify an exact Asset quantity at the requested Accounting
Epoch, export fails closed.

## CSV shape

The generated file uses:

```text
date,activityType,currency,amount,account,comment
```

Amounts are always positive because Wealthfolio derives cash direction from the
activity type.

`account` is the LOAM Locus token. Create matching Wealthfolio Cash accounts
or map the column during import.

`comment` retains the human description when present plus:

- `loam_event_id`;
- `loam_locus`;
- `loam_measure`;
- or `loam_epoch` for opening rows.

Only conservative three-letter alphabetic Measure tokens are exported as
currencies, upper-cased for Wealthfolio. Current household examples such as
`jpy`, `usd`, `eur`, and `ils` satisfy this boundary.

## Target assumptions

This adapter targets Wealthfolio's CSV importer documented on 2026-09-30 /
2026-10-01, where cash-only rows use activity type + amount, optional currency,
account and comment fields, and cash setup may be seeded with a deposit.

Because Wealthfolio evolves independently, preview the CSV in its import wizard
before committing an import. LOAM source evidence is never modified by that
preview or import.
