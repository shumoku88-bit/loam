# Operational multi-currency boundary — 2026-09-20

Status: **implementation qualification candidate**

Baseline:

```text
main: 9b6436583d1425dfde9d3cf93817833de1bb72c9
```

## Question

Can LOAM now use ordinary foreign-currency quantities in day-to-day household
recording without turning Measure into Currency, weakening exact Quantity, or
smuggling exchange / valuation semantics into ordinary Movement?

## Result

The intended operational shape is:

```text
Locus              Measure          human text       retained Quantity
-----              -------          ----------       -----------------
wallet             jpy              1000             1000 quanta
wallet             usd              12.34            1234 quanta
wallet             ils              27.90            2790 quanta

food               jpy              500              500 quanta
food               usd              4.50             450 quanta
food               ils              18.00            1800 quanta
```

Locus and Measure stay orthogonal. A household does not need `food-usd` and
`food-ils` merely because one expense Locus is used under several Measures.

## Qualified layers

### Core

No change.

`Quantity` remains exact integral quanta and `MeasureId` remains an opaque
stable identity. There is no Currency enum and no floating-point monetary value.

### Input / correction presentation

`MeasurePresentation` supplies an optional fixed-point scale.

For scale 2:

```text
12       -> 1200 quanta
12.3     -> 1230 quanta
12.34    -> 1234 quanta
12.345   -> REFUSED
```

No rounding is performed.

Correction must preserve the target Measure. Changing a USD Event into ILS is
not a correction; it belongs to separately qualified exchange semantics.

### PTA export

Plain Text Accounting export formats exact retained quanta through the same
Measure presentation convention.

A retained `1234 quanta` under `usd -> 2` is exported as:

```text
12.34 usd
```

not `1234 usd`.

### Beancount / Fava export

Beancount export uses the same exact formatter.

One LOAM Locus may map to one Beancount account holding several commodities.
For example:

```text
2026-09-01 open Expenses:Loam-food ILS,JPY,USD
```

This avoids multiplying source Loci merely to satisfy a target viewer.

Distinct LOAM Loci that normalize to the same Beancount account name still
fail closed.

## Canonical activation

After the implementation and external Beancount/Fava fixture pass, canonical
household presentation may activate:

```text
jpy  0
usd  2
ils  2
```

in:

```text
config/measure-presentation.tsv
```

This file does not admit a Measure or a Locus. It only defines exact human
fixed-point representation for an already-used Measure identity.

## Still deliberately separate

Operational multi-currency does not imply cross-Measure exchange.

This remains invalid as one ordinary Movement:

```text
cash-jpy  -15000 jpy
cash-usd    +100 usd
```

because unlike Measures do not arithmetically cancel.

Observation 282 records the current candidate direction:

```text
cross-Measure Event
+ explicit ExchangeEvidence(EventId)
```

without making an observed quantity ratio into a market rate, current
valuation, acquisition basis, or tax basis.

## Stop point

Once the real Beancount parser and Fava accept the scaled JPY/USD/ILS fixture,
ordinary multi-currency quantity handling is complete enough for household use.

Reopen only for a concrete need such as:

- an actual currency with another decimal scale;
- a display label / symbol requirement;
- an actual exchange transaction;
- independent valuation evidence.

Do not add a global ISO currency database or automatic FX feed merely to claim
feature completeness.
