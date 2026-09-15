# Observation 252 — REA to Ledger accounting-view commutation

Status: **EXPERIMENT — Alloy qualification pending**

LOAM baseline:

```text
shumoku88-bit/loam
main: 6eaa8adfbfb94224ef3243a307100d66af217f5b
Observation 250 / PR #919 merged
Observation 251 / PR #922 merged
```

## Question

Observations 250 and 251 established two different connection shapes:

```text
LOAM BalancedMovement
    -> Ledger/Pacioli-shaped additive observation
```

and

```text
LOAM retained evidence
+ independent economic interpretation
    -> selected REA view
```

Observation 252 asks what belongs on the remaining REA -> Ledger edge.

The external REA literature explicitly treats debit/credit/account judgements as
views that can be materialized after transaction capture rather than intrinsic
REA event facts. Therefore this observation does not assume that REA itself
uniquely determines a Ledger account coordinate.

The selected question is:

> Does a selected REA interpretation uniquely determine the same Ledger image as
> Observation 250, or is an additional accounting-view policy required; and if
> that policy agrees with the direct LOAM coordinate view, do the two routes
> commute?

## Bounded triangle

The fixed LOAM evidence remains:

```text
Payment
  CashLocus   JPY  -100
  GoodsLocus  JPY  +100
```

The selected REA overlay remains observation-local:

```text
resourceOf  : Locus -> Resource
participant : Event -> Agent set
duality     : Event -> Event
```

The Ledger shadow contains three `AccountName x Commodity` coordinates:

```text
CashAccount        x JPY
GoodsAccount       x JPY
AlternativeAccount x JPY
```

Observation 250's direct route is represented by:

```text
CashLocus  -> CashAccount x JPY
GoodsLocus -> GoodsAccount x JPY
```

The new relation is deliberately separate from REA:

```text
ledgerCoordinateOfResource : Resource -> LedgerCoordinate
```

This is the accounting-view policy being tested.

## Expected boundary

### O252-1 — a compatible triangle can exist

Expected:

```text
compatibleTriangleExists = SAT
```

REA interpretation is not incompatible with the direct Observation-250 Ledger
view.

### O252-2 — REA does not uniquely determine Ledger accounting view

Hold `resourceOf`, `participant`, and `duality` fixed while changing only
`ledgerCoordinateOfResource`.

Expected:

```text
sameReaDifferentLedgerView = SAT
ReaInterpretationDeterminesLedgerImage = SAT counterexample
```

If qualified, the REA -> Ledger edge needs explicit accounting-view policy.

### O252-3 — a misaligned view can break commutation

Expected:

```text
misalignedAccountingViewBreaksCommutation = SAT
```

The triangle is therefore not unconditionally commutative.

### O252-4 — selected REA semantics can be forgotten by the Ledger image

Vary the observed Payment's Agent participation or duality while keeping the
Resource interpretation and accounting view fixed.

Expected:

```text
differentReaSemanticsSameLedgerImage = SAT
```

This is the expected lossy direction: equal balance/account images need not
mean equal economic interpretation.

### O252-5 — Resource granularity matters

Collapse `CashLocus` and `GoodsLocus` to the same REA Resource while the direct
LOAM route keeps them at distinct Ledger coordinates.

Expected:

```text
resourceCollapseBlocksCommutation = SAT
```

A Resource-only account view cannot recover distinctions already erased by the
REA interpretation.

### O252-6 — explicit compatibility is sufficient for commutation

Define compatibility above Effects:

```text
for every observed Locus l:
  accountView(resourceOf(l)) = directLedgerCoordinate(l)
```

Expected:

```text
CompatibleAccountingViewCommutes = UNSAT counterexample
```

Then every Effect reaches the same Ledger coordinate through either route.

A second positive control is expected:

```text
CompatibleViewCannotHideDistinctDirectCoordinates = UNSAT counterexample
```

If two direct LOAM coordinates are distinct, a compatible Resource-only bridge
cannot first collapse their Loci to the same Resource.

## Intended result

If the matrix qualifies, the connection triangle is not:

```text
               LOAM
              /    \
             v      v
           REA ---> Ledger
             automatic
```

but:

```text
                    LOAM retained evidence
                    /                  \
                   /                    \
       economic interpretation          additive denotation
                 /                        \
                v                          v
              REA                   Ledger/Pacioli
                \
                 \
          accounting-view policy
                   \
                    v
              Ledger/Pacioli
```

with a commutation obligation:

```text
accountView(resourceOf(locus))
    =
directLedgerCoordinate(locus)
```

for every observed Locus in the selected projection.

## Why this matters

The expected result gives the three systems different jobs rather than ranking
them:

- LOAM retains neutral evidence and identity/provenance distinctions;
- REA supplies economic interpretation such as Resource, Agent participation,
  and duality where a question needs them;
- Ledger semantics supplies an additive accounting denotation;
- an explicit accounting-view policy connects REA interpretation to a chosen
  Ledger account surface.

The policy is not evidence that Account must become a LOAM Core noun. It is a
view boundary.

## Deliberate limits

Observation 252 does not formalize:

- complete REA ontology or ISO/IEC 15944-4;
- complete ledger-semantics category/groupoid structure;
- debit/credit presentation rules;
- accounting roles, financial statement classification, or cash-flow class;
- valuation, prices, lots, booking, recognition, or tax policy;
- Event or Effect correction provenance;
- numeric Pacioli flow equality beyond the already-qualified Observation-250
  additive preservation laws.

The Alloy model asks only whether coordinate selection commutes.

## Stop condition

Do not add Account, Resource, Agent, Duality, or accounting-view policy to
production LOAM merely because this experiment uses them.

A later Lean observation may promote the positive commutation condition into a
generic theorem if the Alloy boundary qualifies and the theorem can reuse the
existing Observation-250 bridge without expanding production Core.
