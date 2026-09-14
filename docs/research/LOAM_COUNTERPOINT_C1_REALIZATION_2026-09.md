# C1 — Scheduled realization counterpoint

Status: first production-semantics counterexample map

Direction checkpoint: `LOAM_COUNTERPOINT_EXPLORATION_2026-09.md`
Production baseline: `9c4989a9772f7da91a34ab9f6da0544c4f38209e`

## Question

Observation 113 qualified a useful bounded law for one Purpose:

```text
Headroom_after - Headroom_before
    = Scheduled_expected - Actual_realized
```

with the familiar special case:

```text
expected = actual  -> Headroom unchanged
```

The current exercise asks whether that law survives LOAM's present production semantics rather than the smaller historical model.

The answer after the first pass is: **yes, but only after `expected` and `actual` are stated as contributions to the same queried semantic voice, not as whole-movement totals.**

## Current production voices

Current coverage is assembled as:

```text
Entitlement := effective Capacity in the current elapsed window
Consumption := correction-frontier Actual contribution routed to one Purpose
Commitment  := current-open Scheduled pressure routed/classified for one Purpose
Remaining   := Entitlement - Consumption
Headroom    := Remaining - Commitment
```

The two changing voices therefore live behind different authorities and different routing subjects:

```text
Scheduled pressure
  subject = ScheduledId × LocusId
  route selected at observedAt

Actual consumption
  subject = LocusId
  route selected at the Actual Event's valid coordinate
```

Scheduled completion itself publishes only:

```text
ScheduledId -> Actual EventId
Actual Event effects
Actual valid date
```

It does **not** copy Scheduled routing into Actual routing and does not assert that the completion Actual has the same Purpose contribution as the Scheduled expectation.

This separation is intentional: expected intent and actual historical interpretation are independent evidence.

## First counterexample

A whole-movement equality is insufficient.

Suppose a Scheduled occurrence carries 5,000 JPY of positive pressure routed to Purpose `living`.

Completion may publish an Actual movement with the same 5,000 JPY gross/positive total, while the Actual Locus is:

- routed to another Purpose at the Actual valid date;
- explicitly unmanaged;
- unrouted;
- routed to `living` only after the Actual valid date;
- split differently across Loci so that only part contributes to `living`.

Then:

```text
whole Scheduled amount = whole Actual amount
```

does **not** imply:

```text
Headroom_after = Headroom_before
```

The old algebra survives only after comparing the contributions selected by the current production projections.

## Refined law candidate

For a fixed Purpose `p`, Measure `m`, current-window start `w0`, observation coordinate `t`, and future horizon `h`, define:

```text
S_p,m = managed Scheduled commitment contribution removed by realization
A_p,m = Actual consumption contribution added to the correction frontier
```

where `S_p,m` is selected using Scheduled routing / fallback pressure classification at `t`, and `A_p,m` is selected using Actual routing at the realized Event's valid coordinate.

If Capacity/Entitlement is unchanged and no unrelated evidence changes, then the algebra suggests:

```text
Headroom_after - Headroom_before = S_p,m - A_p,m
```

The exact-equality special case becomes:

```text
S_p,m = A_p,m  -> Headroom unchanged
```

This is stronger and more precise than comparing whole Scheduled and Actual movements.

## Conditions already visible from current production

The candidate law needs at least these boundaries to be held fixed or stated explicitly:

1. **Same queried Purpose and Measure.** The law is per projection voice, not necessarily global.
2. **Stable Capacity evidence.** Completion does not itself mutate Capacity, but an unrelated Capacity publication changes Entitlement and therefore Headroom.
3. **Effective completion.** A Scheduled terminal pointing to an Actual endpoint does not close the Scheduled source until that Actual Event exists. Interrupted publication therefore must not be treated as a completed transition.
4. **Actual valid coordinate inside the elapsed current window.** Consumption is selected from `currentWindowStart <= validOn <= observedAt`.
5. **Scheduled occurrence inside the current future horizon before completion.** Commitment selects current-open pressure in `[observedAt, endExclusive)`.
6. **Current routing evidence used at each side's own coordinate.** Scheduled routing is selected at `observedAt`; Actual routing is selected at the Actual valid coordinate. No equality between them is implied by completion.
7. **Correction frontier fixed except for the realized Actual under study.** A later EventCorrection can replace the Actual contribution and therefore changes `A_p,m` without changing the Scheduled completion relation.
8. **No double counting across split Loci.** Scheduled pressure is aggregated per `ScheduledId × LocusId`; Actual consumption folds Event effects by Locus routing. Whole-event totals are not the correct comparison object.

## Interesting dissonances

These are not necessarily bugs. They are cases where the voices legitimately do not resolve to the same contribution.

### Routing divergence

```text
Scheduled -> living
Actual    -> books
```

The realization relation says the Actual realizes the expectation, but Purpose interpretation differs. Headroom shifts across Purpose projections rather than remaining invariant in either one individually.

### Quantity divergence

```text
Scheduled contribution = 5,000
Actual contribution    = 4,700
```

For the same Purpose voice, headroom should increase by 300 if all other conditions are fixed.

### Split divergence

A Scheduled movement can route different Loci to different Purposes because its routing subject is `ScheduledId × LocusId`. An Actual Event may use a different split. The correct comparison is therefore the projected contribution per Purpose/Measure, not one scalar attached to the realization relation.

### Time divergence

Scheduled routing and Actual routing use different semantic coordinates. A route change between expectation time and actual occurrence time can intentionally make the two contributions differ even when the movement contents are identical.

### Correction divergence

Completion owns a stable Scheduled -> Actual endpoint, while EventCorrection may later make a replacement Event the effective Actual content. A user-facing realization variance should therefore read the correction frontier rather than freezing the originally published completion Event's quantity.

## What this means for LOAM's sound

The interesting answer is no longer merely:

> the bill was expected to be 5,000 and happened to be 4,700.

LOAM can potentially say something more exact:

> 5,000 of future pressure left `living`; 4,700 of realized consumption entered `living`; the realization released 300 of headroom.

Or, when routing differs:

> the expectation left one Purpose, but the Actual entered another; the realization relation is intact, while the household interpretation changed.

That answer falls naturally out of already-independent Scheduled, Actual, routing, time, correction, and Capacity semantics. No stored `Variance`, `Settlement`, or `Fulfillment` amount is required merely to state it.

## Next probes

The next work should test the refined law, not the old whole-movement equality.

Start with the smallest pure/executable cases:

1. exact same Purpose contribution -> zero Headroom delta;
2. under-realization -> positive delta;
3. over-realization -> negative delta;
4. same whole amount but different Purpose routing -> counterexample to whole-movement equality;
5. split Scheduled/Actual movement -> contribution-wise law;
6. Actual valid date outside the current elapsed window -> identify whether the comparison is unavailable or deliberately asymmetric;
7. corrected completion Actual -> compare against correction-frontier contribution;
8. interrupted completion relation without Actual endpoint -> verify no premature transition.

Use existing production projection functions wherever possible. Add an Alloy model only if the interaction of routing/time/correction alternatives is easier to falsify relationally than with direct Lean examples. A production surface is not yet earned.
