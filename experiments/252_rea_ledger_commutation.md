# Observation 252 — REA to Ledger accounting-view commutation

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

LOAM baseline:

```text
shumoku88-bit/loam
main: 6eaa8adfbfb94224ef3243a307100d66af217f5b
Observation 250 / PR #919 merged
Observation 251 / PR #922 merged
```

Exact pre-qualification branch head:

```text
9888f9bbae2d4e3e70ac3e12311216a58f2bb2ac
```

GitHub Actions qualification:

```text
workflow: Observation 252
run:      34983842489
job:      104430749595
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
```

Observed matrix:

```text
compatibleTriangleExists                               SAT
sameReaDifferentLedgerView                             SAT
misalignedAccountingViewBreaksCommutation              SAT
differentReaSemanticsSameLedgerImage                   SAT
resourceCollapseBlocksCommutation                      SAT
ReaInterpretationDeterminesLedgerImage                 SAT counterexample
CompatibleAccountingViewCommutes                       UNSAT counterexample
CompatibleViewCannotHideDistinctDirectCoordinates      UNSAT counterexample
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

The qualified answer is:

```text
REA interpretation alone
    -/-> unique Ledger image

REA interpretation + explicit accounting-view policy
    -> Ledger image

policy agreement with the direct LOAM view
    -> commuting coordinate selection
```

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

## Qualified boundary

### O252-1 — a compatible triangle can exist

Observed:

```text
compatibleTriangleExists = SAT
```

REA interpretation is not incompatible with the direct Observation-250 Ledger
view.

### O252-2 — REA does not uniquely determine Ledger accounting view

Hold `resourceOf`, `participant`, and `duality` fixed while changing only
`ledgerCoordinateOfResource`.

Observed:

```text
sameReaDifferentLedgerView = SAT
ReaInterpretationDeterminesLedgerImage = SAT counterexample
```

Therefore the selected REA interpretation does not determine one Ledger account
surface. The REA -> Ledger edge needs explicit accounting-view policy.

### O252-3 — a misaligned view can break commutation

Observed:

```text
misalignedAccountingViewBreaksCommutation = SAT
```

The triangle is not unconditionally commutative.

### O252-4 — selected REA semantics can be forgotten by the Ledger image

Vary the observed Payment's Agent participation or duality while keeping the
Resource interpretation and accounting view fixed.

Observed:

```text
differentReaSemanticsSameLedgerImage = SAT
```

Equal balance/account images therefore need not mean equal economic
interpretation. The Ledger projection is intentionally lossy with respect to
these selected REA distinctions.

### O252-5 — Resource granularity matters

Collapse `CashLocus` and `GoodsLocus` to the same REA Resource while the direct
LOAM route keeps them at distinct Ledger coordinates.

Observed:

```text
resourceCollapseBlocksCommutation = SAT
```

A Resource-only accounting-view function cannot recover distinctions already
erased by a coarser Resource interpretation.

### O252-6 — explicit compatibility is sufficient for commutation

Define compatibility above Effects:

```text
for every observed Locus l:
  accountView(resourceOf(l)) = directLedgerCoordinate(l)
```

Observed:

```text
CompatibleAccountingViewCommutes = UNSAT counterexample
```

Within the bounded model, every Effect then reaches the same Ledger coordinate
through either route.

The second positive control also qualified:

```text
CompatibleViewCannotHideDistinctDirectCoordinates = UNSAT counterexample
```

If two direct LOAM coordinates are distinct, a compatible Resource-only bridge
cannot first collapse their Loci to the same Resource.

## Qualified connection shape

The connection triangle is not:

```text
               LOAM
              /    \
             v      v
           REA ---> Ledger
             automatic
```

It is:

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

This means the triangle can commute without making REA or Ledger primitives of
LOAM, but the REA-mediated route needs a separately explicit view policy.

## Why this matters

The three systems now have distinguishable jobs rather than a ranking:

- LOAM retains neutral evidence and identity/provenance distinctions;
- REA supplies economic interpretation such as Resource, Agent participation,
  and duality where a question needs them;
- Ledger semantics supplies an additive accounting denotation;
- an explicit accounting-view policy connects REA interpretation to a chosen
  Ledger account surface.

The policy is not evidence that Account must become a LOAM Core noun. It is a
view boundary.

A further consequence is now visible: REA Resource granularity can be too coarse
for one selected Ledger surface. If two distinct LOAM coordinates are first
collapsed to one Resource, a Resource-only account mapping cannot later recreate
both coordinates. Any future REA bridge must therefore state its information-loss
boundary explicitly rather than assuming Resource identity is always a lossless
replacement for Locus identity.

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

## Next gate

The Alloy result earns one small follow-up question:

> Can the positive commutation condition be stated and proved generically in
> Lean by reusing Observation 250's `LedgerAccountShadow`, without adding REA or
> accounting-view nouns to production Core?

That successor should be a theorem about a supplied interpretation/view mapping,
not a new production ontology.

## Stop condition

Do not add Account, Resource, Agent, Duality, or accounting-view policy to
production LOAM merely because this experiment uses them.

A later Lean observation may promote the positive commutation condition into a
generic theorem only if it reuses the existing Observation-250 bridge without
expanding production Core.
