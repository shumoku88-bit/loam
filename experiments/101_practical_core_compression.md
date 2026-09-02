# Observation 101: Can balance meaning stay application-local without rebuilding Account machinery?

## Question

Recent practical dogfood exposed a tension.

LOAM can already retain ordinary multi-effect quantity Events without assigning accounting roles to `LocusId` or signs. A practical balance view, however, needs to know which loci belong in that particular view.

One response would be to introduce familiar accounting machinery immediately:

```text
AccountId
AccountType
Account declaration
Account registry
Account admission
Account writer
```

Those concepts may eventually be earned, but Observation 101 asks a smaller question first:

> For the balance query alone, is one explicit application-local selection of neutral loci sufficient, while Events and Effects remain unchanged?

The purpose is not to avoid accounting vocabulary at any cost. It is to discover whether the required distinction is smaller than a full Account subsystem.

## Pressure from the comparison

A typed accounting application normally knows up front which coordinates are balance-owning and which are flow/use coordinates. That gives excellent clarity, but it also brings declarations, registries, validation, mutation paths, and UI concepts with it.

LOAM currently has a smaller retained shape:

```text
Event
  -> Effects
       -> LocusId × MeasureId × Quantity
```

The practical question is whether a balance view can remain:

```text
neutral retained facts
  + explicit query evidence
  -> selected projection
```

instead of turning every retained locus into an Account.

No private household values, dates, descriptions, identities, or account names are used in this public experiment.

## Synthetic witnesses

The Lean probe uses three accounting-shaped but deliberately anonymous Event forms.

### One balance locus to one use locus

```text
asset-a  -7
use-a    +7
```

### One balance locus to another balance locus

```text
asset-a  -5
asset-b  +5
```

### One balance locus split across two use loci

```text
asset-b  -11
use-a     +4
use-b     +7
```

All three remain ordinary LOAM Events with ordinary Effects. Their shapes do not contain debit, credit, Asset, Expense, transfer, purchase, or posting-order semantics.

## Candidate compression

`101_practical_core_compression.lean` introduces only an experiment-local value:

```text
BalanceScope
  = explicit set-like list of LocusId values selected for one balance query
```

The probe then computes ordinary Event quantity projections only for loci admitted by that scope.

With the synthetic scope:

```text
{ asset-a, asset-b }
```

it checks that:

- the source side of the one-use Event is visible;
- the use locus remains retained by the Event but is absent from the balance view;
- both sides of the balance-to-balance transfer are visible;
- the split-use Event still changes only the selected balance locus in this query;
- narrowing the scope changes the view without changing any Event or Effect.

## What this would compress

If this tiny shape survives further pressure, the first practical distinction needed for balances would not yet require:

- `AccountId`;
- `AccountType`;
- an Account registry;
- an Account declaration persistence stream;
- an Account-specific Event form;
- transfer-specific or spending-specific Core types.

That would be a genuine structural compression rather than a rename: the retained Event model would stay neutral and the accounting distinction would live only where the selected query needs it.

## What this does not prove

The experiment is intentionally narrow.

It does **not** show that a complete household accounting application can avoid Accounts.

In particular it does not yet provide:

- Income versus Expense classification;
- Liability or Equity semantics;
- a chart-of-accounts naming policy;
- stable human-facing locus declaration or rename behavior;
- admission of unknown loci;
- persistence for `BalanceScope`;
- Plan or Envelope meaning;
- editor or TUI behavior;
- starting-basis composition;
- correction-aware whole-memory balance projection.

If those later needs force the same declarations and invariants as an Account registry, the compression attempt should say so rather than rebuild the familiar machinery under new names.

## Compactness criteria

Observation 101 treats compactness as more than line count.

A later production step should be considered smaller only if it reduces at least one meaningful structural cost without hiding the law elsewhere:

```text
fewer domain concepts
fewer dedicated mutation paths
fewer duplicated laws
shorter input -> fact -> projection -> view path
less UI-side reinterpretation
one proof boundary for one shared law
```

Moving complexity into strings, conventions, or unchecked UI code does not count as compression.

## Practical Core impact

None yet.

- no Core change;
- no Application change;
- no Persistence change;
- no CLI or TUI change;
- no wire-format change;
- no private canonical data committed;
- `BalanceScope` exists only inside the experiment.

The next step, if the Lean receipt succeeds, is to decide whether this result earns a tiny application-level balance-selection primitive or whether existing basis evidence already supplies the right selection boundary.
