# Observation 235 — Household dogfood for Transactions-Flow incidence

Status: **QUALIFIED HOUSEHOLD VALUE — incidence semantics earned / dense grid rejected**

This observation was originally qualified against a private household snapshot.
The exact private revision, account identities, transaction descriptions,
amounts, and measured row totals are intentionally not retained in the public
repository.

## Publicly retained result

The private measurement established the structural point needed by this
observation:

- an Event-by-EffectCoordinate incidence matrix is mathematically valid;
- the real household window was sparse enough that a literal dense terminal grid
  spent most of its visual space on zero cells;
- some coordinates had substantial two-sided activity while ending with a small
  or zero net change;
- therefore the Event dimension can explain circulation and cancellation that a
  net-only Stock–Flow margin hides;
- the useful production direction is a sparse/focused incidence view, not a
  dense zero-heavy matrix.

No source/destination pairing, transfer classification, Purpose inference, or
new canonical authority is implied by this result.

## Privacy boundary

Real household qualification belongs in the private household repository.
Public research should retain the semantic conclusion and synthetic witnesses,
not copied household balances, descriptions, account names, or private commit
identities.

## Qualified production direction

```text
shared TransactionsFlowReview
  built over ActualReview
  with explicit half-open window
  EffectCoordinate rows
  Event columns
  exact cells
  row totals
  per-Measure Event residuals
```

The incidence semantics remain useful. The private dataset that motivated the
decision is not part of the public fixture surface.
