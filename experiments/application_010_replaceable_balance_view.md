# Application 010: replaceable balance-view configuration

## Pressure

Real daily-use dogfood exposed a false coupling in the first human-facing `balances` command.

The command selected every coordinate retained by the admitted `QuantityBasis` frontier. That was useful as an early safe boundary, but it also made basis presence do two jobs:

```text
basis fact
  -> evidence for anchored quantity
  -> implicit membership in the balance view
```

Observations 085 and 086 rejected that collapse. Basis applicability is query-relative, and basis/Event presence does not determine which coordinates one query should select.

Observations 101 through 103 then qualified a smaller application seam:

```text
canonical quantity evidence
  Event / EventCorrection
  QuantityBasis / QuantityBasisCorrection

current application question
  List EffectCoordinate

projection
  CurrentQuantity
```

Application 010 connects that seam to ordinary dogfood.

## Production shape

The current data directory may contain one replaceable file:

```text
balance-view.tsv
```

Each row is only:

```text
<locus-token><TAB><measure-token>
```

For example:

```text
wallet	jpy
reserve	jpy
```

The file is intentionally not a LOAM canonical memory format. It has:

- no stable row identity;
- no append-only history;
- no correction relation;
- no current frontier;
- no authority or provenance claim;
- no Asset / Liability / Income / Expense role;
- no Account registry.

Replacing the file replaces the current question only. Event and Basis facts remain unchanged.

## Missing and malformed configuration

A missing `balance-view.tsv` means an empty current selection. It does not mean every basis coordinate is selected and it does not invent zero balances.

Malformed rows fail closed before any balance row is printed.

A selected coordinate without admitted starting-basis evidence also fails closed through the existing `CurrentQuantity` boundary. Configuration therefore chooses a question but cannot manufacture the evidence needed to answer it.

## Backward compatibility

Direct CLI use without a balance-view argument retains the earlier basis-frontier selection behavior:

```text
loamDailyQuantity balances <events> <event-corrections> <basis> [basis-corrections]
```

The ordinary `tools/loam` menu now supplies the data-directory `balance-view.tsv` path, so daily dogfood exercises the new explicit selection boundary.

This keeps the semantic change narrow: old direct callers still work while the primary human-facing path stops treating basis presence as hidden balance classification.

## Compactness result

The production delta introduces one tiny config decoder and one optional selection input. It does not introduce a second financial subsystem.

The intended path remains:

```text
Event / Basis facts
      ↓
current coordinate list
      ↓
CurrentQuantity
      ↓
balance view
```

rather than:

```text
AccountId
AccountType
AccountRegistry
PolicyId
PolicyMemory
PolicyCorrection
PolicyFrontier
      ↓
balance view
```

That larger machinery remains available to be earned by future pressure, but it is not required by the current balance-view question.

## Qualification target

`Practical Starting Quantity` covers the production boundary with synthetic witnesses:

- a basis-bearing use coordinate can remain outside the configured balance view;
- an explicitly-zero selected balance remains visible;
- duplicate config rows do not duplicate rendered balances;
- replacing only the config changes the selected view without rewriting canonical facts;
- malformed config fails closed;
- selecting a basisless coordinate fails closed;
- the primary menu uses the current data-directory config;
- absent menu config produces an explicit empty view rather than hidden basis-derived selection.

## Deliberate limits

Application 010 does not yet add an editor for `balance-view.tsv`.

Manual or external replacement is sufficient for the first dogfood checkpoint. If repeatedly editing this file becomes real friction, that pressure can earn a tiny typed editor/TUI action without changing the canonical financial model.
