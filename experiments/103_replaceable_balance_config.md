# Observation 103: Does current balance selection need canonical history?

## Question

Observation 102 connected a tiny balance policy directly to the production current-quantity projection while keeping `QuantityBasis` separate from accounting classification.

That still leaves a persistence question:

> If the only current requirement is "which neutral coordinates should this balance view ask about now?", must that selection become another append-only canonical fact family with stable identity and correction history?

Observation 103 asks whether a smaller boundary is sufficient first:

```text
canonical facts
  Event / EventCorrection
  QuantityBasis / QuantityBasisCorrection

replaceable application configuration
  selected coordinates

projection
  CurrentQuantity
```

## Existing evidence

This question composes several earlier observations rather than starting from a blank slate.

Observation 047 separated selection policy from the graph or facts it selects over. Observation 068 later separated policy-selected output from independently retained historical/source provenance. Observations 085 and 086 showed that basis/Event presence does not determine anchored-current selection. Observations 101 and 102 then showed that an explicit balance selection seam can stay small and can feed the production current-quantity projection directly.

Those results make a second append-only history mechanism look unearned unless the application actually needs policy provenance or historical "as-known" policy views.

## Lean probe

`103_replaceable_balance_config.lean` deliberately uses the smallest representation that can express the current requirement:

```lean
abbrev BalanceConfig := List EffectCoordinate
```

There is no new production type and no experiment-local identity or correction relation.

The same retained synthetic Event/Basis state contains:

- a non-zero wallet balance;
- an explicitly-zero reserve balance;
- a basis-bearing use coordinate.

One configuration selects wallet + reserve. Another selects wallet + use.

Both configurations call the existing production `inspectCurrentQuantityWithBasisCorrections` over exactly the same retained facts.

The probe checks that:

- wallet remains `93` in the ordinary daily configuration;
- explicitly-zero reserve remains visible as `0`;
- basis-bearing use remains outside that balance view;
- replacing only the configuration can select use and obtain `7` without rewriting Event or Basis facts;
- duplicate configuration rows do not create another semantic selection;
- configuration order does not change the selected quantity answer.

## Finding boundary

For the current balance-view requirement, the experiment supports this smaller interpretation:

```text
balance selection
  = current application question configuration

not yet

balance selection
  = canonical historical fact
```

That distinction matters for compactness. Treating current view configuration as canonical history would immediately earn machinery such as:

```text
PolicyId
PolicyMemory
PolicyCorrection
frontier admission
persistence ordering rules
writer ownership
```

None of that is required to answer the current question exercised by this probe.

The retained financial facts remain the source of quantity truth. Configuration only chooses which coordinates the application asks the already-qualified projection to inspect.

## Important limit

This observation does **not** prove that balance configuration should never have history.

If a future requirement asks:

- which balance policy was active at an earlier knowledge time;
- who changed the policy;
- why one coordinate was selected historically;
- whether a historical report must reproduce the exact policy then in force;

then current replaceable configuration is insufficient. At that point policy history or another retained fact may be earned.

Observation 068 is especially relevant: a current policy must not silently stand in for independently required provenance.

## Compactness impact

At this checkpoint the candidate path remains:

```text
Event / Basis facts
      ↓
small replaceable config
      ↓
CurrentQuantity
      ↓
view
```

with no Account machinery and no second correction/history subsystem.

This is a stronger compression result than merely reducing source LOC: one semantic responsibility, current view selection, remains outside canonical financial history until historical responsibility is actually required.

## Non-goals

Observation 103 does not introduce:

- production `BalanceConfig` or `BalancePolicy`;
- a config file, environment variable, CLI flag, or TUI editor;
- Account, AccountType, Asset, Expense, Income, Liability, or registry machinery;
- policy identity, provenance, chronology, correction, or append-only history;
- private household data;
- any change to Core, Persistence, CLI, TUI, or wire formats.

## Tool choice

Lean is sufficient because the new practical question is whether the smallest replaceable configuration value can feed the already-qualified production projection while retaining exact output behavior. No new temporal/history law is claimed. If historical policy reconstruction becomes a requirement later, that transition may earn TLA+ or another explicit retained-history model.

## Practical Core impact

None.
