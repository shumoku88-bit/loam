# LOAM Opening Position

Status: **derived read projection**

LOAM exposes a conventional accounting opening balance as a derived **Opening
Position** at an explicit **Accounting Epoch**.

It is intentionally not a new authority file and not a generated opening
transaction.

## Meaning

For a selected `Locus × Measure` coordinate and calendar day:

> Opening Position = the exact quantity justified at the start of the Accounting
> Epoch day.

The value is delegated to `HistoricalBalanceReview`.

That means the answer is available only through evidence LOAM already trusts:

- exact zero-origin forward reconstruction; or
- explicit `BoundedHistorySupport` plus an exact `CurrentQuantityAnchor`,
  reconstructed backward through admitted dated Actual evidence.

If neither route can justify the requested boundary, LOAM refuses the answer.

## Why this is not `OpeningSupport`

`OpeningSupport` is an older, deliberately narrow current-balance witness. It
states that one current Actual Event supplies support for one coordinate.

It does **not** claim that all changes after a date are known, and therefore it
does not authorize historical reconstruction or an Accounting Epoch.

The new Opening Position read boundary preserves that distinction.

## Why LOAM does not store an opening-balance amount

Storing another opening quantity would create a second quantity authority beside
Actual and current reconciliation evidence.

Instead:

```text
CurrentQuantityAnchor
        +
BoundedHistorySupport(start day)
        +
dated correction-aware Actual
        |
        v
HistoricalBalanceReview
        |
        v
OpeningPositionReview(Accounting Epoch)
```

The opening amount is therefore reproducible from existing evidence and cannot
silently drift away from the current world.

## External viewers

A disposable exporter may translate the derived Opening Position into the
target application's conventional opening-balance rows, then emit Actual
activity from the Accounting Epoch onward.

For example, a future Wealthfolio projection can use:

```text
OpeningPositionReview(epoch)
        +
ActualJournalProjection(activity on/after epoch)
        |
        v
disposable Wealthfolio CSV
```

Those generated opening rows belong to the external projection. They do not
become canonical LOAM Events.
