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

## Observed TLC result

TLA+ tools 1.7.4 / TLC 2.19 explored the positive model completely:

```text
4 initial states
202 states generated
121 distinct states
0 states left on queue
depth 3
no error
```

The checked safety properties were:

- type safety;
- unseen coordinates have no recorded activity or interpretation;
- every enrolled coordinate has explicit zero-origin evidence;
- every enrolled coordinate really had zero quantity immediately before its first Event;
- the resulting anchored current quantity matches modeled reality for admitted coordinates.

## Boundary 1 — transfer does not prove zero

The deliberately false invariant:

```text
TransferFirstAppearanceProvesZero
```

failed as expected.

TLC found a state where coordinate `b` was unseen while its modeled real quantity was already `1`. Its first observed operation was then `transfer`:

```text
before first observation
  reality[b] = 1

first operation
  firstOp[b] = transfer
  firstPrior[b] = nonzero
  activity[b] = 1
  reality[b] = 2
```

Therefore:

```text
first transfer appearance
    -/-> zero immediately before transfer
```

## Boundary 2 — income does not prove zero

The deliberately false invariant:

```text
IncomeFirstAppearanceProvesZero
```

also failed as expected.

TLC found the corresponding witness with an unseen coordinate whose modeled real quantity was already `1` before its first `income` observation.

Therefore:

```text
first income appearance
    -/-> zero immediately before income
```

## Boundary 3 — even the same transfer verb and same physical first appearance do not determine admission

The strongest deliberately false invariant was:

```text
SameTransferFirstAppearanceDeterminesEnrollment
```

TLC found a three-state witness.

Both coordinates begin at real zero. Coordinate `a` first appears through an ordinary observe-only transfer. Coordinate `b` then first appears through a transfer carrying explicit zero-origin admission evidence.

The resulting physical and operation signatures are equal:

```text
firstOp[a] = transfer
firstOp[b] = transfer

firstPrior[a] = zero
firstPrior[b] = zero

activity[a] = 1
activity[b] = 1

reality[a] = 1
reality[b] = 1
```

but interpretation differs:

```text
a
  zeroEvidence = false
  enrolled = false

b
  zeroEvidence = true
  originKind = firstEvent
  enrolled = true
```

So even after adding the existing operation verb to the neutral physical facts:

```text
operation kind + physical first Event
    -/-> anchored-current enrollment
```

The missing distinction is the admission premise itself.

## Qualified boundary

The observed result is:

```text
first appearance
    can locate a possible origin in time

ordinary transfer / income / spending verb
    -/-> exact-zero origin

operation kind + physical first Event
    -/-> anchored-current enrollment

explicit zero-origin admission evidence
    -> can justify a first-event origin
```

This means the tempting production rule:

```text
unseen transfer destination
    -> silently create current coordinate at zero
```

is too strong.

A safer future operation needs to express something closer to:

```text
this coordinate begins empty here
and this Event is its first activity
```

That premise could later be attached to a transfer, income, or another concrete entrance if daily use earns it. The experiment deliberately does not decide the final user-facing wording.

## Why this is not an Account primitive

The result does not say that a transfer destination is an Account, Holding, Asset, or any other universal role.

It says only that one selected anchored-current question needs evidence for its local origin.

The neutral Event still retains only quantity effects. Operation vocabulary and origin-admission evidence remain application-level concerns.

## Next pressure

Restart-safe daily use now creates a sharper question:

> Must zero-origin admission evidence be persisted as its own typed fact, since neither the neutral Event nor the human-facing verb can reconstruct it later?

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
