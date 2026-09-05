# Observation 181 — Budget Window derived projection redundancy

Status: production-facing Lean observation after Observation 180 observational closure.

## Question

Observation 180 distinguished three useful categories:

```text
independent observation
derived observation
evidence-sensitive observation
```

The current practical Budget Window report is the first real LOAM report where
that distinction can be tested directly.

It displays:

```text
Entitlement
Consumption
Remaining
```

while Application already defines:

```text
Remaining = Entitlement - Consumption
```

and explicitly retains no Remaining state.

The practical question is therefore not whether Remaining should disappear from
the report. It is:

> after the CLI has already resolved Entitlement and Consumption from one loaded
> immutable evidence snapshot, does it need to call the complete Remaining
> projection again to obtain an independently meaningful third value?

## Current production shape

`Loam.Application.CapacityWindowInspection.remainingAtEffectiveWindow?` is
literally a composition of the two component queries:

```text
entitlementAtEffectiveWindow?
consumptionAtCorrectionFrontierEffectiveRoutingWindow?
-> entitlement - consumption
```

`Loam.Cli.BudgetWindowCli.report` currently calls all three functions
independently:

```text
entitlementAtEffectiveWindow?
consumptionAtCorrectionFrontierEffectiveRoutingWindow?
remainingAtEffectiveWindow?
```

so the third call repeats both component projections after the first two have
already resolved.

## Lean qualification

`Loam.Observations.Observation181` proves directly against the production
Application functions that:

1. if Entitlement resolves to `E` and Consumption resolves to `C`, then
   production Remaining resolves to exactly `E - C`;
2. unresolved Entitlement forces unresolved Remaining;
3. after Entitlement resolves, unresolved Consumption also forces unresolved
   Remaining;
4. the existing practical fixture arithmetic remains `100 - 30 = 70`;
5. Entitlement alone does not determine Remaining;
6. Consumption alone does not determine Remaining.

The result is the practical classification:

```text
Entitlement  = independent component observation
Consumption  = independent component observation
Remaining    = derived observation
```

`Remaining` may still be useful presentation. Derived does not mean disposable.
It means the field adds no independent distinguishing power once the two
components have resolved.

## What this earns

A small follow-up production refactor is now justified:

```text
resolve Entitlement once
resolve Consumption once
compute Remaining from those resolved values
```

instead of invoking `remainingAtEffectiveWindow?` after the two component
queries have already been performed.

That refactor should preserve:

- the same immutable loaded evidence snapshot;
- the same component fail-closed frontier;
- the same visible three-field Budget Window report;
- exact integer Quantity arithmetic;
- the same half-open coordinate semantics.

## What this does not earn

This observation does **not** justify:

- hiding Remaining from the UI;
- storing Remaining as canonical state;
- removing `remainingAtEffectiveWindow?` from Application, because other callers
  may legitimately want one composed query;
- introducing generic closure machinery into production;
- globally minimizing every report;
- treating all derived display fields as waste;
- collapsing retained Capacity, Actual, routing, correction, or temporal evidence.

## Relation to Observation 180

Observation 180 established the abstract pattern with a finite additive witness:
adding an already-derived observation need not increase distinguishing power.

Observation 181 is the first practical return from that result. It does not
import a large algebraic framework into the report path. Instead it uses the
existing production definitions to identify one concrete duplicate computation.

This is the desired direction of travel:

```text
formal observation
-> practical semantic distinction
-> one small earned simplification
```

## Stop condition

Do not continue searching for abstract closure structures merely because the
mathematics is available. After this observation, prefer the concrete Budget
Window refactor. Resume broader observational-closure work only when another
real report, query, or UI decision presents an actual redundancy question.
