# Measure decimal presentation boundary — 2026-09-20

Status: **qualified implementation candidate; canonical activation deferred**

Baseline:

```text
main: d6c43aa4c80ffe2fd81569c781986d241f5eccfe
```

## Question

LOAM can retain arbitrary single-Measure exact quantities, but Core `Quantity`
is an integer number of indivisible quanta.

How should a human enter and read a conventional fixed-point amount such as:

```text
12.34 USD
27.90 ILS
```

without adding floating point, rounding, currency semantics, or a decimal
coordinate to Event / Effect?

## Decision

Keep the Core unchanged.

Add an optional Measure presentation convention:

```text
MeasureId   decimal scale

jpy         0
usd         2
ils         2
```

A scale of 2 means:

```text
12.34 displayed units
        |
        v
1234 exact quanta
```

Parsing and formatting are integer-only and exact. No floating-point value is
constructed.

## Why this is outside Core

`MeasureId` remains an opaque identity. It does not become a Currency enum or
acquire built-in ISO-4217 knowledge.

The same mechanism can describe another fixed-point household Measure if one is
ever needed.

This boundary does not establish:

- FX valuation;
- conversion rates;
- market prices;
- acquisition basis;
- tax basis;
- cross-Measure arithmetic.

## Configuration

The optional file is:

```text
config/measure-presentation.tsv
```

with rows:

```text
# measure<TAB>decimal-scale
jpy	0
usd	2
ils	2
```

Missing metadata preserves the previous scale-0 integer UI behavior.

Malformed configuration refuses Record-shaped TUI entrances that would otherwise
risk interpreting typed text under a different numeric convention.

The configured scale is a convention for an existing Measure identity, not
permission to create a Locus, assign AccountingRole, or infer that the Measure
is a currency.

## TUI behavior

With `usd -> 2`:

```text
typed      retained
-----      --------
12         1200 quanta
12.3       1230 quanta
12.34      1234 quanta
12.345     REFUSED
-0.05      -5 quanta
```

Correction and Scheduled-completion editors format retained quanta back through
the same convention before presenting editable text. They do not expose
`1234` and then accidentally parse it as `123400` on republication.

## Current activation boundary

The code may land before any nonzero scale is activated in canonical
`loam-data`.

Do **not** add `usd -> 2` or `ils -> 2` to canonical data until every
production projection that claims ordinary commodity amounts applies the same
presentation convention.

In particular, the existing PTA exporter and the in-flight Beancount/Fava
exporter currently render stored quanta directly. If a scale-2 Measure were
activated first, `1234` retained quanta could be exported as `1234 USD`
instead of `12.34 USD`.

The safe sequence is therefore:

```text
1. exact decimal parser / formatter
2. Record + Correction + Actual completion presentation
3. exporters consume the same convention
4. qualify exported decimal fixture with real target parser
5. only then add usd / ils scale rows to canonical loam-data
```

## Stop point

Qualified by this change:

- exact fixed-point parse / render without floating point;
- scale-0 backward compatibility;
- Record input under explicit Measure presentation metadata;
- Correction prefill / preview under the same metadata;
- Scheduled-completion Actual prefill / preview under the same metadata;
- refusal of excess fractional precision.

Deliberately deferred until exporter work is on main:

- canonical `usd -> 2` / `ils -> 2` activation;
- PTA decimal rendering;
- Beancount/Fava decimal rendering;
- Measure picker / friendly currency labels;
- automatic ISO currency tables;
- cross-Measure exchange.

This keeps the feature dormant and harmless until every external accounting view
can preserve the same exact quantity meaning.
