# Observation 220 — Does uncorrected QuantityBasis factor through one origin snapshot?

Status: **PROBE**

## Pressure

Observation 219 qualified a narrow current-data result:

```text
pointwise-zero QuantityBasis
    ->
explicit coverage domain + existing Event quantity
```

The common zero was numerically redundant, but the finite coverage domain remained
observable because `basisMissing != zero`.

That leaves a stronger question. The historical LOAM dogfood previously used
non-zero starting quantities. If non-zero bootstrap remains useful, does that force
LOAM to keep one independently identified `QuantityBasis` fact per coordinate?

The narrower question is:

> Before basis correction ancestry is observed, is a finite
> `Coordinate -> starting Quantity` image sufficient for the same current-quantity
> answers?

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

The probe checks:

1. non-zero `wallet` production current equals the snapshot current (`93`);
2. covered zero `reserve` remains exact current zero;
3. uncovered `use` remains `basisMissing` despite Event activity;
4. the two basis memories are different retained evidence;
5. changing only the stable basis ids does not change either current answer.

This asks directly whether line identity is observed by the current quantity
question before correction edges exist.

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
corrected basis memory != direct current basis memory
correction memory       != empty correction memory
```

So the current quantity projection does not by itself observe basis ancestry.
That ancestry may still matter for provenance, future correction, or another
query. Observation 220 must not silently erase it merely because a current-value
projection factors through a smaller state image.

## Interpretation

There are now three distinct information levels:

```text
current quantity answer
        ^
        |
Coordinate -> current origin quantity
        ^
        |
per-line basis identity + correction ancestry
```

The top layer may be a sufficient statistic for one current query while failing
to preserve the lower layer's provenance.

This is directly relevant to the current HRA-backed operating mode. LOAM no longer
needs to preserve historical LOAM correction machinery merely for operational
continuity. Therefore the burden of proof changes:

> If no intended LOAM question observes basis correction ancestry, retaining a
> correction graph for hypothetical future edits may be unnecessary machinery.

That is a product/design question, not something this extensional probe alone can
settle.

## Accounting comparison

A conventional opening balance is naturally a finite state vector over accounts.
The candidate here has a similar mathematical shape but deliberately avoids
claiming that LOAM Core therefore needs Account or debit/credit ontology.

The interesting convergence is smaller:

```text
starting state
    = finite partial coordinate -> quantity map
```

rather than one separately identified fact per coordinate merely because the
initial implementation used append-only memories.

## Expected finding if the probe passes

The intended bounded finding is:

```text
uncorrected/non-ancestry current quantity
    factors through
finite origin snapshot + Event quantity

stable QuantityBasisId
    is not observed by that current answer

basis correction ancestry
    is stronger evidence than the snapshot
    even when both give the same current value
```

This would make the next question explicit:

> Does future LOAM have an independently useful query or workflow that requires
> retained basis correction ancestry?

If not, `QuantityBasisMemory + QuantityBasisCorrectionMemory + BasisCut` may be a
historically earned implementation family whose remaining production pressure has
collapsed to a much smaller origin-state boundary.

## Non-goals

Observation 220 does not authorize:

- deleting QuantityBasis production code;
- converting every opening state into a fictional Event;
- dropping `basisMissing != zero`;
- inferring origin coverage from AccountingRole or balance-view;
- claiming correction provenance is universally irrelevant;
- introducing Account as Core ontology;
- committing private household values.

## Practical Core impact

None for the probe.
