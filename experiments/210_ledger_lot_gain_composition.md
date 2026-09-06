# Observation 210 — Ledger lot / gain composition

Status: **Ledger reconstruction gate; C-seeking bounded composition probe**

## Question

Observations 066–071 already separated the static pieces:

```text
historical valuation != acquisition basis
aggregate holding != disposal provenance
policy-selected attribution != retained source attribution
current policy != retained historical attribution
```

Observations 208–209 then qualified chart/status/date and generation/finality compositions without enlarging neutral Event/Effect.

Observation 210 asks the remaining Ledger-style valuation question:

```text
acquisition-specific basis
+ disposal provenance
+ sale proceeds
+ remaining market valuation
+ cost-vs-market report policy
    -> realised gain
     + unrealised gain
     + selected remaining value
```

Does composing these meanings expose a need for a larger neutral physical Core, or are explicit additive evidence and policy sufficient?

## External pressure

Ledger 3 distinguishes lot/acquisition cost from later market value and can report gain using acquisition-specific cost information. hledger 1.52 also distinguishes posting-attached costs from ambient market valuation, while its automated lot/gain machinery is more limited than Ledger 3.

References:

- https://ledger-cli.org/doc/ledger3.html
- https://hledger.org/1.52/hledger.html

This probe targets the common semantic pressure, not syntax or full investment-accounting parity.

## Observation-local model

There are exactly two acquisition identities:

```text
AcquisitionA
AcquisitionB
```

Each carries an independently supplied acquisition basis. One acquisition is selected as the source consumed by a disposal. The other remains held.

The world also supplies:

```text
saleProceeds
remainingMarketValue
reportMode = CostMode | MarketMode
```

The bounded values `V0` through `V4` and gain/loss atoms `Loss4` through `Gain4` are connected by an explicit exact difference table. The model deliberately avoids Alloy integer overflow and does not claim production currency arithmetic.

Selected answers are:

```text
realised gain   = sale proceeds - disposed acquisition basis
unrealised gain = remaining market value - remaining acquisition basis
cost report     = remaining acquisition basis
market report   = remaining market value
```

This is a one-unit-like composition specimen. Observation 067 already established quantity-bearing multi-source disposal provenance, so 210 does not repeat partial-lot allocation arithmetic.

## C-seeking witnesses

### Lot selection changes both realised and unrealised gain

Hold acquisition bases, sale proceeds, and market value fixed. Dispose A in one world and B in another.

Expected: **SAT**.

The same aggregate holding and sale amount can produce different realised gain because different basis provenance was consumed. The remaining basis also changes, so unrealised gain changes.

### Market value alone does not determine unrealised gain

Hold the remaining market value fixed while changing the remaining acquisition basis.

Expected: **SAT**.

Market valuation and acquisition basis are different information, as Observation 066 predicted.

### Basis/provenance fixed, market value changes unrealised gain only

Hold acquisition bases, disposal source, and sale proceeds fixed. Change only the remaining market value.

Expected: **SAT**.

Realised gain stays fixed while unrealised gain changes.

### Same realised gain scalar, different provenance

Choose different disposed acquisitions and sale proceeds that yield the same gain scalar.

Expected: **SAT**.

A gain number does not reconstruct which acquisition basis produced it.

### Cost and market reports select different remaining values

Hold all evidence fixed and switch only report mode.

Expected: **SAT**.

Cost view and market-value view must not be silently collapsed.

## Expected Alloy matrix

```text
representativeLotGain                                  SAT
lotSelectionChangesRealisedAndUnrealisedGain           SAT
sameMarketDifferentRemainingBasisChangesUnrealisedGain SAT
sameBasisDifferentMarketChangesUnrealisedOnly          SAT
sameRealisedGainDifferentProvenance                     SAT
reportModeChangesSelectedRemainingValue                 SAT

BasisAndProceedsDetermineRealisedGain                  SAT counterexample
MarketValueDeterminesUnrealisedGain                    SAT counterexample
RealisedGainScalarDeterminesDisposalProvenance         SAT counterexample
BasisDeterminesMarketValue                             SAT counterexample
ExplicitValuationInputsDetermineGains                  UNSAT counterexample
ExplicitReportInputsDetermineSelectedValue             UNSAT counterexample
ExplicitInputsDetermineSelectedAnswers                 UNSAT counterexample
```

## Interpretation gate

If acquisition basis, disposal provenance, market valuation, and report policy are independently observable but fixing them fixes all selected gain/value answers, classify:

```text
B / conservative additive composition
```

Only if a legitimate selected Ledger answer still cannot be represented because the existing Event/Effect/EffectKey shape is semantically insufficient would this demonstrate:

```text
C / Core-shape pressure
```

## Production boundary

Even if the expected matrix succeeds, this observation does **not** earn:

- a production `Lot` object;
- a production `CostBasis` fact family;
- FIFO/LIFO/average-cost/specific-identification policy;
- tax basis rules;
- stock splits, mergers, spin-offs, fees, or corporate actions;
- short-position semantics;
- automatic gain postings;
- production market-price persistence;
- investment UI/CLI;
- Ledger file-format compatibility.

It asks only whether the selected Ledger-style lot/gain composition forces neutral Event/Effect to grow.
