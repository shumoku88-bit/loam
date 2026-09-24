# Adding a currency to LOAM

LOAM does not contain a built-in currency database.

A currency is represented operationally by:

```text
MeasureId + optional decimal presentation scale
```

For example:

```text
usd -> scale 2
```

means that LOAM retains exact integer quanta while humans enter and read:

```text
12.34 USD <-> 1234 quanta
```

The Core remains unchanged: `MeasureId` is still an opaque quantity identity,
not a Currency enum.

## Before adding a currency

For an ordinary national currency, use ISO 4217 as the reference for:

- the three-letter alphabetic code;
- the relationship between the currency and its minor unit.

Official reference:

```text
https://www.iso.org/iso-4217-currency-codes.html
```

LOAM deliberately does **not** copy the whole ISO 4217 table into the program.
The standard remains an external reference, while the household records only
the Measures it actually uses.

This avoids turning LOAM into a currency-registry maintenance project and keeps
non-currency Measures possible.

## 1. Choose the Measure token

Prefer the lowercase ISO 4217 alphabetic code for ordinary currencies.

Examples already used by this household:

```text
jpy
usd
ils
```

The lowercase token is LOAM identity. External exporters may render a target
system's conventional uppercase form such as `USD`.

Do not create a second token for the same currency merely for display.

## 2. Determine the decimal scale

Check the currency's minor-unit relationship in the current ISO 4217 reference.

The decimal scale means how many displayed decimal places correspond to one
retained whole currency unit.

Examples of the shape:

```text
scale 0   1234 quanta -> 1234 displayed units
scale 2   1234 quanta -> 12.34 displayed units
scale 3   1234 quanta -> 1.234 displayed units
```

LOAM does not round extra digits. Input with more fractional digits than the
configured scale is refused.

## 3. Select the presentation scale

Use the production Measure-scale administration command rather than editing the
configuration file directly:

```text
loam measure-scale LOAM_DATA_DIR usd 2
```

The command re-reads the current retained quantity authorities while holding the
qualified ownership order. If the Measure is still unused, the selected scale is
published atomically to:

```text
LOAM_DATA_DIR/config/measure-presentation.tsv
```

The file remains deliberately small and inspectable:

```text
# measure<TAB>decimal-scale
jpy<TAB>0
usd<TAB>2
ils<TAB>2
```

If retained Actual, Scheduled, Capacity, or CurrentQuantityAnchor evidence
already uses the Measure, an ordinary scale change is refused. Re-selecting the
current effective scale is a harmless no-op. Missing configuration retains the
historical scale-0 convention.

This configuration does **not**:

- create a Locus;
- assign an AccountingRole;
- create a balance;
- create a transaction;
- establish an exchange rate;
- make the Measure a Core currency primitive.

It only states how exact retained quanta for that Measure are entered and
presented. A scale change for an already-used Measure is a migration question,
not a direct configuration edit.

## 4. Decide whether a new Locus is actually needed

Locus and Measure are independent.

An existing expense Locus may be reused across currencies:

```text
food × jpy
food × usd
food × ils
```

Do not create `food-usd`, `food-ils`, and similar Loci merely because the
Measure differs.

Create a new Locus only when the household needs a genuinely distinct place or
holding, for example a separate foreign-currency cash holding:

```text
usd-cash
ils-cash
```

Use the normal Locus administration boundary for that Locus and assign any
needed AccountingRole separately.

## 5. Record with the selected Measure

In the Record editor, select the Measure token and enter human decimal text.

With `usd -> 2`:

```text
Measure: usd

usd-cash  -12.34
food       12.34
```

LOAM retains exact signed integer quanta:

```text
usd-cash  -1234 quanta
food       1234 quanta
```

PTA and Beancount/Fava projections use the same Measure presentation convention.

## Important: scale becomes stable after use

Before a Measure has retained household quantities, its scale may still be
chosen.

After household data has been retained under that Measure, changing its scale
is **not** an ordinary configuration edit.

For example:

```text
usd -> 2

1234 quanta = 12.34 USD
```

Changing the configuration later to:

```text
usd -> 0
```

would reinterpret the same retained quantity as `1234 USD`.

Therefore:

```text
unused Measure
    -> choose scale

used Measure
    -> scale is stable
    -> changing scale requires an explicit migration
```

Git history is useful provenance, but it is not a substitute for a qualified
migration.

## Currency addition is not exchange

Adding both `jpy` and `usd` does not make this an ordinary Movement:

```text
cash-jpy  -15000 jpy
cash-usd    +100 usd
```

Unlike Measures do not cancel arithmetically.

A JPY-to-USD exchange needs separate exchange evidence. A transaction-specific
quantity ratio must not silently become a market rate, current valuation,
acquisition basis, or tax basis.

## Why LOAM does not embed the complete ISO table

Embedding the complete ISO 4217 registry would make some operations more
automatic. LOAM could recognize a code and obtain its standard minor-unit
relationship without household configuration.

It would also create additional responsibilities:

- keeping an external registry synchronized;
- handling added, withdrawn, and historical codes;
- deciding policy for ISO fund and precious-metal codes;
- separating currency-only rules from general `MeasureId` use;
- deciding what happens when external reference data changes.

LOAM currently needs none of those responsibilities for ordinary household use.

The selected policy is therefore:

```text
ISO 4217 = reference source
LOAM     = records only the Measures the household actually uses
```

If repeated real-world currency additions later make manual reference checking
a source of errors, an optional ISO-backed validator or helper may be earned
without changing neutral Core semantics.
