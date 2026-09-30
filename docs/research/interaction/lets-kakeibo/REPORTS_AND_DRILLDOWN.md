# Let's Kakeibo — reports, graphs, and drill-down

## 1. Reports are not a separate dead end

Later hands-on analysis documents a valuable navigation property: summary values can lead back to the detail that produced them.

Examples include:

- a monthly-comparison graph region -> detail list;
- a report table cell -> underlying transactions;
- a card settlement aggregate -> constituent purchases.

This is more important than the particular graph library or visual style.

## 2. Graph families

Historical review material mentions:

- pie;
- bar;
- area;
- line.

Later material demonstrates:

- annual/fiscal-year monthly comparison;
- account balance trend.

Version 5 refreshed graph presentation, though the 2024 reviewer notes that old graph rendering does not adapt well to modern high-resolution displays.

## 3. Fiscal-year control

The report period does not assume January as the only year boundary. The later review demonstrates that the start month can be changed, e.g. January-December or April-March.

This is a useful example of letting household reporting periods differ from calendar-year defaults.

## 4. Report table

The report surface can be switched from graphs to a tabular view.

Observed capabilities include:

- monthly category actuals;
- budget values;
- budget ratios;
- budget-consumption visual cues;
- switching the report target from category to account/asset;
- account month-end balance history;
- detail access from a selected numeric cell.

### Reconstructed information path

```text
report cell / graph segment
          |
          v
   aggregate amount
          |
          v
   source-detail list
          |
          v
   household ledger rows
```

## 5. Why this is relevant to LOAM

LOAM already has stronger evidence/provenance concepts than Let's家計簿.

The reusable UI principle is therefore:

```text
observation -> contributing evidence
```

not:

```text
copy this exact graph
```

Possible LOAM research questions include:

- Can Trend jump directly to the contributing Actual movements?
- Can Stock-Flow observations expose their source interval/evidence?
- Can Scheduled pressure show the scheduled items that produce a total?
- Can a balance point reveal the movements that changed it?
- Can every aggregate clearly state its period and selection rule?

## 6. Presentation lessons

Useful:

- expose the number and its source;
- permit category/account switching without leaving the report concept;
- keep time-period configuration explicit;
- support tabular analysis alongside graphs.

Less useful to copy:

- decorative gradients;
- fixed-resolution graph assumptions;
- graph type proliferation merely because several chart types exist.

## 7. Terminal implications

A terminal cannot reproduce every graph affordance, but it can reproduce the evidence path.

For example:

```text
Food        18,420
Coffee       3,240
Transport    5,600
              ^
              Enter
              |
              v
contributing Actual rows
```

That interaction may be more important for LOAM Desk than drawing smooth curves.
