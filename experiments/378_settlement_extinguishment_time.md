# Observation 378 — extinguishment temporal placement

Status: **BOUNDED RESULT — optional effective time is sufficient; unknown placement must remain explicit**

Baseline:

```text
#1442  Observation 377 — stable extinguishment row identity qualified
main   f4008b2b71a559e61969648a002aa53259d96443
```

## Trigger

Observation 377 earned stable row identity plus append-only evidence revision for
non-settlement extinguishment.

Before promotion, one practical history question remains:

> If a valid commitment loses quantity without settlement, do we need to retain
> when that change belonged, or are row identity + target + quantity enough?

The answer matters for LOAM's cycle/month/history surfaces, but the UI goal is the
opposite of field proliferation: retain only the smallest time coordinate that
changes an answer.

## Candidate under test

```text
SettlementCommitmentExtinguishment
  id
  target
  quantity
  effectiveOn : Option Date
```

`effectiveOn = none` means:

```text
the extinguishment is accepted current evidence,
but its historical placement is unknown
```

It must not silently mean commitment date, recording date, or today.

No separate `recordedAt`, reason code, Event reference, or legal taxonomy is
introduced by this observation.

## Current-state query

Current outstanding does not need temporal placement:

```text
current outstanding
=
committed
- settled
- current extinguished
```

An extinguishment with unknown effective date can still reduce the current open
quantity because the fact that it occurred is known even when its exact
historical placement is not.

## Historical query

For cutoff T, only extinguishments explicitly placed on or before T may affect a
dated historical answer.

Unknown placement remains unplaced rather than guessed.

## Witness — unknown time still supports current state

```text
commitment = 10
extinguishment = 3
effectiveOn = unknown

current outstanding = 7
```

Expected Alloy result: **SAT**.

This protects the low-input workflow and avoids forcing invented dates.

## Witness — known versus unknown placement remain distinct

Two otherwise equivalent extinguishment rows may differ only in whether a
historical occurrence time is known.

Expected Alloy result: **SAT**.

That distinction is intentional evidence, not missing data to auto-fill.

## Assertions

### CurrentOutstandingIgnoresTemporalPlacement

Current quantity is determined by retained current extinguishment quantities,
not by whether those rows have historical placement.

Expected: **UNSAT counterexample**.

### KnownHistoricalPlacementDeterminesAsOfView

Given explicit effective times, the bounded as-of projection is determined.

Expected: **UNSAT counterexample**.

### CurrentOutstandingDeterminesHistoricalOutstanding

Deliberately too strong.

Two histories can have the same current outstanding while answering a cutoff
question differently because the reduction belonged on different sides of the
cutoff.

Expected: **SAT counterexample**.

### UnknownEffectiveTimeEqualsOpenTime

Deliberately too strong.

Treating unknown time as the commitment's opening time fabricates historical
precision and changes as-of answers.

Expected: **SAT counterexample**.

## Alloy result

Qualified on Alloy 6.2.0 with SAT4J through the shared research witness harness.

```text
sameCurrentDifferentHistoricalPlacementWitness SAT
knownEarlyVersusUnknownWitness                 SAT
unknownStillDeterminesCurrentOutstandingWitness SAT

CurrentOutstandingIgnoresTemporalPlacement     UNSAT counterexample
KnownHistoricalPlacementDeterminesAsOfView     UNSAT counterexample

CurrentOutstandingDeterminesHistoricalOutstanding SAT counterexample
UnknownEffectiveTimeEqualsOpenTime                SAT counterexample
```

The bounded result supports a deliberately asymmetric treatment:

```text
current state
  exact extinguishment quantity is enough
  effective time may remain unknown

historical placement
  only explicitly known effective time may place the reduction at a cutoff
  unknown must remain unplaced
```

So optional time is not extra display metadata. It is the minimum information
needed to distinguish equal current states with different histories.

At the same time, requiring an exact date would be too strong: unknown-time
extinguishment still determines current outstanding correctly.

## Finding

The smallest production shape becomes:

```text
SettlementExtinguishmentId

SettlementCommitmentExtinguishment
  id
  target
  quantity
  effectiveOn : Option Date

SettlementExtinguishmentRevision
  target
  replacement : Option SettlementExtinguishmentId
```

This adds only one optional time coordinate beyond Observation 377.

For ordinary current use, the user need not enter or see it unless relevant.
A future friendly TUI can ask:

```text
When did this change happen?
  [today]
  [choose date]
  [I don't know]
```

and keep IDs, revision vocabulary, and provenance mechanics behind the detail
surface.

## What this does not earn

- `recordedAt` as canonical authority;
- mandatory exact dates;
- synthetic zero-value Events;
- reason categories such as waiver/forgiveness/expiry/novation;
- automatic date inference from prose;
- showing temporal metadata in the default Settlement list.

## Stop condition

If the matrix holds:

1. retain optional `effectiveOn` on extinguishment rows;
2. never default unknown time to another date;
3. let unknown-time extinguishment affect current outstanding;
4. exclude unknown-time rows from exact historical placement;
5. proceed to production promotion with no additional user-visible taxonomy.
