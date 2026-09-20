# Multi-Measure Recording Boundary — 2026-09-20

Status: **qualified entrance generalization; exchange semantics intentionally deferred**

Baseline: `17d6cfc773cbd084e9ccfaa6be61d50dcbf10938`

## Question

Can LOAM stop treating JPY as the only practical recording Measure without
turning ordinary recording into an implicit FX / valuation engine?

A second pressure follows immediately:

> If cash is exchanged at an airport, for example 15,000 JPY for 100 USD, can
> LOAM record the fact without corrupting quantity or accounting semantics?

## Existing basis

The neutral physical Core is already:

```text
Event
  -> Effect
       -> Locus
       -> Measure
       -> exact Quantity
```

`MeasureId` carries no built-in currency, commodity, valuation, or dimensional
meaning. Runtime addition is admitted only when Measure identity agrees.

Normalized Actual persistence is already stronger than the former JPY entrance:
for an ordinary retained Event it checks balance independently for every
represented Measure.

Therefore this change does not add a Currency primitive, change Event / Effect,
or change the wire representation.

## Production change

The ordinary Movement entrance now accepts any **one explicit Measure**.

JPY remains the default for existing household use. CLI callers may select
another Measure, and the TUI Record editor exposes the Measure as an editable
field.

The admission law is:

```text
one valid Measure
+ nonzero Effects
+ all Effects use that Measure
+ signed total = 0
+ positive side total matches the draft total
    -> practical Movement
```

Correction uses the same single-Measure recognition and the editor pre-fills the
selected Actual's Measure instead of rejecting non-JPY evidence.

This qualifies ordinary examples such as:

```text
usd-wallet  -25 usd
food        +25 usd
```

without assigning any exchange-rate meaning to `usd`.

## Cross-Measure exchange is deliberately different

The direct airport-exchange shape:

```text
cash-jpy    -15000 jpy
cash-usd      +100 usd
```

is **not** an ordinary balanced Movement.

Its JPY projection totals -15000 and its USD projection totals +100. Treating
those unlike quantities as if they cancelled would violate the existing
Measure-separation law.

The ordinary Movement entrance therefore continues to refuse this shape.

## Why not use a clearing-locus workaround?

It is mechanically possible to manufacture per-Measure balance by adding a
synthetic locus:

```text
cash-jpy        -15000 jpy
fx-clearing     +15000 jpy

fx-clearing       -100 usd
cash-usd           +100 usd
```

That makes each Measure total zero, but it leaves quantities at a synthetic
locus. Unless that locus has separately qualified ownership / counterparty /
projection semantics, household balance and accounting views can mistake those
residual quantities for retained household positions.

LOAM should not use that representation merely to satisfy the current balance
checker.

## What a future exchange boundary must preserve

A practical exchange entrance should be added only when real household use
requires it. At minimum it must keep these questions separate:

```text
what JPY quantity left?
what USD quantity arrived?
which Event / operation says they belong to one exchange?
what occurrence / settlement coordinate applies?
what comparison or rate evidence, if any, is being claimed?
is that rate observed, derived from the exchanged quantities, or supplied by
another authority?
does a fee exist as an independently observable quantity?
```

The exchange relation must not silently become market valuation, acquisition
basis, tax basis, or a timeless FX rate.

Observation 032 already established Measure as an independent quantity
coordinate. Observation 033 established that Measure-to-Measure valuation can
vary while the event core remains fixed. Observation 066 further established
that historical valuation does not determine acquisition basis.

Those results still apply.

## Decimal currencies

Core Quantity is exact integral quanta. This change does not introduce display
scale metadata.

A Measure may therefore identify whatever exact quantum the household chooses
to retain, but a friendly representation such as `100.25 USD` still needs an
explicit presentation / scale convention before the UI should pretend that
decimal currency formatting is canonical.

That is presentation metadata, not evidence that Event / Effect needs a new
physical coordinate.

## Stop point

Qualified now:

- arbitrary single-Measure Actual recording;
- JPY remains the zero-configuration default;
- non-JPY single-Measure correction;
- existing Measure identity survives persistence and review;
- cross-Measure exchange-like drafts remain refused by ordinary Movement
  admission.

Not qualified now:

- JPY -> USD exchange publication;
- market FX-rate authority;
- automatic base-currency valuation;
- realised / unrealised FX gain;
- decimal currency display policy;
- acquisition-basis or tax semantics.

The next exchange change should start from an actual household exchange need,
not from a desire to make unlike quantities balance.
