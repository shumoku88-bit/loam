# Observation 088 — Can an existing operation verb justify a zero-origin admission?

## Question

Observation 087 established a temporal possibility:

```text
first appearance
    can provide the time of a new anchor

first appearance
    -/-> whether that anchor should exist
```

A practical next temptation is to let an existing human-facing verb decide.

For example:

```text
first transfer into an unseen destination
    -> destination begins here at zero
```

or:

```text
first income into an unseen destination
    -> destination begins here at zero
```

The production entrances do have useful interface-level promises:

- `transfer` records `source -q / destination +q`;
- `income` records one positive Effect at the selected destination;
- interactive `spend` records `source -q / use locus +q`.

But none of those promises currently says that an unseen destination or use locus was physically empty immediately before LOAM first observed it.

The question is therefore:

> Does the existing operation kind itself justify an exact-zero first-event origin, or does admission require separate evidence that the coordinate really begins at zero here?

## Key distinction

This observation makes `unseen` deliberately epistemic.

Before LOAM first sees a coordinate, the modeled real quantity may already be:

```text
0
```

or:

```text
nonzero
```

So:

```text
unseen by LOAM
    -/-> empty in the world
```

That matters for a first-event origin. If a previously existing destination already held quantity before the first observed transfer or income, using zero as the origin would erase that prior quantity.

## TLA+ candidate

The model keeps two neutral coordinates and lets each begin with hidden real quantity `0` or `1` while still unseen.

Two experiment-local first-appearance transitions are then available.

### Observe first

```text
unseen
  + ordinary verb
  + first Event activity
  -> seen
  -> no anchored-current enrollment
```

The ordinary verb may be `transfer`, `income`, or `spendUse`.

It records which verb caused the first observation and what the real quantity was immediately before that observation, but it contributes no zero-origin evidence.

### Admit zero at first Event

```text
unseen
  + explicit premise: real quantity is exactly 0 now
  + first Event activity
  + anchored-current admission
  -> first-event origin
```

The physical first Event can otherwise be identical to the observe-only case.

This operation is intentionally application-level and experiment-local. It is not a new Core primitive and is not yet a production command.

## Positive safety

The candidate specification checks:

- type safety;
- unseen coordinates have no recorded activity or interpretation;
- every enrolled coordinate has explicit zero-origin evidence;
- every enrolled coordinate really had zero quantity immediately before its first Event;
- the resulting anchored current quantity matches modeled reality for admitted coordinates.

Expected result:

```text
complete finite state graph
no error
```

## Boundary 1 — transfer does not prove zero

A deliberately false invariant asks:

```text
TransferFirstAppearanceProvesZero
```

Expected result:

```text
counterexample
```

A coordinate may be unseen by LOAM, already carry nonzero real quantity, and then first appear through `transfer`.

Therefore:

```text
first transfer appearance
    -/-> zero immediately before transfer
```

## Boundary 2 — income does not prove zero

The same pressure applies to income.

A deliberately false invariant asks:

```text
IncomeFirstAppearanceProvesZero
```

Expected result:

```text
counterexample
```

Receiving income into a newly observed coordinate does not prove that the coordinate was empty before receipt.

## Boundary 3 — even the same transfer verb and same physical first appearance do not determine admission

The strongest boundary fixes both coordinates to the same human-facing verb and the same first physical signature.

Both may have:

```text
firstOp = transfer
prior = zero
activity = 1
reality after Event = 1
```

while one first appearance merely observes and the other carries explicit zero-origin admission evidence.

A deliberately false invariant asks:

```text
SameTransferFirstAppearanceDeterminesEnrollment
```

Expected result:

```text
counterexample
```

So even after adding the existing operation verb to the neutral Event shape:

```text
operation kind + physical first Event
    -/-> anchored-current enrollment
```

The missing distinction is the admission premise itself.

## Interpretation if qualified

If all expected results hold, the candidate boundary becomes:

```text
first appearance
    can locate a possible origin in time

ordinary transfer / income / spending verb
    -/-> exact-zero origin

explicit zero-origin admission evidence
    -> can justify a first-event origin
```

This means the tempting production rule:

```text
unseen transfer destination
    -> silently create current coordinate at zero
```

would be too strong.

A safer future operation would need to express something closer to:

```text
this coordinate begins empty here
and this Event is its first activity
```

That premise could later be attached to a transfer, income, or another concrete entrance if daily use earns it. The experiment deliberately does not decide the final user-facing wording.

## Why this is not an Account primitive

The result does not say that a transfer destination is an Account, Holding, Asset, or any other universal role.

It says only that one selected anchored-current question needs evidence for its local origin.

The neutral Event still retains only quantity effects. Operation vocabulary and origin-admission evidence remain application-level concerns.

## Next pressure if qualified

If admission evidence is required, restart-safe daily use creates a new question:

> Must that admission evidence be persisted as its own typed fact, since the neutral Event and the human-facing verb alone cannot reconstruct it later?

That is deliberately left for a later observation.

## Practical Core impact

None at this checkpoint.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no Account / HoldingRole / UseRole / Expense Category primitive;
- no automatic transfer-destination enrollment;
- no private household values committed.
