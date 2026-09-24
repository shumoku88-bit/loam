# Observation 328 — Measure scale history distinguishability

Status: **QUALIFIED BOUNDED ALLOY OBSERVATION**

## Trigger

The post-Generation-2 audit finding D3 identified a mismatch between an already
documented household rule and current runtime evidence.

The rule is already explicit:

```text
unused Measure
    -> scale may be selected

Measure with retained household quantities
    -> scale is stable
    -> changing it requires an explicit migration
```

Current `MeasurePresentation` retains only the current
`measure -> decimal scale` configuration. Exact quantities retain Measure and
integer quanta, but not the historical convention under which those quanta first
acquired human fixed-point meaning.

## Question

Can two household histories have:

- the same retained Measure + exact quanta;
- the same current Measure presentation configuration;

while requiring different answers to:

> Under which scale did this retained quantity acquire its human meaning?

If yes, current-state inspection alone cannot distinguish an ordinary unchanged
configuration from a silent reinterpretation.

## Model boundary

The Alloy model introduces `recordedScale` only as **model-side historical
truth**. It is not a proposed LOAM production field.

```text
World
  retained      : set RetainedQuantity
  currentScale  : Measure -> Scale      // visible current config
  recordedScale : Measure -> Scale      // model-only historical truth
```

The model deliberately abstracts away dates, Loci, Event identity, balancing,
and decimal arithmetic. Those are not needed for this distinguishability
question.

## Qualified matrix

GitHub Actions run `35945061540`, Alloy 6.2.0 / Sat4j:

```text
ambiguousCurrentSnapshot                       SAT
silentScaleRewriteExists                       SAT
stableUseExists                                SAT
CurrentSnapshotDeterminesHistoricalConvention  SAT counterexample
QualifiedSnapshotDeterminesHistoricalConvention UNSAT counterexample
```

The fourth command finds the intended counterexample: current retained quanta
plus current presentation configuration do **not** determine the historical
convention.

The fifth includes the historical convention in the qualified snapshot and has
no counterexample within the bound. This does not prescribe how production
should retain that distinction; it only demonstrates the missing information
needed to close the ambiguity.

## Qualified conclusion

The matrix supports this conclusion:

> A validator that sees only current retained quanta and current
> `measure-presentation.tsv` cannot, in general, prove that a used Measure has
> never been silently reinterpreted.

It does **not** yet choose among:

- immutable Measure-convention evidence;
- an append-only convention history;
- explicit migration evidence;
- another fail-closed operational mechanism that preserves the same distinction.

That choice belongs to the D3 obligation audit after the bounded result is known.


## Next obligation

D3 R1 is closed.

The remaining obligation is design selection: preserve the already-documented
used-Measure scale stability rule with the smallest retained operational
boundary, then qualify that production correspondence separately.
