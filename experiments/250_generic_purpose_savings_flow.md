# Observation 250 — Generic Purpose already models current-window savings contribution

Status: **ACTIVE WITNESS — production semantics unchanged**

Baseline:

```text
Observation 249 head
4bda7607107954e14340df52ed3a3e0cf8031cba
```

## Question

The real household counterexample behind Observation 249 raised a tempting design response:

> Should LOAM introduce a separate savings / accumulation Purpose kind?

Before adding a new semantic distinction, test whether the existing generic Purpose already answers the concrete current-cycle savings question.

## Witness

One ordinary Purpose receives 5,000 JPY of Capacity.

The retained savings Asset has an explicit Actual route to that Purpose.

Three worlds are compared:

```text
OLD POSITION ONLY
  pre-window savings Asset +10000

CURRENT DEPOSIT
  pre-window savings Asset +10000
  current-window savings Asset +5000

CURRENT WITHDRAWAL
  pre-window savings Asset +10000
  current-window savings Asset +5000
  current-window savings Asset -2000
```

All savings coordinates are AccountingRole.asset. No special Purpose kind is introduced.

Expected CurrentCoverage:

```text
                     Consumption   Remaining
old position only          0          5000
current deposit         5000             0
withdraw 2000           3000          2000
```

## Interpretation

The existing signed routed-Actual semantics already expresses:

```text
current-cycle savings contribution
= signed net flow routed to the savings Purpose inside the current window
```

A deposit fulfills allocated Capacity. A withdrawal re-opens part of that allocation. A pre-window Asset position does not satisfy a current-cycle contribution allocation.

Therefore a dedicated `SavingsPurpose` / `StockPurpose` distinction is not earned merely to support:

```text
"put 5,000 JPY into savings this cycle"
```

The remaining distinct question is a true stock-position goal such as:

```text
"have 50,000 JPY in savings"
```

That question depends on current balance / position evidence and must not be conflated with current-window contribution flow.

## Architectural consequence

Savings and investment **boxes may be ordinary Purpose identities** if their household meaning is a current-window contribution allocation. The missing practical seam is routing administration for non-Expense Loci, not necessarily a new Core Purpose taxonomy.

AccountingRole remains orthogonal:

```text
AccountingRole.asset
×
Purpose = savings contribution
```

is coherent.

## Stop rules

- Do not add `FlowPurpose`, `StockPurpose`, `SavingsPurpose`, or `PurposeKind` from this witness alone.
- Do not infer a stock target from a Capacity allocation.
- Do not treat an Asset balance as current-cycle contribution.
- Do not restrict generic Actual routing to Expense solely because the current administration surface does.
- Do not rename production `Consumption` until broader report/UI semantics justify that surface change.

## Next gate

If this witness qualifies, inspect the smallest practical way to let the routing administration surface expose a deliberately selected non-Expense Locus for an existing Purpose without turning every Asset into a required budget route.
