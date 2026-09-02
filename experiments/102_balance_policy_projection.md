# Observation 102: Can one balance query policy stay smaller than Account machinery?

## Question

Observation 085 established that basis applicability is query-relative. Observation 086 then established that retained basis/Event presence does not determine which coordinates an anchored-current query should select.

Observation 101 supplied the positive side: an experiment-local `BalanceScope` can select neutral LOAM loci for one balance projection without changing `Event`, `Effect`, or `LocusId` and without introducing Account machinery.

The current practical `balances` command still uses the admitted `QuantityBasis` frontier itself as its row-selection surface. That is convenient, but it collapses two meanings that earlier observations kept separate:

```text
basis evidence
    !=
query selection
```

Real dogfood exposed the pressure directly: a use-shaped coordinate may carry an explicit zero basis only because an older anchored-current path required that premise. Basis presence alone should not silently make that coordinate a balance row.

Observation 102 asks the next smallest practical question:

> Can a tiny application-local balance query policy feed the existing production `CurrentQuantity` projection directly, while keeping basis evidence and accounting classification separate?

## Probe shape

The Lean probe imports production `Loam.Application.CurrentQuantity` and keeps one retained fact state with three neutral coordinates:

```text
wallet
  basis 100
  Event activity -7

reserve
  basis 0
  no Event activity

use
  basis 0
  Event activity +7
```

All three coordinates therefore have explicit basis evidence.

The selected balance policy contains only:

```text
wallet
reserve
```

It does not contain `use`.

The expected answers are:

```text
wallet  -> current 93
reserve -> current 0
use     -> not selected by this view
```

A second policy over the exact same retained Event and Basis facts selects `wallet + use`. Under that question the `use` coordinate is answerable as current `7`.

The intended distinction is therefore:

```text
physical evidence
  Event / Basis / Corrections

query policy
  selected coordinates

projection
  existing CurrentQuantity
```

No accounting role is needed merely to keep those layers distinct.

## Why this is a compression experiment

The candidate policy carries only a set of `EffectCoordinate` values. It does not introduce:

- `AccountId`;
- `AccountType`;
- Asset / Liability / Equity / Income / Expense;
- account hierarchy;
- account registry admission;
- account creation/mutation writers;
- account-specific persistence;
- transaction or posting subclasses.

The experiment therefore tests whether the first practical balance-selection distinction can remain one small query concept rather than opening an Account subsystem.

Compactness is not being measured by source lines alone. The stronger criteria are:

```text
new domain concepts
new canonical facts
new mutation paths
duplicated laws
fact -> projection -> view distance
```

For Observation 102 the target is:

```text
new production domain concepts: 0
new production canonical facts:  0
new production mutation paths:   0
new Account machinery:            0
```

## Relation to current `balances`

The production `balances` command currently enumerates coordinates from the admitted basis frontier and then asks the existing correction-aware current-quantity projection for each coordinate.

Observation 102 does not change that command yet.

Instead it demonstrates the narrower replacement seam:

```text
current:
  admitted basis frontier
      -> coordinates
      -> CurrentQuantity

candidate:
  BalancePolicy
      -> coordinates
      -> CurrentQuantity
```

The candidate does not reinterpret `QuantityBasis`. Basis remains exact quantity evidence at an application origin. The policy is question information only.

## Finding to qualify

The Lean receipt should establish all four concrete witnesses:

- a selected non-zero balance composes existing basis and Event activity;
- a selected explicit-zero balance remains visible;
- a basis-bearing use coordinate can remain absent from the balance view;
- changing only the policy can expose that same use coordinate without changing Event or Basis facts.

If these hold, the practical pressure does not yet earn Account machinery.

It also does not yet earn a production `BalancePolicy` representation. The next question would be how, or whether, a daily-use editor should retain that query preference without turning it into accounting ontology.

## Tool choice

Lean is earned here because the question is no longer only structural independence. Observation 102 asks whether a tiny policy adapter composes with the actual production `CurrentQuantity` function and preserves its exact result type and arithmetic.

Alloy already supplied the negative independence result in Observation 086. Repeating that model would add little.

## Non-goals

Observation 102 does not earn:

- a production `BalancePolicy` type;
- a new persistence stream or configuration file;
- a `track balance` / `untrack balance` command;
- Account, AccountType, or Chart of Accounts;
- an Income or Expense projection;
- post-origin balance creation semantics;
- balance-policy correction/history semantics;
- TUI or editor changes;
- private household values in the public repository.

## Practical Core impact

None.

The probe is experiment-only and reuses the current production `CurrentQuantity` boundary unchanged.
