# Observation 186 — one concrete Scheduled suppression overlay

Status: practical Lean observation following Observation 185.

## Pressure

Household advice needs to answer questions such as:

```text
what changes before this horizon if I pause this one Scheduled expense?
```

Observation 185 qualified a general boundary for typed hypothetical interventions, but deliberately stopped before a production-shaped Application operation.

The smallest follow-up is therefore not a generic Scenario engine. It is one read-only overlay over one already-qualified projection.

## Existing projection reused

`Loam.Application.currentScheduledBalanceEffectsBefore?` already provides:

```text
retained Scheduled / lifecycle evidence
+ selected balance coordinates
+ explicit end-exclusive horizon
-> current-open Scheduled balance effects
```

It fails closed when completion or retirement evidence is structurally inconsistent.

Observation 186 keeps that lifecycle boundary unchanged.

## Small refactor

`ScheduledBalanceInspection` now exposes the pure projection step:

```text
already-qualified Scheduled occurrence list
+ selected coordinates
+ end-exclusive horizon
-> Scheduled balance effects
```

The existing canonical query still qualifies lifecycle evidence first and then calls that exact projection.

This extraction adds no new authority. It exists so baseline and hypothetical answers can be derived from the same already-qualified open set instead of fabricating a second Scheduled memory.

## Typed hypothetical operation

The only hypothetical type introduced is:

```text
SuppressScheduledHypothesis
    scheduled : ScheduledId
```

The comparison result carries:

```text
hypothesis
baseline effects
projected effects
```

The target must be present in the qualified current-open set. A missing or already-closed target is rejected as `targetNotOpen` rather than silently becoming a no-op.

Lifecycle refusal states remain explicit:

```text
unknownCompletionScheduled
unknownRetirementScheduled
conflictingTerminalEvidence
```

## Qualified witnesses

`Loam/Observations/Observation186.lean` checks four nearby seams.

1. Suppressing one open payment changes only the derived comparison, with baseline retained beside it.
2. The comparison baseline is exactly the existing `currentScheduledBalanceEffectsBefore?` result.
3. An open Scheduled target outside the requested horizon is still a valid hypothesis and can legitimately leave this projection unchanged.
4. Broken lifecycle evidence is not repaired or bypassed by a hypothetical request.

## Earned boundary

```text
qualified current-open Scheduled evidence
+ one typed SuppressScheduledHypothesis
+ ordinary Scheduled balance question
-> baseline and hypothetical derived effects side by side
```

This is enough for a later adapter to answer one concrete household question such as whether pausing a selected upcoming subscription changes the projected balance effects before a horizon.

## Not earned

Observation 186 does not introduce or authorize:

- canonical Scenario state;
- Recommendation or Preference;
- optimizer/search over candidate actions;
- automatic Scheduled retirement or completion;
- mutation of canonical evidence;
- safe-to-spend semantics;
- a generic hypothetical-intervention framework;
- a claim that equal projected balances imply equal household meaning.

## Smallest next step

If this slice qualifies, expose this single comparison through one read-only adapter surface, preferably the existing query bridge used by external clients. Keep the request bound to an exact canonical source revision and return baseline, projected effects, and the suppressed Scheduled identity as query provenance.
