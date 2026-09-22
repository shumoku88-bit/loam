# Observation 269 — valid unknown classification is not invalid recording

Status: **PROPOSED — Alloy qualification pending**

Issue: #1169

## Trigger

LOAM deliberately refuses to invent household meaning.

That is a safety property, but a daily recording entrance can become unusable if
"meaning is not fully known yet" is treated as "the physical movement is invalid".

Common examples include:

- one exact PayPay/card payment whose purpose is still unclear;
- a bulk purchase where some quantity is already classified and the remainder is not;
- an advance or split expense awaiting later settlement;
- a lost receipt where the exact cash reduction is known.

The research question is narrower than "add a suspense account":

> Can LOAM retain the exact physical quantity now, keep the unresolved remainder
> explicit, and later refine only that remainder without weakening conservation
> or inventing a new Measure?

## Model boundary

The model deliberately fixes one Measure.

That stands for the case where the physical unit is already known, such as JPY.
It therefore does **not** model "unknown currency" by creating a suspense Measure.

The four Loci are:

```text
Source
KnownA
KnownB
Suspense
```

For a snapshot to be admitted:

- Source must carry a negative quantity;
- all destination quantities are non-negative;
- the whole movement is conserved.

An unresolved snapshot is admitted and has positive Suspense quantity.

A partially-known snapshot additionally has some positive quantity already
assigned to KnownA or KnownB.

## Candidate refinement law

Classification refinement may move quantity only:

```text
Suspense -> KnownA / KnownB
```

It may be partial or complete.

The predicate intentionally does **not** state that the Source quantity is unchanged.
Instead the Alloy assertions test whether:

```text
exact conservation
+ destination redistribution only
```

is already enough to force the physical payment to remain unchanged.

This matters because the desired production law is not "trust a special suspense mutation".
It is closer to:

> reclassification changes interpretation of the unresolved destination quantity,
> not the observed physical payment.

## Expected qualification matrix

The first bounded run should require:

```text
validUnknownExists                         SAT
validPartialClassificationExists           SAT
partialResolutionExists                    SAT
fullResolutionExists                       SAT
invalidImbalanceExists                     SAT

UnknownIsNotInvalid                        UNSAT counterexample
RedistributionPreservesPhysicalPayment     UNSAT counterexample
RedistributionPreservesDestinationTotal    UNSAT counterexample
FullResolutionLeavesNoUnresolvedQuantity   UNSAT counterexample
```

The SAT witnesses show that strict conservation does not require all-or-nothing
classification.

The invalid imbalance witness preserves the important opposite boundary:
"unknown" is admissible only when the physical movement itself is coherent.
Suspense is not a way to accept arbitrary malformed quantities.

## What this observation does not earn

Even if the bounded assertions hold, this does **not** yet justify:

- a new Core `Suspense` type;
- a new canonical file;
- a new Measure;
- automatic AccountingRole assignment;
- a second retained Attention flag;
- a particular TUI workflow;
- tax decomposition;
- HRA-N implementation.

The strongest desirable result would be that existing Event / Effect / Locus /
Measure / Correction semantics are already sufficient and only a conventional
designated Locus plus derived queries are needed.

## Tax boundary

Consumption tax is deliberately outside this observation.

For an ordinary household purchase whose exact total is known to be JPY, the
movement may retain the tax-inclusive physical amount. Tax-rate or tax-component
evidence should become mandatory only if a later admitted query proves that the
extra distinction is required.

## Next step

If Alloy qualifies the redistribution law, pressure it against LOAM's real
Event/Effect and Correction semantics.

Only if a stable general theorem remains useful after that contact should a
small Lean theorem be promoted into the permanent proof surface.
