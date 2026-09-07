# Observation 220 — Does QuantityBasis current state factor through one origin snapshot?

Status: **QUALIFIED CURRENT-VALUE FACTORIZATION**

## Pressure

Observation 219 qualified a narrow current-data result:

```text
pointwise-zero QuantityBasis
    ->
explicit coverage domain + existing Event quantity
```

The common zero was numerically redundant, but the finite coverage domain remained
observable because `basisMissing != zero`.

That leaves a stronger question. Historical LOAM dogfood previously used non-zero
starting quantities. If non-zero bootstrap remains useful, does that force LOAM to
keep one independently identified `QuantityBasis` fact per coordinate?

The narrower question is:

> For the current-quantity answer, is a finite
> `Coordinate -> starting Quantity` image sufficient even when the starting value
> is non-zero?

## Candidate

The experiment introduces only an observation-local:

```text
OriginSnapshot
  = finite partial map
      EffectCoordinate -> Quantity
```

It carries:

- explicit finite coverage;
- one exact starting quantity per covered coordinate.

It deliberately does **not** carry:

- one stable identity per coordinate/value line;
- append-only basis-correction ancestry;
- Account or AccountingRole meaning;
- balance-view selection;
- Event chronology.

For one covered coordinate:

```text
current
  = originSnapshot[coordinate]
  + correction-aware Event quantity
```

For an uncovered coordinate:

```text
basisMissing
```

## Lean specimen

The public synthetic Event world contains:

```text
wallet Event quantity = -7
use Event quantity    = +7
reserve activity      = 0
```

The initial origin image is:

```text
wallet  = 100
reserve = 0
```

Two separate production `QuantityBasisMemory` values retain exactly those
coordinate/value facts but use completely different stable `QuantityBasisId`
values.

The executable checks establish:

1. non-zero `wallet` production current equals the snapshot current (`93`);
2. covered zero `reserve` remains exact current zero;
3. uncovered `use` remains `basisMissing` despite Event activity;
4. the two basis fact lists are different retained evidence;
5. changing only the stable basis ids does not change either current answer.

So stable per-line identity is not observed by this current-value question before
basis correction ancestry is queried.

## Correction ancestry control

The probe then adds a stronger retained history:

```text
wallet-v1 = 100
wallet-v2 = 120
wallet-v1 -> wallet-v2
```

The correction-aware production answer is `113` after the `-7` Event activity.

A direct current basis of `120` with no basis-correction edge produces the same
current answer, as does an origin snapshot containing `wallet = 120`.

But the retained evidence is deliberately unequal:

```text
corrected basis fact list != direct current basis fact list
correction list           != empty correction list
```

So the current quantity projection does not observe basis ancestry even though
that ancestry remains stronger retained provenance.

## Executed result

The first CI attempt exposed only experiment-fixture mistakes:

- `QuantityBasisMemory` contains proof fields and does not itself provide the
  `DecidableEq` needed for a direct `by decide` memory inequality;
- the synthetic `QuantityBasisCorrection` omitted its required correction `id`.

The probe was corrected to compare the underlying decidable fact lists and to
supply the explicit correction identity. No semantic candidate or expected
quantity was changed.

The corrected Observation 220 Lean job then compiled every equality and
inequality witness successfully against production `CurrentQuantity`.

## Finding

The qualified boundary is:

```text
current quantity answer
        ^
        |
finite Coordinate -> origin Quantity snapshot
        ^
        |
per-line QuantityBasis identity + correction ancestry
```

For the tested current-value projection, the middle layer is sufficient even for
a non-zero starting quantity.

More precisely:

```text
starting quantity value + explicit coverage
    -> observed by current quantity

stable QuantityBasisId alone
    -> not observed by current quantity

basis correction ancestry
    -> stronger retained evidence
       but can collapse to the same current origin snapshot
```

This is not a claim that provenance is false or useless. It is a separation of
questions: current value does not require all evidence needed to reconstruct how
that value was revised.

## Current production pressure

The production repository still has an active human-facing
`correct-starting-quantity` entrance. It currently implements a `100000 -> 95000`
style correction append-only using:

```text
new QuantityBasisId
+ QuantityBasisCorrectionId
+ target -> replacement edge
+ admitted current frontier
```

So basis correction is not merely dead code.

However, the original Application 009 design explicitly introduced that
append-only correction relation because destructive replacement was disallowed by
LOAM's then-current append-only operating direction. The present operating mode is
different: HRA supplies day-to-day authority and LOAM-local canonical state may be
destructively redesigned when the stronger evidence is recoverable.

Therefore the remaining pressure is no longer:

> Do users need to correct a starting quantity?

They clearly may.

It is:

> Does LOAM need the correction **ancestry graph** as present household state, or
> can one origin snapshot be atomically replaced while Git/HRA preserve the
> historical/reconstruction evidence?

Observation 220 does not answer that policy question automatically, but it shows
that the current-value projection itself does not force the graph to exist.

## Accounting comparison

A conventional opening balance is naturally a finite state vector over accounts.
The candidate here has a similar mathematical shape but deliberately avoids
claiming that LOAM Core therefore needs Account or debit/credit ontology.

The useful convergence is smaller:

```text
starting state
    = finite partial coordinate -> quantity map
```

rather than one separately identified fact per coordinate merely because the
initial implementation used append-only memories.

## Consequence for the next step

The next practical question is now sharp enough to test directly:

> Under the current HRA-authority / destructively-reconstructible LOAM operating
> mode, can `starting-quantity` and `correct-starting-quantity` both be served by
> one atomically replaceable origin snapshot without weakening any currently used
> balance answer or fail-closed coverage distinction?

If yes, the production pressure for:

- `QuantityBasisId`;
- `QuantityBasisCorrectionId`;
- `QuantityBasisCorrectionMemory`;
- correction-frontier admission for starting state;
- basis-correction persistence;

may disappear from the practical current-state path.

`BasisCut` must still be assessed separately because it represented a different
problem: avoiding double-counting Events already reflected in an observed basis.
The current private data no longer contains a basis cut after historical
reconstruction, but that does not make the old semantic pressure nonexistent.

## Non-goals

Observation 220 does not authorize:

- deleting QuantityBasis production code immediately;
- converting every opening state into a fictional Event;
- dropping `basisMissing != zero`;
- inferring origin coverage from AccountingRole or balance-view;
- claiming correction provenance is universally irrelevant;
- introducing Account as Core ontology;
- committing private household values.

## Practical Core impact

None for Observation 220 itself.
